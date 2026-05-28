local marks = require("yuumi.marks")
local ui = require("yuumi.ui")
local util = require("yuumi.util")

local M = {}

local function context_lines(title)
  local task, anchor = marks.anchor_at_cursor()

  if not task or not anchor then
    util.notify("No Yuumi anchor at cursor", vim.log.levels.WARN)
    return nil
  end

  return {
    "# " .. title,
    "",
    "This MVP uses a mock GPT adapter.",
    "Configure a real adapter later to send this context to your provider.",
    "",
    "Task: " .. (task.summary or task.id or "unknown"),
    "File: " .. task.file,
    "Line: " .. anchor.line,
    "",
    "Reason:",
    anchor.reason or "not provided",
    "",
    "Guidance:",
    anchor.guidance or "not provided",
  }
end

local function show(title)
  local lines = context_lines(title)
  if lines then
    ui.float(lines, { title = "Yuumi " .. title })
  end
end

function M.explain()
  show("Explain")
end

function M.suggest()
  show("Suggest")
end

function M.check()
  show("Check")
end

function M.reanchor()
  show("Reanchor")
end

function M.breakdown()
  show("Breakdown")
end

return M
