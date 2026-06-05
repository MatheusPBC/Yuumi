local board = require("yuumi.board")
local state = require("yuumi.state")
local util = require("yuumi.util")

local M = {
  win = nil,
  buf = nil,
}

local function set_options()
  vim.bo[M.buf].buftype = "nofile"
  vim.bo[M.buf].bufhidden = "hide"
  vim.bo[M.buf].filetype = "yuumi"
  vim.bo[M.buf].swapfile = false
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

  local lines = board.lines()
  vim.bo[M.buf].modifiable = true
  vim.api.nvim_buf_set_lines(M.buf, 0, -1, false, lines)
  vim.bo[M.buf].modifiable = false
end

function M.show()
  if not state.plan then
    util.notify("No plan loaded", vim.log.levels.WARN)
    return
  end

  board.close()

  if M.is_open() then
    M.refresh()
    return
  end

  local source_win = vim.api.nvim_get_current_win()
  if not M.buf or not vim.api.nvim_buf_is_valid(M.buf) then
    M.buf = vim.api.nvim_create_buf(false, true)
  end

  vim.cmd("botright vertical new")
  M.win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(M.win, M.buf)
  vim.api.nvim_win_set_width(M.win, math.min(72, math.max(40, math.floor(vim.o.columns * 0.34))))
  set_options()
  M.refresh()
  vim.api.nvim_set_current_win(source_win)
end

function M.hide()
  if M.is_open() then
    pcall(vim.api.nvim_win_close, M.win, true)
  end
  M.win = nil
end

function M.close()
  M.hide()
  if M.buf and vim.api.nvim_buf_is_valid(M.buf) then
    pcall(vim.api.nvim_buf_delete, M.buf, { force = true })
  end
  M.buf = nil
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
