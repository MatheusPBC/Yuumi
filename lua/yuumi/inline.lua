local config = require("yuumi.config")
local gpt = require("yuumi.gpt")
local marks = require("yuumi.marks")
local state = require("yuumi.state")

local M = {}

local function starts_with(value, prefix)
  return value:sub(1, #prefix) == prefix
end

local function line_prefix()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.api.nvim_get_current_line()
  local prefix_end = math.min(col + 1, #line)
  return line:sub(1, prefix_end), row - 1, prefix_end
end

local function matching_prefix(insert_text, trigger, prefix)
  for length = math.min(#prefix, #insert_text), #trigger, -1 do
    local candidate = prefix:sub(#prefix - length + 1)
    if candidate:sub(1, #trigger) == trigger and insert_text:sub(1, length) == candidate then
      return candidate
    end
  end

  return nil
end

local function ai_suggestion(task, anchor, prefix, row)
  if not config.options.inline_ai_enabled or not config.options.gpt_command then
    return nil, nil
  end

  local start_line = math.max(0, row - 4)
  local end_line = math.min(vim.api.nvim_buf_line_count(0), row + 5)
  local output = gpt.run_command({
    action = "InlineSuggest",
    file = task.file,
    line = row + 1,
    prefix = prefix,
    nearbyLines = vim.api.nvim_buf_get_lines(0, start_line, end_line, false),
    guidance = anchor.guidance,
    writeText = anchor.writeText,
  })

  if not output or output == "" then
    return nil, nil
  end

  return { insertText = prefix .. output:gsub("%s+$", "") }, prefix
end

local function find_suggestion(task, anchor, prefix, row)
  local write_text = anchor.writeText or {}

  for _, line in ipairs(write_text) do
    if prefix ~= "" and starts_with(line, prefix) and line ~= prefix then
      return { insertText = line }, prefix
    end
  end

  if prefix == "" then
    local buffer_text = "\n" .. table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n") .. "\n"
    for _, line in ipairs(write_text) do
      if not buffer_text:find("\n" .. vim.pesc(line) .. "\n") then
        return { insertText = line }, ""
      end
    end
  end

  local suggestions = anchor.inlineSuggestions or {}

  for _, suggestion in ipairs(suggestions) do
    if suggestion.trigger and suggestion.insertText then
      local typed_prefix = matching_prefix(suggestion.insertText, suggestion.trigger, prefix)
      if typed_prefix then
        return suggestion, typed_prefix
      end
    end
  end

  return nil, nil
end

function M.clear(bufnr)
  vim.api.nvim_buf_clear_namespace(bufnr or 0, state.inline_namespace, 0, -1)
  state.inline = nil
end

function M.refresh()
  local bufnr = vim.api.nvim_get_current_buf()
  M.clear(bufnr)

  local task, anchor = marks.anchor_at_cursor()
  if not anchor then
    return
  end

  local prefix, row, col = line_prefix()
  local suggestion, typed_prefix = find_suggestion(task, anchor, prefix, row)
  if not suggestion then
    suggestion, typed_prefix = ai_suggestion(task, anchor, prefix, row)
  end
  if not suggestion then
    return
  end

  local ghost = suggestion.insertText:sub(#typed_prefix + 1)
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
    typed_prefix = typed_prefix,
  }
end

function M.accept()
  local inline = state.inline
  if not inline or inline.bufnr ~= vim.api.nvim_get_current_buf() then
    return ""
  end

  local suggestion = inline.suggestion
  local typed_prefix = inline.typed_prefix or suggestion.trigger
  local suffix = suggestion.insertText:sub(#typed_prefix + 1)
  M.clear(inline.bufnr)
  return suffix
end

function M.accept_current()
  local inline = state.inline
  if not inline or inline.bufnr ~= vim.api.nvim_get_current_buf() then
    return false
  end

  local suggestion = inline.suggestion
  local typed_prefix = inline.typed_prefix or suggestion.trigger
  local suffix = suggestion.insertText:sub(#typed_prefix + 1)
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.api.nvim_get_current_line()
  local insert_row = row - 1
  local insert_col = math.min(col, #line)

  if typed_prefix and line:match(vim.pesc(typed_prefix) .. "$") then
    insert_col = #line
  end

  M.clear(inline.bufnr)
  vim.api.nvim_buf_set_text(inline.bufnr, insert_row, insert_col, insert_row, insert_col, { suffix })
  return true
end

return M
