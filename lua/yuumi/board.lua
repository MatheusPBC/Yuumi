local state = require("yuumi.state")
local anchor_util = require("yuumi.anchor")
local locator = require("yuumi.locator")
local util = require("yuumi.util")

local M = {
  win = nil,
  buf = nil,
}

local function status_for(anchor)
  return anchor.status or "pending"
end

local function current_anchor()
  local task = state.current_task()
  if not task then
    return nil, nil
  end

  return task, task.anchors and task.anchors[state.cursor.anchor]
end

local function current_file_anchor()
  local relative = util.buf_relative_path(0)
  local task_indexes = state.tasks_by_file[relative]

  if not task_indexes then
    return nil, nil
  end

  local row = vim.api.nvim_win_get_cursor(0)[1]

  for _, task_index in ipairs(task_indexes) do
    local task = state.plan.tasks[task_index]
    for _, anchor in ipairs(task.anchors or {}) do
      local start_line, end_line = locator.range(0, anchor)
      if row >= start_line and row <= end_line then
        return task, anchor
      end
    end
  end

  local task = state.plan.tasks[task_indexes[1]]
  return task, task and task.anchors and task.anchors[1]
end

local function add_anchor_details(lines, title, task, anchor)
  if not task or not anchor then
    return
  end

  table.insert(lines, "")
  table.insert(lines, title)
  local start_line = locator.range(0, anchor)
  table.insert(lines, "  " .. task.file .. ":" .. start_line)
  table.insert(lines, "  " .. (task.summary or anchor.guidance or task.id or "planned edit"))

  if anchor.guidance then
    table.insert(lines, "")
    table.insert(lines, "Write:")
    table.insert(lines, "  " .. anchor.guidance)
  end

  local write_text = anchor_util.write_text(anchor)
  if #write_text > 0 then
    table.insert(lines, "")
    table.insert(lines, "Write exactly:")
    for _, item in ipairs(write_text) do
      table.insert(lines, "  " .. item)
    end
  end

  if anchor.removeText then
    table.insert(lines, "")
    table.insert(lines, "Remove:")
    table.insert(lines, "  " .. anchor.removeText)
  end

  if anchor.doneWhen then
    table.insert(lines, "")
    table.insert(lines, "Done when:")
    for _, item in ipairs(anchor.doneWhen) do
      table.insert(lines, "  - " .. item)
    end
  end
end

local function add_current_details(lines)
  local file_task, file_anchor = current_file_anchor()
  if file_task and file_anchor then
    add_anchor_details(lines, "Current file", file_task, file_anchor)
    return
  end

  local task, anchor = current_anchor()
  add_anchor_details(lines, "Current", task, anchor)
end

function M.lines()
  if not state.plan then
    return { "Yuumi Plan", "", "No plan loaded" }
  end

  local lines = {
    "Yuumi Plan",
    state.plan.title or "untitled",
    "",
    "Files",
  }

  for task_index, task in ipairs(state.plan.tasks or {}) do
    table.insert(lines, string.format("  %d. %s", task_index, task.file))
    for anchor_index, anchor in ipairs(task.anchors or {}) do
      local marker = task_index == state.cursor.task and anchor_index == state.cursor.anchor and ">" or " "
      table.insert(lines, string.format("   %s [%s] L%d %s", marker, status_for(anchor), anchor.line, task.summary or anchor.guidance or anchor.id))
    end
  end

  add_current_details(lines)
  return lines
end

function M.close()
  if M.win and vim.api.nvim_win_is_valid(M.win) then
    vim.api.nvim_win_close(M.win, true)
  end
  M.win = nil
  M.buf = nil
end

function M.open()
  if not state.plan then
    util.notify("No plan loaded", vim.log.levels.WARN)
    return
  end

  if not M.buf or not vim.api.nvim_buf_is_valid(M.buf) then
    M.buf = vim.api.nvim_create_buf(false, true)
    vim.bo[M.buf].bufhidden = "wipe"
    vim.bo[M.buf].filetype = "yuumi"
  end

  vim.api.nvim_buf_set_lines(M.buf, 0, -1, false, M.lines())

  local width = math.min(44, math.max(32, math.floor(vim.o.columns * 0.28)))
  local height = math.min(#M.lines(), math.max(12, vim.o.lines - 6))

  if M.win and vim.api.nvim_win_is_valid(M.win) then
    vim.api.nvim_win_set_config(M.win, {
      relative = "editor",
      row = 2,
      col = vim.o.columns - width - 2,
      width = width,
      height = height,
    })
    return
  end

  M.win = vim.api.nvim_open_win(M.buf, false, {
    relative = "editor",
    row = 2,
    col = vim.o.columns - width - 2,
    width = width,
    height = height,
    border = "rounded",
    title = " Yuumi ",
    style = "minimal",
  })
end

function M.refresh()
  if not M.buf or not vim.api.nvim_buf_is_valid(M.buf) then
    return
  end

  vim.api.nvim_buf_set_lines(M.buf, 0, -1, false, M.lines())
end

return M
