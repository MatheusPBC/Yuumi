local state = require("yuumi.state")
local view = require("yuumi.board_view")
local ui_cleanup = require("yuumi.ui_cleanup")
local util = require("yuumi.util")

local M = {
  win = nil,
  buf = nil,
  wins = {},
  bufs = {},
  line_actions = {},
  namespace = vim.api.nvim_create_namespace("yuumi-board"),
  zoomed = false,
}

local STATUS_HIGHLIGHTS = {
  done = "YuumiBoardDone",
  pending = "YuumiBoardPending",
  skipped = "YuumiBoardMuted",
  stale = "YuumiBoardStale",
}

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

local function apply_highlights(buf)
  vim.api.nvim_buf_clear_namespace(buf, M.namespace, 0, -1)

  for row, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
    highlight_line(buf, row - 1, line)
  end
end

function M.lines()
  return view.lines()
end

function M.open_selected(panel_name)
  local win = M.wins[panel_name]
  if not win or not vim.api.nvim_win_is_valid(win) then
    return false
  end

  local line = vim.api.nvim_win_get_cursor(win)[1]
  local action = M.line_actions[panel_name] and M.line_actions[panel_name][line]
  if not action then
    return false
  end

  M.close()
  require("yuumi.nav").open(action.task_index, action.anchor_index, { open_board = false })
  M.close()
  return true
end

local function open_panel(name, title, lines, config, actions)
  local buf = M.bufs[name]
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    buf = vim.api.nvim_create_buf(false, true)
    M.bufs[name] = buf
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].filetype = "yuumi"
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  apply_highlights(buf)
  M.line_actions[name] = actions or {}

  local win = M.wins[name]
  config.border = "single"
  config.title = " " .. title .. " "
  config.style = "minimal"

  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_set_config(win, config)
  else
    win = vim.api.nvim_open_win(buf, false, config)
    M.wins[name] = win
  end

  vim.wo[win].wrap = false
  vim.wo[win].cursorline = name == "patches" or name == "files"
  if next(M.line_actions[name]) then
    vim.keymap.set("n", "<CR>", function()
      M.open_selected(name)
    end, { buffer = buf, nowait = true, silent = true })
    vim.keymap.set("n", "<2-LeftMouse>", function()
      M.open_selected(name)
    end, { buffer = buf, nowait = true, silent = true })
  end
  return win
end

local function has_open_panel()
  for _, win in pairs(M.wins) do
    if vim.api.nvim_win_is_valid(win) then
      return true
    end
  end

  return false
end

local function panel_layout(width, height)
  local row = 2
  local col = math.max(1, math.floor((vim.o.columns - width) / 2))
  local gap = 1
  local left_width = math.max(32, math.floor(width * 0.38))
  local right_width = width - left_width - gap
  local status_height = 4
  local actions_height = 4
  local patches_height = math.max(7, math.floor(height * 0.25))
  local files_height = math.max(8, height - status_height - patches_height - actions_height - (gap * 3))
  local diagnostics_height = math.max(7, math.floor(height * 0.26))
  local ai_height = math.max(6, math.floor(height * 0.20))
  local preview_height = math.max(8, height - diagnostics_height - ai_height - (gap * 2))

  return {
    status = { relative = "editor", row = row, col = col, width = left_width, height = status_height },
    patches = { relative = "editor", row = row + status_height + gap, col = col, width = left_width, height = patches_height },
    files = { relative = "editor", row = row + status_height + patches_height + (gap * 2), col = col, width = left_width, height = files_height },
    actions = { relative = "editor", row = row + status_height + patches_height + files_height + (gap * 3), col = col, width = left_width, height = actions_height },
    preview = { relative = "editor", row = row, col = col + left_width + gap, width = right_width, height = preview_height },
    ai_review = { relative = "editor", row = row + preview_height + gap, col = col + left_width + gap, width = right_width, height = ai_height },
    diagnostics = { relative = "editor", row = row + preview_height + ai_height + (gap * 2), col = col + left_width + gap, width = right_width, height = diagnostics_height },
  }
end

function M.close()
  if M.win and vim.api.nvim_win_is_valid(M.win) then
    vim.api.nvim_win_close(M.win, true)
  end

  for _, win in pairs(M.wins) do
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  ui_cleanup.close_floats()

  M.win = nil
  M.buf = nil
  M.wins = {}
  M.bufs = {}
  M.line_actions = {}
end

function M.setup_highlights()
  vim.api.nvim_set_hl(0, "YuumiBoardSection", { default = true, fg = "#56d4dd", bold = true })
  vim.api.nvim_set_hl(0, "YuumiBoardKey", { default = true, fg = "#61afef" })
  vim.api.nvim_set_hl(0, "YuumiBoardPending", { default = true, fg = "#e5c07b" })
  vim.api.nvim_set_hl(0, "YuumiBoardDone", { default = true, fg = "#98c379" })
  vim.api.nvim_set_hl(0, "YuumiBoardStale", { default = true, fg = "#e06c75" })
  vim.api.nvim_set_hl(0, "YuumiBoardMuted", { default = true, fg = "#7f8da3" })
end

function M.open(opts)
  opts = opts or {}
  if not state.plan then
    util.notify("No plan loaded", vim.log.levels.WARN)
    return
  end

  ui_cleanup.close_sidebars()

  if has_open_panel() and not opts.force then
    M.close()
    return
  end

  local width, height = window_size()
  local layout = panel_layout(width, height)

  local status_lines, status_actions = view.panel_lines("status")
  local patches_lines, patches_actions = view.panel_lines("patches")
  local files_lines, files_actions = view.panel_lines("files")
  local actions_lines, actions_actions = view.panel_lines("actions")

  M.win = open_panel("status", "[1]-Status", status_lines, layout.status, status_actions)
  open_panel("patches", "[2]-Patches", patches_lines, layout.patches, patches_actions)
  open_panel("files", "[3]-Arquivos", files_lines, layout.files, files_actions)
  open_panel("actions", "[4]-Acoes", actions_lines, layout.actions, actions_actions)
  open_panel("preview", "[0]-Patch / Preview esperado", view.panel_lines("current"), layout.preview)
  open_panel("ai_review", "[6]-AI Review", view.panel_lines("ai_review"), layout.ai_review)
  open_panel("diagnostics", "[5]-Validate / Diagnostics", view.panel_lines("validate"), layout.diagnostics)
end

function M.toggle_zoom()
  M.zoomed = not M.zoomed
  M.open({ force = true })
end

function M.refresh()
  if state.plan then
    M.open({ force = true })
  end
end

return M
