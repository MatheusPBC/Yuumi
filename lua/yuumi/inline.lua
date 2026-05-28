local marks = require("yuumi.marks")
local state = require("yuumi.state")

local M = {}

local function line_prefix()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.api.nvim_get_current_line()
  local prefix_end = math.min(col + 1, #line)
  return line:sub(1, prefix_end), row - 1, prefix_end
end

local function find_suggestion(anchor, prefix)
  local suggestions = anchor.inlineSuggestions or {}

  for _, suggestion in ipairs(suggestions) do
    if suggestion.trigger and suggestion.insertText and prefix:match(vim.pesc(suggestion.trigger) .. "$") then
      return suggestion
    end
  end

  return nil
end

function M.clear(bufnr)
  vim.api.nvim_buf_clear_namespace(bufnr or 0, state.inline_namespace, 0, -1)
  state.inline = nil
end

function M.refresh()
  local bufnr = vim.api.nvim_get_current_buf()
  M.clear(bufnr)

  local _, anchor = marks.anchor_at_cursor()
  if not anchor then
    return
  end

  local prefix, row, col = line_prefix()
  local suggestion = find_suggestion(anchor, prefix)
  if not suggestion then
    return
  end

  local trigger_len = #suggestion.trigger
  local ghost = suggestion.insertText:sub(trigger_len + 1)
  if ghost == "" then
    return
  end

  vim.api.nvim_buf_set_extmark(bufnr, state.inline_namespace, row, col, {
    virt_text = { { ghost, "Comment" } },
    virt_text_pos = "inline",
    priority = 200,
  })

  state.inline = {
    bufnr = bufnr,
    row = row,
    col = col,
    suggestion = suggestion,
  }
end

function M.accept()
  local inline = state.inline
  if not inline or inline.bufnr ~= vim.api.nvim_get_current_buf() then
    return ""
  end

  local suggestion = inline.suggestion
  local trigger_len = #suggestion.trigger
  local suffix = suggestion.insertText:sub(trigger_len + 1)
  M.clear(inline.bufnr)
  return suffix
end

function M.accept_current()
  local inline = state.inline
  if not inline or inline.bufnr ~= vim.api.nvim_get_current_buf() then
    return false
  end

  local suggestion = inline.suggestion
  local suffix = suggestion.insertText:sub(#suggestion.trigger + 1)
  M.clear(inline.bufnr)
  vim.api.nvim_buf_set_text(inline.bufnr, inline.row, inline.col, inline.row, inline.col, { suffix })
  return true
end

return M
