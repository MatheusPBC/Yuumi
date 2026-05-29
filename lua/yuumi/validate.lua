local marks = require("yuumi.marks")
local ui = require("yuumi.ui")
local util = require("yuumi.util")
local anchor_util = require("yuumi.anchor")

local M = {}

local function trim(value)
  return (value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function find_exact(buffer_lines, expected)
  for _, line in ipairs(buffer_lines) do
    if line == expected then
      return true
    end
  end

  return false
end

local function find_different(buffer_lines, expected)
  local expected_trimmed = trim(expected)

  if expected_trimmed == "" then
    return nil
  end

  for _, line in ipairs(buffer_lines) do
    if trim(line) ~= "" and trim(line) ~= expected_trimmed then
      local shared = 0
      for index = 1, math.min(#trim(line), #expected_trimmed) do
        if trim(line):sub(index, index) ~= expected_trimmed:sub(index, index) then
          break
        end
        shared = index
      end

      if shared >= 6 then
        return line
      end
    end
  end

  return nil
end

function M.current_buffer()
  local task, anchor = marks.anchor_at_cursor()
  if not task or not anchor then
    return nil, "No Yuumi anchor at cursor"
  end

  local expected_lines = anchor_util.write_text(anchor)
  if #expected_lines == 0 then
    return nil, "Current anchor has no writeText"
  end

  local buffer_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local result = {
    task = task,
    anchor = anchor,
    ok = 0,
    missing = 0,
    different = 0,
    details = {},
  }

  for index, expected in ipairs(expected_lines) do
    if find_exact(buffer_lines, expected) then
      result.ok = result.ok + 1
      table.insert(result.details, { status = "ok", index = index, expected = expected })
    else
      local actual = find_different(buffer_lines, expected)
      if actual then
        result.different = result.different + 1
        table.insert(result.details, { status = "different", index = index, expected = expected, actual = actual })
      else
        result.missing = result.missing + 1
        table.insert(result.details, { status = "missing", index = index, expected = expected })
      end
    end
  end

  return result
end

function M.lines(result)
  local lines = {
    "# Yuumi Validate",
    "",
    "Task: " .. (result.task.summary or result.task.id or "unknown"),
    "Anchor: " .. (result.anchor.id or "unknown"),
    "",
    string.format("OK: %d", result.ok),
    string.format("Missing: %d", result.missing),
    string.format("Different: %d", result.different),
  }

  for _, detail in ipairs(result.details) do
    if detail.status == "missing" then
      table.insert(lines, "")
      table.insert(lines, string.format("Missing L%d:", detail.index))
      table.insert(lines, "  expected: " .. detail.expected)
    elseif detail.status == "different" then
      table.insert(lines, "")
      table.insert(lines, string.format("Different L%d:", detail.index))
      table.insert(lines, "  expected: " .. detail.expected)
      table.insert(lines, "  actual:   " .. detail.actual)
    end
  end

  return lines
end

function M.show()
  local result, err = M.current_buffer()
  if not result then
    util.notify(err, vim.log.levels.WARN)
    return
  end

  ui.float(M.lines(result), { title = "Yuumi Validate", width = 84, height = 22 })
end

return M
