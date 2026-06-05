local board = require("yuumi.board")
local board_view = require("yuumi.board_view")
local state = require("yuumi.state")
local ui_cleanup = require("yuumi.ui_cleanup")
local util = require("yuumi.util")

local M = {
  win = nil,
  buf = nil,
  source_win = nil,
  line_actions = {},
}

function M.open_selected()
  if not M.is_open() then
    return false
  end

  local line = vim.api.nvim_win_get_cursor(M.win)[1]
  local action = M.line_actions[line]
  if not action then
    return false
  end

  if M.source_win and vim.api.nvim_win_is_valid(M.source_win) then
    vim.api.nvim_set_current_win(M.source_win)
  end

  require("yuumi.nav").open(action.task_index, action.anchor_index)
  M.refresh()
  return true
end

local function set_keymaps()
  vim.keymap.set("n", "<CR>", M.open_selected, { buffer = M.buf, nowait = true, silent = true })
  vim.keymap.set("n", "<2-LeftMouse>", M.open_selected, { buffer = M.buf, nowait = true, silent = true })
end

local function set_options()
  vim.bo[M.buf].buftype = "nofile"
  vim.bo[M.buf].bufhidden = "hide"
  vim.bo[M.buf].filetype = "yuumi"
  vim.bo[M.buf].swapfile = false
  vim.api.nvim_buf_set_name(M.buf, "Yuumi Plan")
  vim.wo[M.win].wrap = false
  vim.wo[M.win].number = false
  vim.wo[M.win].relativenumber = false
  vim.wo[M.win].signcolumn = "no"
  vim.wo[M.win].winfixwidth = true
end

function M.is_open()
  return M.win and vim.api.nvim_win_is_valid(M.win) or false
end

function M.refresh()
  if not M.buf or not vim.api.nvim_buf_is_valid(M.buf) then
    return
  end

  local render = board_view.render()
  M.line_actions = render.actions
  vim.bo[M.buf].modifiable = true
  vim.api.nvim_buf_set_lines(M.buf, 0, -1, false, render.lines)
  vim.bo[M.buf].modifiable = false
end

function M.show()
  if not state.plan then
    util.notify("No plan loaded", vim.log.levels.WARN)
    return
  end

  board.close()
  ui_cleanup.close_sidebars(M.win, M.buf)

  if M.is_open() then
    M.refresh()
    return
  end

  M.source_win = vim.api.nvim_get_current_win()
  if not M.buf or not vim.api.nvim_buf_is_valid(M.buf) then
    M.buf = vim.api.nvim_create_buf(false, true)
  end

  vim.cmd("botright vertical split")
  M.win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(M.win, M.buf)
  vim.api.nvim_win_set_width(M.win, math.min(48, math.max(32, math.floor(vim.o.columns * 0.24))))
  set_options()
  set_keymaps()
  M.refresh()
  vim.api.nvim_set_current_win(M.source_win)
end

function M.hide()
  if M.is_open() then
    pcall(vim.api.nvim_win_close, M.win, true)
  end
  ui_cleanup.close_sidebars(nil, M.buf)
  M.win = nil
end

function M.close()
  M.hide()
  if M.buf and vim.api.nvim_buf_is_valid(M.buf) then
    pcall(vim.api.nvim_buf_delete, M.buf, { force = true })
  end
  M.buf = nil
  M.source_win = nil
  M.line_actions = {}
end

function M.toggle()
  board.close()

  if M.is_open() then
    M.hide()
  else
    M.show()
  end
end

return M
