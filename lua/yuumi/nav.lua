local locator = require("yuumi.locator")
local marks = require("yuumi.marks")
local persist = require("yuumi.persist")
local state = require("yuumi.state")
local status_util = require("yuumi.status")
local ui = require("yuumi.ui")
local ui_manager = require("yuumi.ui_manager")
local util = require("yuumi.util")

local M = {}

local function open_anchor(task_index, anchor_index, opts)
  opts = opts or {}
  local task = state.plan.tasks[task_index]
  local anchor = task and task.anchors and task.anchors[anchor_index]

  if not task or not anchor then
    util.notify("Yuumi anchor not found", vim.log.levels.ERROR)
    return
  end

  state.cursor = { task = task_index, anchor = anchor_index }
  vim.cmd.edit(vim.fn.fnameescape(util.resolve_path(task.file)))
  local start_line = locator.range(0, anchor)
  local line_count = math.max(1, vim.api.nvim_buf_line_count(0))
  vim.api.nvim_win_set_cursor(0, { math.min(start_line, line_count), 0 })
  marks.render_buffer(0)
  if opts.refresh_ui ~= false then
    ui_manager.refresh()
  end
end

M.open = open_anchor

local function has_approved_ai_review(anchor)
  local review = state.ai_review
  if not review or review.status ~= "approved" then
    return false
  end

  if review.patch and anchor.id and review.patch ~= anchor.id then
    return false
  end

  return true
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
  ui.select_file("Yuumi files", open_anchor)
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

  if status == "done" then
    if not status_util.has_expected_text(0, anchor) then
      util.notify("Cannot mark done: expected Yuumi text is missing", vim.log.levels.WARN)
      return
    end
    if not has_approved_ai_review(anchor) then
      util.notify("Cannot mark done: run :YuumiCheck and get AI approval first", vim.log.levels.WARN)
      return
    end
  end

  anchor.status = status
  state.cursor = position
  persist.save()
  marks.render_all_loaded_buffers()
  ui_manager.refresh()
  util.notify(string.format("Marked %s as %s", anchor.id or task.id or "anchor", status))
end

return M
