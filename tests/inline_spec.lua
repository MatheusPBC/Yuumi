local inline = require("yuumi.inline")
local minit = require("tests.minit")
local plan = require("yuumi.plan")
local nav = require("yuumi.nav")
local state = require("yuumi.state")

local function cleanup()
  state.reset()
  vim.cmd("enew!")
end

minit.test("accepts deterministic inline suggestion into current buffer", function()
  cleanup()

  minit.truthy(plan.load(".agent/current-plan.json"))
  nav.next()
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "local" })
  vim.api.nvim_win_set_cursor(0, { 1, 5 })
  inline.refresh()

  inline.accept_current()

  minit.eq("local function greeting(name)", vim.api.nvim_get_current_line())

  cleanup()
end)

minit.test("accepts inline suggestion at current cursor when stored column is stale", function()
  cleanup()

  minit.truthy(plan.load(".agent/current-plan.json"))
  nav.next()
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "local" })
  vim.api.nvim_win_set_cursor(0, { 1, 5 })
  inline.refresh()

  state.inline.col = 99
  inline.accept_current()

  minit.eq("local function greeting(name)", vim.api.nvim_get_current_line())

  cleanup()
end)
