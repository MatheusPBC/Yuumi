local anchor_util = require("yuumi.anchor")

local M = {}

local function trim(value)
  return (value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function has_line(buffer_lines, expected)
  local expected_trimmed = trim(expected)

  for _, line in ipairs(buffer_lines) do
    if line == expected or (expected_trimmed ~= "" and trim(line) == expected_trimmed) then
      return true
    end
  end

  return false
end

function M.has_expected_text(bufnr, anchor)
  local write_text = anchor_util.write_text(anchor)
  if #write_text == 0 then
    return true
  end

  local buffer_lines = vim.api.nvim_buf_get_lines(bufnr or 0, 0, -1, false)
  for _, line in ipairs(write_text) do
    if not has_line(buffer_lines, line) then
      return false
    end
  end

  return true
end

function M.for_anchor(bufnr, anchor)
  if anchor.status == "done" and not M.has_expected_text(bufnr or 0, anchor) then
    return "stale"
  end

  return anchor.status or "pending"
end

return M
