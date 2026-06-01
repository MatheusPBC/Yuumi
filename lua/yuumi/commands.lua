local board = require("yuumi.board")
local gpt = require("yuumi.gpt")
local inline = require("yuumi.inline")
local marks = require("yuumi.marks")
local nav = require("yuumi.nav")
local persist = require("yuumi.persist")
local plan = require("yuumi.plan")
local plans = require("yuumi.plans")
local reanchor = require("yuumi.reanchor")
local ui = require("yuumi.ui")
local validate = require("yuumi.validate")

local M = {}

function M.main()
  if not require("yuumi.state").plan then
    M.load({ args = "" })
    return
  end

  board.open()
  ui.select_task("Yuumi patches", function(task_index, anchor_index)
    nav.open(task_index, anchor_index)
  end)
end

function M.load(opts, after_load)
  if not opts.args or opts.args == "" then
    plans.select(function(path)
      M.load({ args = path }, after_load or function()
        board.open()
      end)
    end)
    return
  end

  if plan.load(opts.args) then
    marks.render_all_loaded_buffers()
    if after_load then
      after_load()
    elseif require("yuumi.config").options.open_files_on_load then
      board.open()
      nav.files()
    end
  end
end

function M.create()
  vim.api.nvim_create_user_command("Yuumi", function()
    M.main()
  end, { desc = "Open Yuumi plan or patch picker", force = true })

  vim.api.nvim_create_user_command("YuumiLoad", M.load, {
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

  vim.api.nvim_create_user_command("YuumiPlans", function()
    plans.select(function(path)
      M.load({ args = path })
    end)
  end, { desc = "Pick and load a Yuumi plan", force = true })

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

  vim.api.nvim_create_user_command("YuumiValidate", function()
    if plan.ensure_loaded() then
      validate.show()
    end
  end, { desc = "Validate current edit against Yuumi writeText", force = true })

  vim.api.nvim_create_user_command("YuumiBoard", function()
    board.open()
  end, { desc = "Show Yuumi guidance board", force = true })

  vim.api.nvim_create_user_command("YuumiBoardZoom", function()
    board.toggle_zoom()
  end, { desc = "Toggle Yuumi board zoom", force = true })

  vim.api.nvim_create_user_command("YuumiDone", function()
    nav.mark_status("done")
  end, { desc = "Mark current Yuumi anchor as done", force = true })

  vim.api.nvim_create_user_command("YuumiSkip", function()
    nav.mark_status("skipped")
  end, { desc = "Mark current Yuumi anchor as skipped", force = true })

  vim.api.nvim_create_user_command("YuumiResetState", function()
    persist.reset()
    marks.render_all_loaded_buffers()
  end, { desc = "Reset persisted Yuumi state", force = true })

  vim.api.nvim_create_user_command("YuumiAcceptInline", function()
    inline.accept_current()
  end, { desc = "Accept current Yuumi inline suggestion", force = true })

  vim.api.nvim_create_user_command("YuumiExplain", gpt.explain, { desc = "Explain current Yuumi anchor", force = true })
  vim.api.nvim_create_user_command("YuumiSuggest", gpt.suggest, { desc = "Suggest an alternative for current Yuumi anchor", force = true })
  vim.api.nvim_create_user_command("YuumiCheck", function()
    if plan.ensure_loaded() then
      validate.show()
    end
  end, { desc = "Check current edit against Yuumi anchor", force = true })
  vim.api.nvim_create_user_command("YuumiReanchor", function()
    if reanchor.current_buffer() then
      marks.render_buffer(0)
      return
    end

    gpt.reanchor()
  end, { desc = "Reanchor current Yuumi task", force = true })
  vim.api.nvim_create_user_command("YuumiBreakdown", gpt.breakdown, { desc = "Break down current Yuumi task", force = true })
end

return M
