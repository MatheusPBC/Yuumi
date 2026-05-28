local state = require("yuumi.state")
local util = require("yuumi.util")

local M = {}

function M.new(opts)
  return setmetatable({ opts = opts or {} }, { __index = M })
end

function M:enabled()
  return state.plan ~= nil
end

local function completion_kind_text()
  local ok, types = pcall(require, "blink.cmp.types")
  if ok then
    return types.CompletionItemKind.Text
  end

  return 1
end

local function current_file_tasks(ctx)
  local bufnr = ctx and ctx.bufnr or vim.api.nvim_get_current_buf()
  local relative = util.buf_relative_path(bufnr)
  return state.tasks_by_file[relative] or {}
end

local function item_for(task, anchor, suggestion, index)
  return {
    label = suggestion.insertText,
    kind = completion_kind_text(),
    insertText = suggestion.insertText,
    filterText = suggestion.trigger or suggestion.insertText,
    sortText = string.format("%04d", index),
    documentation = {
      kind = "markdown",
      value = table.concat({
        "# Yuumi suggestion",
        "",
        task.summary or task.id or "Plan suggestion",
        "",
        anchor.guidance or anchor.reason or "No guidance provided.",
      }, "\n"),
    },
  }
end

function M:get_completions(ctx, callback)
  local items = {}

  if state.plan then
    for _, task_index in ipairs(current_file_tasks(ctx)) do
      local task = state.plan.tasks[task_index]
      for _, anchor in ipairs(task.anchors or {}) do
        for _, suggestion in ipairs(anchor.inlineSuggestions or {}) do
          table.insert(items, item_for(task, anchor, suggestion, #items + 1))
        end
      end
    end
  end

  callback({
    items = items,
    is_incomplete_backward = false,
    is_incomplete_forward = false,
  })

  return function() end
end

return M
