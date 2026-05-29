local config = require("yuumi.config")
local persist = require("yuumi.persist")
local state = require("yuumi.state")
local util = require("yuumi.util")

local M = {}

local function patch_to_anchor(patch)
  return {
    id = patch.id,
    line = patch.line,
    endLine = patch.endLine,
    kind = patch.kind or "guided-patch",
    locator = patch.locator,
    reason = patch.reason,
    guidance = patch.guidance or patch.summary,
    patch = {
      mode = patch.mode or "insert-between",
      writeText = patch.insert or patch.writeText or (patch.patch and patch.patch.writeText),
    },
    doneWhen = patch.doneWhen,
    inlineSuggestions = patch.inlineSuggestions,
  }
end

local function normalize_v2(plan)
  local tasks = {}
  local task_by_file = {}

  for _, patch in ipairs(plan.patches or {}) do
    local task = task_by_file[patch.file]
    if not task then
      task = {
        id = (patch.file or "patches"):gsub("[^%w]+", "-"):gsub("^%-", ""):gsub("%-$", ""),
        file = patch.file,
        status = "pending",
        summary = "Guided patches for " .. patch.file,
        anchors = {},
      }
      task_by_file[patch.file] = task
      table.insert(tasks, task)
    end

    table.insert(task.anchors, patch_to_anchor(patch))
  end

  return {
    version = 1,
    sourceVersion = 2,
    title = plan.title,
    tasks = tasks,
  }
end

function M.normalize(plan)
  if plan.version == 2 then
    return normalize_v2(plan)
  end

  return plan
end

local function plan_root_for(path)
  local agent_dir = "/.agent/"
  local agent_start = path:find(agent_dir, 1, true)
  if agent_start then
    return path:sub(1, agent_start - 1)
  end

  return vim.fn.fnamemodify(path, ":p:h")
end

local function validate_string_list(list, path)
  if type(list) ~= "table" then
    return path .. " must be a list"
  end

  for index, item in ipairs(list) do
    if type(item) ~= "string" then
      return string.format("%s[%d] must be a string", path, index)
    end
  end

  return nil
end

local function validate_inline_suggestion(suggestion, path)
  if type(suggestion.trigger) ~= "string" then
    return path .. ".trigger must be a string"
  end

  if type(suggestion.insertText) ~= "string" then
    return path .. ".insertText must be a string"
  end

  return nil
end

local function validate_anchor(anchor, task_index, anchor_index)
  if anchor.line and type(anchor.line) ~= "number" then
    return string.format("tasks[%d].anchors[%d].line must be a number", task_index, anchor_index)
  end

  if anchor.endLine and type(anchor.endLine) ~= "number" then
    return string.format("tasks[%d].anchors[%d].endLine must be a number", task_index, anchor_index)
  end

  local path = string.format("tasks[%d].anchors[%d]", task_index, anchor_index)

  if anchor.locator then
    if type(anchor.locator) ~= "table" then
      return path .. ".locator must be an object"
    end

    if anchor.locator.afterText and type(anchor.locator.afterText) ~= "string" then
      return path .. ".locator.afterText must be a string"
    end

    if anchor.locator.beforeText and type(anchor.locator.beforeText) ~= "string" then
      return path .. ".locator.beforeText must be a string"
    end
  end

  if anchor.patch then
    if type(anchor.patch) ~= "table" then
      return path .. ".patch must be an object"
    end

    if anchor.patch.mode and type(anchor.patch.mode) ~= "string" then
      return path .. ".patch.mode must be a string"
    end

    if anchor.patch.writeText then
      local err = validate_string_list(anchor.patch.writeText, path .. ".patch.writeText")
      if err then
        return err
      end
    end
  end

  if anchor.writeText then
    local err = validate_string_list(anchor.writeText, path .. ".writeText")
    if err then
      return err
    end
  end

  if anchor.doneWhen then
    local err = validate_string_list(anchor.doneWhen, path .. ".doneWhen")
    if err then
      return err
    end
  end

  if anchor.inlineSuggestions then
    if type(anchor.inlineSuggestions) ~= "table" then
      return path .. ".inlineSuggestions must be a list"
    end

    for index, suggestion in ipairs(anchor.inlineSuggestions) do
      local err = validate_inline_suggestion(suggestion, string.format("%s.inlineSuggestions[%d]", path, index))
      if err then
        return err
      end
    end
  end

  return nil
end

local function validate_task(task, task_index)
  if type(task.file) ~= "string" or task.file == "" then
    return string.format("tasks[%d].file must be a string", task_index)
  end

  if task.anchors and type(task.anchors) ~= "table" then
    return string.format("tasks[%d].anchors must be a list", task_index)
  end

  for anchor_index, anchor in ipairs(task.anchors or {}) do
    local err = validate_anchor(anchor, task_index, anchor_index)
    if err then
      return err
    end
  end

  return nil
end

function M.validate(plan)
  if type(plan) ~= "table" then
    return "plan must be a JSON object"
  end

  if plan.version ~= 1 and plan.version ~= 2 then
    return "plan.version must be 1 or 2"
  end

  if plan.version == 2 then
    if type(plan.patches) ~= "table" then
      return "plan.patches must be a list"
    end

    plan = M.normalize(plan)
  end

  if type(plan.tasks) ~= "table" then
    return "plan.tasks must be a list"
  end

  for task_index, task in ipairs(plan.tasks) do
    local err = validate_task(task, task_index)
    if err then
      return err
    end
  end

  return nil
end

function M.load(path)
  local plan_path = path and path ~= "" and path or config.options.plan_path
  local resolved_plan_path = util.resolve_existing_path(plan_path)
  local content, read_err = util.read_file(plan_path)

  if read_err then
    util.notify(read_err, vim.log.levels.ERROR)
    return false
  end

  local ok, decoded = pcall(vim.json.decode, content)
  if not ok then
    util.notify("Invalid plan JSON: " .. decoded, vim.log.levels.ERROR)
    return false
  end

  local validation_err = M.validate(decoded)
  if validation_err then
    util.notify("Invalid plan: " .. validation_err, vim.log.levels.ERROR)
    return false
  end

  decoded = M.normalize(decoded)
  state.plan = decoded
  state.plan_path = plan_path
  state.plan_root = plan_root_for(resolved_plan_path)
  state.cursor = { task = 1, anchor = 0 }
  state.index_tasks()
  persist.load()

  util.notify(string.format("Loaded %d task(s) from %s", #decoded.tasks, plan_path))
  return true
end

function M.ensure_loaded()
  if state.plan then
    return true
  end

  return M.load(config.options.plan_path)
end

function M.resume()
  local session = persist.read_session()
  if not session or not session.plan_path then
    return false
  end

  return M.load(session.plan_path)
end

return M
