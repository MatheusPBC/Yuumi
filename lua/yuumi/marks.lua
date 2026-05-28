local config = require("yuumi.config")
local state = require("yuumi.state")
local util = require("yuumi.util")

local M = {}

local status_highlights = {
  pending = "YuumiAnchorPending",
  done = "YuumiAnchorDone",
  skipped = "YuumiAnchorSkipped",
}

local status_labels = {
  pending = "pending",
  done = "done",
  skipped = "skipped",
}

local function status_for(anchor)
  return status_labels[anchor.status] or "pending"
end

local function summary_for(task, anchor)
  return anchor.summary or task.summary or anchor.guidance or "planned edit"
end

function M.setup_highlights()
  vim.api.nvim_set_hl(0, config.options.highlight_group, {
    default = true,
    bg = "#2d3328",
  })
  vim.api.nvim_set_hl(0, "YuumiAnchorPending", { default = true, bg = "#2d3328" })
  vim.api.nvim_set_hl(0, "YuumiAnchorDone", { default = true, bg = "#1f3a2d" })
  vim.api.nvim_set_hl(0, "YuumiAnchorSkipped", { default = true, bg = "#3a2f1f" })
end

function M.highlight_group(anchor)
  return status_highlights[anchor.status] or status_highlights.pending
end

function M.virtual_text(task, anchor)
  return string.format(
    "%s[%s] %s",
    config.options.virtual_text_prefix,
    status_for(anchor),
    summary_for(task, anchor)
  )
end

function M.clear(bufnr)
  vim.api.nvim_buf_clear_namespace(bufnr or 0, state.namespace, 0, -1)
end

function M.render_buffer(bufnr)
  bufnr = bufnr or 0
  M.clear(bufnr)

  if not state.plan then
    return
  end

  local relative = util.buf_relative_path(bufnr)
  local task_indexes = state.tasks_by_file[relative]

  if not task_indexes then
    return
  end

  local line_count = vim.api.nvim_buf_line_count(bufnr)

  for _, task_index in ipairs(task_indexes) do
    local task = state.plan.tasks[task_index]

    for anchor_index, anchor in ipairs(task.anchors or {}) do
      local start_line = util.clamp(anchor.line, 1, line_count) - 1
      local end_line = util.clamp(anchor.endLine or anchor.line, 1, line_count)
      local text = M.virtual_text(task, anchor)

      vim.api.nvim_buf_set_extmark(bufnr, state.namespace, start_line, 0, {
        end_row = end_line,
        hl_group = M.highlight_group(anchor),
        hl_eol = true,
        virt_text = { { text, "Comment" } },
        virt_text_pos = "eol",
        priority = 120,
      })
    end
  end
end

function M.render_all_loaded_buffers()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      M.render_buffer(bufnr)
    end
  end
end

function M.anchor_at_cursor()
  if not state.plan then
    return nil, nil, nil
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local relative = util.buf_relative_path(bufnr)
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local task_indexes = state.tasks_by_file[relative] or {}

  for _, task_index in ipairs(task_indexes) do
    local task = state.plan.tasks[task_index]
    for anchor_index, anchor in ipairs(task.anchors or {}) do
      local end_line = anchor.endLine or anchor.line
      if row >= anchor.line and row <= end_line then
        return task, anchor, { task = task_index, anchor = anchor_index }
      end
    end
  end

  return nil, nil, nil
end

return M
