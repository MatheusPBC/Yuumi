local config = require("yuumi.config")
local state = require("yuumi.state")
local util = require("yuumi.util")

local M = {}

local function anchor_key(task, anchor)
  return string.format("%s:%s", task.id or task.file, anchor.id or anchor.line)
end

local function encode_state()
  local anchors = {}

  for _, task in ipairs(state.plan and state.plan.tasks or {}) do
    for _, anchor in ipairs(task.anchors or {}) do
      if anchor.status then
        anchors[anchor_key(task, anchor)] = { status = anchor.status }
      end
    end
  end

  return {
    version = 1,
    plan = state.plan and state.plan.title or nil,
    anchors = anchors,
  }
end

local function ensure_parent(path)
  local parent = vim.fn.fnamemodify(util.resolve_path(path), ":h")
  vim.fn.mkdir(parent, "p")
end

function M.save()
  if not state.plan then
    return false
  end

  local path = config.options.state_path
  ensure_parent(path)

  local file = io.open(util.resolve_path(path), "w")
  if not file then
    util.notify("Could not write " .. path, vim.log.levels.ERROR)
    return false
  end

  file:write(vim.json.encode(encode_state()))
  file:close()
  return true
end

function M.load()
  if not state.plan then
    return
  end

  if not vim.uv.fs_stat(util.resolve_path(config.options.state_path)) then
    return
  end

  local content = util.read_file(config.options.state_path)
  if not content then
    return
  end

  local ok, decoded = pcall(vim.json.decode, content)
  if not ok or type(decoded.anchors) ~= "table" then
    return
  end

  for _, task in ipairs(state.plan.tasks or {}) do
    for _, anchor in ipairs(task.anchors or {}) do
      local persisted = decoded.anchors[anchor_key(task, anchor)]
      if persisted then
        anchor.status = persisted.status
      end
    end
  end
end

function M.reset()
  if state.plan then
    for _, task in ipairs(state.plan.tasks or {}) do
      for _, anchor in ipairs(task.anchors or {}) do
        anchor.status = nil
      end
    end
  end

  os.remove(util.resolve_path(config.options.state_path))
  return true
end

return M
