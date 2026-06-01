local state = require("yuumi.state")
local anchor_util = require("yuumi.anchor")
local locator = require("yuumi.locator")
local status = require("yuumi.status")
local util = require("yuumi.util")

local M = {
  win = nil,
  buf = nil,
  namespace = vim.api.nvim_create_namespace("yuumi-board"),
  zoomed = false,
}

local STATUS_HIGHLIGHTS = {
  done = "YuumiBoardDone",
  pending = "YuumiBoardPending",
  skipped = "YuumiBoardMuted",
  stale = "YuumiBoardStale",
}

local function section(lines, title)
  table.insert(lines, "")
  table.insert(lines, "= " .. title .. " =")
end

local function panel(lines, title)
  table.insert(lines, "")
  table.insert(lines, title)
end

local function pad(value, width)
  value = value or ""
  if #value >= width then
    return value
  end

  return value .. string.rep(" ", width - #value)
end

local function combine_columns(left, right, left_width)
  local lines = {}
  local total = math.max(#left, #right)

  for index = 1, total do
    table.insert(lines, pad(left[index], left_width) .. " │ " .. (right[index] or ""))
  end

  return lines
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

local function add_files(lines)
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
    for anchor_index, anchor in ipairs(task.anchors or {}) do
      local marker = task_index == state.cursor.task and anchor_index == state.cursor.anchor and ">" or " "
      local start_line = locator.range(0, anchor)
      table.insert(lines, string.format("   %s %s L%d %s", marker, status_label(anchor), start_line, anchor.id or task.summary or "patch"))
    end
  end
end

local function add_status(lines)
  local counts = progress_counts()
  panel(lines, "[1]-Status")
  table.insert(lines, string.format("%d patches · %d done · %d pending · %d stale · %d skipped", counts.total, counts.done, counts.pending, counts.stale, counts.skipped))
  table.insert(lines, state.plan.title or "untitled")
end

local function add_patches(lines)
  panel(lines, "[2]-Patches")
  for task_index, task in ipairs(state.plan.tasks or {}) do
    for anchor_index, anchor in ipairs(task.anchors or {}) do
      local marker = task_index == state.cursor.task and anchor_index == state.cursor.anchor and "▶" or " "
      local label = anchor.id or task.summary or "patch"
      table.insert(lines, string.format("%s %s %s", marker, status_label(anchor), label))
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

local function add_highlight(buf, row, from_text, group)
  local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
  if not line then
    return
  end

  local start_col = line:find(from_text, 1, true)
  if not start_col then
    return
  end

  vim.api.nvim_buf_set_extmark(buf, M.namespace, row, start_col - 1, {
    end_col = start_col - 1 + #from_text,
    hl_group = group,
  })
end

local function highlight_line(buf, row, line)
  if line:match("%[%d%]%-") then
    vim.api.nvim_buf_add_highlight(buf, M.namespace, "YuumiBoardSection", row, 0, -1)
  end

  if line:match("^= .+ =$") then
    vim.api.nvim_buf_add_highlight(buf, M.namespace, "YuumiBoardSection", row, 0, -1)
  end

  for current_status, group in pairs(STATUS_HIGHLIGHTS) do
    add_highlight(buf, row, current_status, group)
  end

  add_highlight(buf, row, "Status:", "YuumiBoardKey")
  add_highlight(buf, row, "Arquivo:", "YuumiBoardKey")
  add_highlight(buf, row, "Linha alvo:", "YuumiBoardKey")
  add_highlight(buf, row, "Linhas alvo:", "YuumiBoardKey")
  add_highlight(buf, row, "Resumo:", "YuumiBoardKey")
  add_highlight(buf, row, "current", "YuumiBoardPending")
  add_highlight(buf, row, "next", "YuumiBoardMuted")
end

local function window_size()
  if M.zoomed then
    local width = math.min(vim.o.columns - 4, math.max(96, math.floor(vim.o.columns * 0.92)))
    local height = math.min(vim.o.lines - 6, math.max(16, math.floor(vim.o.lines * 0.85)))
    return width, height
  end

  local width = math.min(vim.o.columns - 4, math.max(84, math.floor(vim.o.columns * 0.82)))
  local height = math.min(#M.lines(), math.max(12, vim.o.lines - 6))
  return width, height
end

local function window_config(width, height)
  return {
    relative = "editor",
    row = 2,
    col = math.max(1, math.floor((vim.o.columns - width) / 2)),
    width = width,
    height = height,
    border = "rounded",
    title = M.zoomed and " Yuumi Zoom " or " Yuumi ",
    style = "minimal",
  }
end

local function apply_highlights(buf)
  vim.api.nvim_buf_clear_namespace(buf, M.namespace, 0, -1)

  for row, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
    highlight_line(buf, row - 1, line)
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

function M.lines()
  if not state.plan then
    return { "Yuumi Plan", "", "No plan loaded" }
  end

  local lines = {
    "Yuumi Plan",
    state.plan.title or "untitled",
  }

  local left = {}
  local right = {}

  add_status(left)
  add_patches(left)
  add_files(left)
  add_actions(left)

  add_current_details(right)
  add_validate_summary(right)
  add_plan_queue(right)

  local board_width = math.min(vim.o.columns - 4, math.max(84, math.floor(vim.o.columns * 0.82)))
  vim.list_extend(lines, combine_columns(left, right, math.max(38, math.floor(board_width * 0.38))))
  return lines
end

function M.close()
  if M.win and vim.api.nvim_win_is_valid(M.win) then
    vim.api.nvim_win_close(M.win, true)
  end
  M.win = nil
  M.buf = nil
end

function M.setup_highlights()
  vim.api.nvim_set_hl(0, "YuumiBoardSection", { default = true, fg = "#56d4dd", bold = true })
  vim.api.nvim_set_hl(0, "YuumiBoardKey", { default = true, fg = "#61afef" })
  vim.api.nvim_set_hl(0, "YuumiBoardPending", { default = true, fg = "#e5c07b" })
  vim.api.nvim_set_hl(0, "YuumiBoardDone", { default = true, fg = "#98c379" })
  vim.api.nvim_set_hl(0, "YuumiBoardStale", { default = true, fg = "#e06c75" })
  vim.api.nvim_set_hl(0, "YuumiBoardMuted", { default = true, fg = "#7f8da3" })
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
  apply_highlights(M.buf)

  local width, height = window_size()

  if M.win and vim.api.nvim_win_is_valid(M.win) then
    vim.api.nvim_win_set_config(M.win, window_config(width, height))
    return
  end

  M.win = vim.api.nvim_open_win(M.buf, false, window_config(width, height))
end

function M.toggle_zoom()
  M.zoomed = not M.zoomed
  M.open()
end

function M.refresh()
  if not M.buf or not vim.api.nvim_buf_is_valid(M.buf) then
    return
  end

  vim.api.nvim_buf_set_lines(M.buf, 0, -1, false, M.lines())
  apply_highlights(M.buf)
end

return M
