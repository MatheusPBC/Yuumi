local M = {}

local function contains(line, text)
  return text and text ~= "" and line:find(text, 1, true) ~= nil
end

local function context_matches(lines, line, text, start_offset, end_offset)
  if not text or text == "" then
    return false
  end

  for offset = start_offset, end_offset do
    local candidate = lines[line + offset]
    if candidate and contains(candidate, text) then
      return true
    end
  end

  return false
end

local function best_anchor_line(bufnr, anchor)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local best_line = nil
  local best_score = 0

  for index, line in ipairs(lines) do
    local score = 0

    if contains(line, anchor.anchorText) then
      score = score + 100
    end

    if context_matches(lines, index, anchor.beforeText, -5, -1) then
      score = score + 25
    end

    if context_matches(lines, index, anchor.afterText, 1, 5) then
      score = score + 25
    end

    if score > best_score then
      best_score = score
      best_line = index
    end
  end

  if best_score > 0 then
    return best_line
  end

  return nil
end

local function find_line(bufnr, text)
  if not text or text == "" then
    return nil
  end

  for index, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
    if line:find(text, 1, true) then
      return index
    end
  end

  return nil
end

function M.anchor_in_buffer(bufnr, anchor)
  bufnr = bufnr or 0

  local line = best_anchor_line(bufnr, anchor)
    or find_line(bufnr, anchor.anchorText)
    or find_line(bufnr, anchor.beforeText)
    or find_line(bufnr, anchor.afterText)

  if not line then
    return false
  end

  local span = math.max((anchor.endLine or anchor.line) - anchor.line, 0)
  anchor.line = line
  anchor.endLine = line + span
  return true
end

function M.current_buffer()
  local state = require("yuumi.state")
  local util = require("yuumi.util")

  if not state.plan then
    util.notify("No plan loaded", vim.log.levels.WARN)
    return false
  end

  local task_indexes = state.tasks_by_file[util.buf_relative_path(0)] or {}
  local changed = false

  for _, task_index in ipairs(task_indexes) do
    local task = state.plan.tasks[task_index]
    for _, anchor in ipairs(task.anchors or {}) do
      changed = M.anchor_in_buffer(0, anchor) or changed
    end
  end

  return changed
end

return M
