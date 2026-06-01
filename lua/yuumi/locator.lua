local anchor_util = require("yuumi.anchor")

local M = {}

local function trim(value)
  return (value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function line_matches(line, expected)
  local expected_trimmed = trim(expected)
  return line == expected or (expected_trimmed ~= "" and trim(line) == expected_trimmed)
end

local function find_line(lines, expected, start_index, stop_index)
  for index = start_index, stop_index do
    if line_matches(lines[index] or "", expected) then
      return index
    end
  end

  return nil
end

local function guided_range(bufnr, anchor, opts)
  opts = opts or {}
  local locator = anchor.locator or {}
  if not locator.afterText and not locator.beforeText then
    return nil, nil
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local after_line = locator.afterText and find_line(lines, locator.afterText, 1, #lines) or nil
  local before_start = after_line and after_line + 1 or 1
  local before_line = locator.beforeText and find_line(lines, locator.beforeText, before_start, #lines) or nil

  if locator.afterText and not after_line then
    return nil, nil
  end

  if locator.beforeText and not before_line then
    return nil, nil
  end

  if after_line and before_line and opts.active then
    return after_line + 1, math.max(after_line + 1, before_line - 1)
  end

  if after_line and before_line then
    return before_line, before_line
  end

  if after_line then
    local start_line = after_line + 1
    return start_line, start_line + #anchor_util.write_text(anchor) - 1
  end

  if before_line then
    local end_line = math.max(1, before_line - 1)
    return math.max(1, end_line - #anchor_util.write_text(anchor) + 1), end_line
  end

  return nil, nil
end

function M.range(bufnr, anchor)
  bufnr = bufnr or 0

  local start_line, end_line = guided_range(bufnr, anchor)
  if start_line and end_line then
    return start_line, end_line
  end

  start_line = anchor.line or 1
  end_line = math.max(anchor.endLine or start_line, start_line + #anchor_util.write_text(anchor) - 1)
  return start_line, end_line
end

function M.active_range(bufnr, anchor)
  bufnr = bufnr or 0

  local start_line, end_line = guided_range(bufnr, anchor, { active = true })
  if start_line and end_line then
    return start_line, end_line
  end

  return M.range(bufnr, anchor)
end

return M
