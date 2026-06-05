local ai = require("yuumi.ai")
local board = require("yuumi.board")
local config = require("yuumi.config")
local gpt = require("yuumi.gpt")
local inline = require("yuumi.inline")
local marks = require("yuumi.marks")
local nav = require("yuumi.nav")
local persist = require("yuumi.persist")
local plan = require("yuumi.plan")
local plans = require("yuumi.plans")
local reanchor = require("yuumi.reanchor")
local sidebar = require("yuumi.sidebar")
local state = require("yuumi.state")
local ui = require("yuumi.ui")
local validate = require("yuumi.validate")

local M = {}

function M.main()
  if not state.plan then
    M.load({ args = "" })
    return
  end

  sidebar.show()
  ui.select_task("Yuumi patches", function(task_index, anchor_index)
    nav.open(task_index, anchor_index)
  end)
end

function M.load(opts, after_load)
  if not opts.args or opts.args == "" then
    plans.select(function(path)
      M.load({ args = path }, after_load or function()
        sidebar.show()
      end)
    end)
    return
  end

  if plan.load(opts.args) then
    marks.render_all_loaded_buffers()
    if after_load then
      after_load()
    elseif config.options.open_files_on_load then
      sidebar.show()
      nav.files()
    end
  end
end

local function with_plan(callback)
  return function()
    if plan.ensure_loaded() then
      callback()
    end
  end
end

local function reanchor_current()
  if reanchor.current_buffer() then
    marks.render_buffer(0)
    return
  end

  gpt.reanchor()
end

local function check_current()
  ai.show_check()
  sidebar.refresh()
end

local function reset_state()
  persist.reset()
  marks.render_all_loaded_buffers()
end

local function command(name, callback, opts)
  opts = vim.tbl_extend("force", { force = true }, opts or {})
  vim.api.nvim_create_user_command(name, callback, opts)
end

function M.create()
  command("Yuumi", M.main, { desc = "Open Yuumi plan or patch picker" })
  command("YuumiLoad", M.load, {
    nargs = "?",
    complete = "file",
    desc = "Load a Yuumi plan JSON",
  })
  command("YuumiPlans", function()
    plans.select(function(path)
      M.load({ args = path })
    end)
  end, { desc = "Pick and load a Yuumi plan" })
  command("YuumiFiles", with_plan(nav.files), { desc = "List Yuumi files and anchors" })
  command("YuumiNext", with_plan(nav.next), { desc = "Jump to next Yuumi anchor" })
  command("YuumiPrev", with_plan(nav.prev), { desc = "Jump to previous Yuumi anchor" })
  command("YuumiHover", with_plan(function()
    local task, anchor = marks.anchor_at_cursor()
    ui.hover(task, anchor)
  end), { desc = "Show Yuumi guidance for cursor" })
  command("YuumiStatus", with_plan(ui.status), { desc = "Show Yuumi plan status" })
  command("YuumiValidate", with_plan(validate.show), { desc = "Validate current edit against Yuumi writeText" })
  command("YuumiBoard", sidebar.toggle, { desc = "Show Yuumi guidance board" })
  command("YuumiBoardZoom", board.toggle_zoom, { desc = "Toggle Yuumi board zoom" })
  command("YuumiDone", function()
    nav.mark_status("done")
  end, { desc = "Mark current Yuumi anchor as done" })
  command("YuumiSkip", function()
    nav.mark_status("skipped")
  end, { desc = "Mark current Yuumi anchor as skipped" })
  command("YuumiResetState", reset_state, { desc = "Reset persisted Yuumi state" })
  command("YuumiAcceptInline", inline.accept_current, { desc = "Accept current Yuumi inline suggestion" })
  command("YuumiExplain", gpt.explain, { desc = "Explain current Yuumi anchor" })
  command("YuumiSuggest", gpt.suggest, { desc = "Suggest an alternative for current Yuumi anchor" })
  command("YuumiCheck", with_plan(check_current), { desc = "Check current edit against Yuumi anchor" })
  command("YuumiReanchor", with_plan(reanchor_current), { desc = "Reanchor current Yuumi task" })
  command("YuumiBreakdown", gpt.breakdown, { desc = "Break down current Yuumi task" })
end

return M
