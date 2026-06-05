local anchor_util = require("yuumi.anchor")
local locator = require("yuumi.locator")
local state = require("yuumi.state")
local status = require("yuumi.status")
local util = require("yuumi.util")

local M = {}

local function section(lines, title)
  table.insert(lines, "")
  table.insert(lines, "= " .. title .. " =")
end

local function panel(lines, title)
  table.insert(lines, "")
  table.insert(lines, title)
end

local function truncate(value, width)
  value = value or ""
  if vim.fn.strdisplaywidth(value) <= width then
    return value
  end

  if width <= 3 then
    return value:sub(1, width)
  end

  local truncated = vim.fn.strcharpart(value, 0, width - 3) .. "..."
  while vim.fn.strdisplaywidth(truncated) > width do
    truncated = vim.fn.strcharpart(truncated, 0, vim.fn.strchars(truncated) - 4) .. "..."
  end

  return truncated
end

local function pad(value, width)
  value = truncate(value, width)
  local display_width = vim.fn.strdisplaywidth(value)
  if display_width >= width then
    return value
  end

  return value .. string.rep(" ", width - display_width)
end

local function combine_columns(left, right, left_width, total_width)
  local lines = {}
  local total = math.max(#left, #right)
  local right_width = math.max(10, total_width - left_width - 3)

  for index = 1, total do
    table.insert(lines, pad(left[index], left_width) .. " │ " .. truncate(right[index] or "", right_width))
  end

  return lines
end

local function strip_panel(lines, actions)
  if lines[1] == "" and lines[2] and lines[2]:match("^%[%d%]%-") then
    local stripped_actions = {}
    for line, action in pairs(actions or {}) do
      if line > 2 then
        stripped_actions[line - 2] = action
      end
    end

    return vim.list_slice(lines, 3), stripped_actions
  end

  return lines, actions or {}
end

local function short_path(path)
  if #path <= 36 then
    return path
  end

  local parts = vim.split(path, "/", { plain = true })
  if #parts >= 3 then
    return ".../" .. table.concat(vim.list_slice(parts, #parts - 2), "/")
  end

  return "..." .. path:sub(#path - 32)
end

local function status_for(anchor)
  return status.for_anchor(0, anchor)
end

local function status_icon(current_status)
  if current_status == "done" then
    return "✓"
  end
  if current_status == "stale" then
    return "!"
  end
  if current_status == "skipped" then
    return "-"
  end
  return "●"
end

local function status_label(anchor)
  local current_status = status_for(anchor)
  return status_icon(current_status) .. " " .. current_status
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
      local start_line, end_line = locator.active_range(0, anchor)
      if row >= start_line and row <= end_line then
        return task, anchor
      end
    end
  end

  return nil, nil
end

local function add_anchor_details(lines, title, task, anchor)
  if not task or not anchor then
    return
  end

  section(lines, title)
  local start_line, end_line = locator.range(0, anchor)
  table.insert(lines, "  Arquivo: " .. short_path(task.file))
  if end_line and end_line ~= start_line then
    table.insert(lines, string.format("  Linhas alvo: %d-%d", start_line, end_line))
  else
    table.insert(lines, "  Linha alvo: " .. start_line)
  end
  table.insert(lines, "  Status: " .. status_label(anchor))
  table.insert(lines, "  Resumo: " .. (task.summary or anchor.guidance or task.id or "planned edit"))

  if anchor.reason then
    section(lines, "Por que")
    table.insert(lines, "  " .. anchor.reason)
  end

  if anchor.guidance then
    section(lines, "Fazer")
    table.insert(lines, "  " .. anchor.guidance)
  end

  local write_text = anchor_util.write_text(anchor)
  if #write_text > 0 then
    section(lines, "Codigo esperado")
    for _, item in ipairs(write_text) do
      table.insert(lines, "  " .. item)
    end
  end

  if anchor.removeText then
    section(lines, "Remover")
    table.insert(lines, "  " .. anchor.removeText)
  end

  if anchor.doneWhen then
    section(lines, "Checklist")
    for _, item in ipairs(anchor.doneWhen) do
      table.insert(lines, "  - " .. item)
    end
  end
end

local function progress_counts()
  local counts = { total = 0, done = 0, pending = 0, stale = 0, skipped = 0 }

  for _, task in ipairs(state.plan.tasks or {}) do
    for _, anchor in ipairs(task.anchors or {}) do
      local current_status = status_for(anchor)
      counts.total = counts.total + 1
      counts[current_status] = (counts[current_status] or 0) + 1
    end
  end

  return counts
end

local function add_files(lines, actions)
  panel(lines, "[3]-Arquivos")
  section(lines, "Arquivos")
  for task_index, task in ipairs(state.plan.tasks or {}) do
    local pending = 0
    local total = #(task.anchors or {})

    for _, anchor in ipairs(task.anchors or {}) do
      if status_for(anchor) == "pending" then
        pending = pending + 1
      end
    end

    table.insert(lines, string.format("  %d. %s  %d/%d", task_index, short_path(task.file), pending, total))
    if actions then
      actions[#lines] = { task_index = task_index, anchor_index = 1 }
    end
    for anchor_index, anchor in ipairs(task.anchors or {}) do
      local marker = task_index == state.cursor.task and anchor_index == state.cursor.anchor and ">" or " "
      local start_line = locator.range(0, anchor)
      table.insert(lines, string.format("   %s %s L%d %s", marker, status_label(anchor), start_line, anchor.id or task.summary or "patch"))
      if actions then
        actions[#lines] = { task_index = task_index, anchor_index = anchor_index }
      end
    end
  end
end

local function add_status(lines)
  local counts = progress_counts()
  panel(lines, "[1]-Status")
  table.insert(lines, string.format("%d patches · %d done · %d pending · %d stale · %d skipped", counts.total, counts.done, counts.pending, counts.stale, counts.skipped))
  table.insert(lines, state.plan.title or "untitled")
end

local function add_patches(lines, actions)
  panel(lines, "[2]-Patches")
  for task_index, task in ipairs(state.plan.tasks or {}) do
    for anchor_index, anchor in ipairs(task.anchors or {}) do
      local marker = task_index == state.cursor.task and anchor_index == state.cursor.anchor and "▶" or " "
      local label = anchor.id or task.summary or "patch"
      table.insert(lines, string.format("%s %s %s", marker, status_label(anchor), label))
      if actions then
        actions[#lines] = { task_index = task_index, anchor_index = anchor_index }
      end
    end
  end
end

local function add_actions(lines)
  panel(lines, "[4]-Acoes")
  table.insert(lines, "Enter abrir · v validate · c check")
  table.insert(lines, "d done · s skip · z zoom · ? help")
end

local function add_validate_summary(lines)
  panel(lines, "[5]-Validate / Diagnostics")
  local ok, validate = pcall(require, "yuumi.validate")
  if not ok then
    table.insert(lines, "Validate unavailable")
    return
  end

  local result, err = validate.current_buffer()
  if not result then
    table.insert(lines, err or "No diagnostics")
    return
  end

  table.insert(lines, string.format("OK %d · Missing %d · Different %d", result.ok, result.missing, result.different))
  for _, detail in ipairs(result.details) do
    if detail.status == "missing" then
      table.insert(lines, string.format("✗ expected L%d%s", detail.index, detail.line and string.format(" @ %d", detail.line) or ""))
    elseif detail.status == "different" then
      table.insert(lines, string.format("~ different L%d%s", detail.index, detail.line and string.format(" @ %d", detail.line) or ""))
    end
  end
end

local function add_multiline(lines, value, prefix)
  if not value or value == "" then
    return
  end

  for index, line in ipairs(vim.split(value, "\n", { trimempty = true })) do
    table.insert(lines, index == 1 and (prefix or "") .. line or line)
  end
end

local function add_ai_review(lines)
  panel(lines, "[6]-AI Review")
  local review = state.ai_review
  if not review then
    table.insert(lines, "Run :YuumiCheck to ask AI to review this patch.")
    return
  end

  table.insert(lines, "Status: " .. (review.status or "unknown"))
  if review.patch then
    table.insert(lines, "Patch: " .. review.patch)
  end
  add_multiline(lines, review.error, "Error: ")
  add_multiline(lines, review.output)
end

local function queue_items()
  local items = {}

  for task_index, task in ipairs(state.plan.tasks or {}) do
    for anchor_index, anchor in ipairs(task.anchors or {}) do
      if status_for(anchor) == "pending" then
        table.insert(items, {
          task_index = task_index,
          anchor_index = anchor_index,
          anchor = anchor,
          label = anchor.id or task.summary or "patch",
        })
      end
    end
  end

  return items
end

local function add_plan_queue(lines)
  local items = queue_items()
  if #items == 0 then
    return
  end

  section(lines, "Plano")
  for index, item in ipairs(items) do
    if item.task_index == state.cursor.task and item.anchor_index == state.cursor.anchor then
      table.insert(lines, "  ▶ current  " .. item.label)
    elseif index <= 5 then
      table.insert(lines, "  ○ next     " .. item.label)
    end
  end
end

local function add_current_details(lines)
  panel(lines, "[0]-Patch / Preview esperado")
  local file_task, file_anchor = current_file_anchor()
  if file_task and file_anchor then
    add_anchor_details(lines, "Patch atual", file_task, file_anchor)
    return
  end

  local task, anchor = current_anchor()
  add_anchor_details(lines, "Patch atual", task, anchor)
end

function M.render()
  if not state.plan then
    return { lines = { "Yuumi Plan", "", "No plan loaded" }, actions = {} }
  end

  local lines = {
    "Yuumi Plan",
    state.plan.title or "untitled",
  }

  local left = {}
  local left_actions = {}
  local right = {}

  add_status(left)
  add_patches(left, left_actions)
  add_files(left, left_actions)
  add_actions(left)

  add_current_details(right)
  add_ai_review(right)
  add_validate_summary(right)
  add_plan_queue(right)

  local board_width = math.min(vim.o.columns - 4, math.max(84, math.floor(vim.o.columns * 0.82)))
  vim.list_extend(lines, combine_columns(left, right, math.max(38, math.floor(board_width * 0.38)), board_width))
  local actions = {}
  for line, action in pairs(left_actions) do
    actions[line + 2] = action
  end

  return { lines = lines, actions = actions }
end

function M.lines()
  return M.render().lines
end

function M.panel_lines(builder)
  local builders = {
    status = add_status,
    patches = add_patches,
    files = add_files,
    actions = add_actions,
    current = add_current_details,
    validate = add_validate_summary,
    ai_review = add_ai_review,
  }
  local lines = {}
  local actions = {}
  builders[builder](lines, actions)
  return strip_panel(lines, actions)
end

return M
