local marks = require("yuumi.marks")
local state = require("yuumi.state")
local ui = require("yuumi.ui")
local util = require("yuumi.util")

local M = {}

local function open_anchor(task_index, anchor_index)
  local task = state.plan.tasks[task_index]
  local anchor = task and task.anchors and task.anchors[anchor_index]

  if not task or not anchor then
    util.notify("Yuumi anchor not found", vim.log.levels.ERROR)
    return
  end

  state.cursor = { task = task_index, anchor = anchor_index }
  vim.cmd.edit(vim.fn.fnameescape(util.resolve_path(task.file)))
  vim.api.nvim_win_set_cursor(0, { anchor.line, 0 })
  marks.render_buffer(0)
end

function M.open_current()
  if not state.plan then
    util.notify("No plan loaded", vim.log.levels.WARN)
    return
  end

  open_anchor(state.cursor.task, state.cursor.anchor)
end

function M.next()
  if not state.plan then
    util.notify("No plan loaded", vim.log.levels.WARN)
    return
  end

  local task_index = state.cursor.task
  local anchor_index = state.cursor.anchor + 1
  local task = state.plan.tasks[task_index]

  if not task or not task.anchors or anchor_index > #task.anchors then
    task_index = task_index + 1
    anchor_index = 1
  end

  if task_index > #state.plan.tasks then
    util.notify("Reached last Yuumi anchor")
    return
  end

  open_anchor(task_index, anchor_index)
end

function M.prev()
  if not state.plan then
    util.notify("No plan loaded", vim.log.levels.WARN)
    return
  end

  local task_index = state.cursor.task
  local anchor_index = state.cursor.anchor - 1

  if anchor_index < 1 then
    task_index = task_index - 1
    local task = state.plan.tasks[task_index]
    anchor_index = task and #(task.anchors or {}) or 1
  end

  if task_index < 1 then
    util.notify("Reached first Yuumi anchor")
    return
  end

  open_anchor(task_index, anchor_index)
end

function M.files()
  ui.select_task("Yuumi files and anchors", open_anchor)
end

function M.mark_status(status)
  local task, anchor, position = marks.anchor_at_cursor()

  if not task or not anchor then
    task = state.current_task()
    anchor = state.current_anchor()
    position = vim.deepcopy(state.cursor)
  end

  if not task or not anchor then
    util.notify("No Yuumi task selected", vim.log.levels.WARN)
    return
  end

  anchor.status = status
  state.cursor = position
  marks.render_all_loaded_buffers()
  util.notify(string.format("Marked %s as %s", anchor.id or task.id or "anchor", status))
end

return M
