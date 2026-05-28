local gpt = require("yuumi.gpt")
local inline = require("yuumi.inline")
local marks = require("yuumi.marks")
local nav = require("yuumi.nav")
local plan = require("yuumi.plan")
local ui = require("yuumi.ui")

local M = {}

local function load(opts)
  if plan.load(opts.args) then
    marks.render_all_loaded_buffers()
  end
end

function M.create()
  vim.api.nvim_create_user_command("YuumiLoad", load, {
    nargs = "?",
    complete = "file",
    desc = "Load a Yuumi plan JSON",
    force = true,
  })

  vim.api.nvim_create_user_command("YuumiFiles", function()
    if plan.ensure_loaded() then
      nav.files()
    end
  end, { desc = "List Yuumi files and anchors", force = true })

  vim.api.nvim_create_user_command("YuumiNext", function()
    if plan.ensure_loaded() then
      nav.next()
    end
  end, { desc = "Jump to next Yuumi anchor", force = true })

  vim.api.nvim_create_user_command("YuumiPrev", function()
    if plan.ensure_loaded() then
      nav.prev()
    end
  end, { desc = "Jump to previous Yuumi anchor", force = true })

  vim.api.nvim_create_user_command("YuumiHover", function()
    if plan.ensure_loaded() then
      local task, anchor = marks.anchor_at_cursor()
      ui.hover(task, anchor)
    end
  end, { desc = "Show Yuumi guidance for cursor", force = true })

  vim.api.nvim_create_user_command("YuumiStatus", function()
    if plan.ensure_loaded() then
      ui.status()
    end
  end, { desc = "Show Yuumi plan status", force = true })

  vim.api.nvim_create_user_command("YuumiDone", function()
    nav.mark_status("done")
  end, { desc = "Mark current Yuumi anchor as done", force = true })

  vim.api.nvim_create_user_command("YuumiSkip", function()
    nav.mark_status("skipped")
  end, { desc = "Mark current Yuumi anchor as skipped", force = true })

  vim.api.nvim_create_user_command("YuumiAcceptInline", function()
    inline.accept_current()
  end, { desc = "Accept current Yuumi inline suggestion", force = true })

  vim.api.nvim_create_user_command("YuumiExplain", gpt.explain, { desc = "Explain current Yuumi anchor", force = true })
  vim.api.nvim_create_user_command("YuumiSuggest", gpt.suggest, { desc = "Suggest an alternative for current Yuumi anchor", force = true })
  vim.api.nvim_create_user_command("YuumiCheck", gpt.check, { desc = "Check current edit against Yuumi anchor", force = true })
  vim.api.nvim_create_user_command("YuumiReanchor", gpt.reanchor, { desc = "Reanchor current Yuumi task", force = true })
  vim.api.nvim_create_user_command("YuumiBreakdown", gpt.breakdown, { desc = "Break down current Yuumi task", force = true })
end

return M
