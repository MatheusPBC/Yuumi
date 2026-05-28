local config = require("yuumi.config")
local persist = require("yuumi.persist")
local state = require("yuumi.state")
local util = require("yuumi.util")

local M = {}

local function validate_anchor(anchor, task_index, anchor_index)
  if type(anchor.line) ~= "number" then
    return string.format("tasks[%d].anchors[%d].line must be a number", task_index, anchor_index)
  end

  if anchor.endLine and type(anchor.endLine) ~= "number" then
    return string.format("tasks[%d].anchors[%d].endLine must be a number", task_index, anchor_index)
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

  if plan.version ~= 1 then
    return "plan.version must be 1"
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

  state.plan = decoded
  state.plan_path = plan_path
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

return M
