local state = require("yuumi.state")
local util = require("yuumi.util")

local M = {}

local function status_for(anchor)
  return anchor.status or "pending"
end

local function lines_for_anchor(task, anchor)
  local lines = {
    "# " .. (task.summary or task.id or "Yuumi task"),
    "",
  }

  if anchor.reason then
    table.insert(lines, "Why:")
    table.insert(lines, anchor.reason)
    table.insert(lines, "")
  end

  if anchor.guidance then
    table.insert(lines, "Guidance:")
    table.insert(lines, anchor.guidance)
    table.insert(lines, "")
  end

  if anchor.doneWhen then
    table.insert(lines, "Done when:")
    for _, item in ipairs(anchor.doneWhen) do
      table.insert(lines, "- " .. item)
    end
  end

  return lines
end

function M.float(lines, opts)
  opts = opts or {}
  local width = opts.width or 72
  local height = math.min(#lines, opts.height or 18)
  local bufnr = vim.api.nvim_create_buf(false, true)

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].filetype = "markdown"

  vim.api.nvim_open_win(bufnr, false, {
    relative = "cursor",
    row = 1,
    col = 0,
    width = width,
    height = height,
    border = "rounded",
    title = opts.title or "Yuumi",
    style = "minimal",
  })
end

function M.hover(task, anchor)
  if not task or not anchor then
    util.notify("No Yuumi anchor at cursor", vim.log.levels.WARN)
    return
  end

  M.float(lines_for_anchor(task, anchor), { title = "Yuumi Guidance" })
end

function M.select_task(title, callback)
  if not state.plan then
    util.notify("No plan loaded", vim.log.levels.WARN)
    return
  end

  local items = {}
  for task_index, task in ipairs(state.plan.tasks) do
    for anchor_index, anchor in ipairs(task.anchors or {}) do
      table.insert(items, {
        label = M.task_label(task, anchor),
        task_index = task_index,
        anchor_index = anchor_index,
      })
    end
  end

  vim.ui.select(items, {
    prompt = title or "Yuumi tasks",
    format_item = function(item)
      return item.label
    end,
  }, function(item)
    if item then
      callback(item.task_index, item.anchor_index)
    end
  end)
end

function M.task_label(task, anchor)
  return string.format(
    "[%s] %s:%d %s",
    status_for(anchor),
    task.file,
    anchor.line,
    task.summary or anchor.guidance or task.id or "planned edit"
  )
end

function M.status()
  if not state.plan then
    util.notify("No plan loaded", vim.log.levels.WARN)
    return
  end

  local pending = 0
  local done = 0
  local skipped = 0
  local total = 0

  for _, task in ipairs(state.plan.tasks or {}) do
    for _, anchor in ipairs(task.anchors or {}) do
      total = total + 1
      if anchor.status == "done" then
        done = done + 1
      elseif anchor.status == "skipped" then
        skipped = skipped + 1
      else
        pending = pending + 1
      end
    end
  end

  M.float({
    "# Yuumi Status",
    "",
    "Plan: " .. (state.plan.title or "untitled"),
    "Path: " .. (state.plan_path or "unknown"),
    "",
    "Anchors: " .. total,
    "Pending: " .. pending,
    "Done: " .. done,
    "Skipped: " .. skipped,
  }, { title = "Yuumi Status", width = 54 })
end

return M
