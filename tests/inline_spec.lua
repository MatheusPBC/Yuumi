local inline = require("yuumi.inline")
local config = require("yuumi.config")
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

minit.test("keeps inline suggestion when user types beyond trigger", function()
  cleanup()

  minit.truthy(plan.load(".agent/current-plan.json"))
  nav.next()
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "local f" })
  vim.api.nvim_win_set_cursor(0, { 1, 7 })
  inline.refresh()

  minit.truthy(state.inline)
  inline.accept_current()

  minit.eq("local function greeting(name)", vim.api.nvim_get_current_line())

  cleanup()
end)

minit.test("suggests remaining writeText for a partially typed line", function()
  cleanup()

  minit.truthy(plan.load(".agent/test-plan.json"))
  nav.next()
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "    <meta name=\"viewport\" conte" })
  vim.api.nvim_win_set_cursor(0, { 1, 31 })
  inline.refresh()

  minit.truthy(state.inline)
  inline.accept_current()

  minit.eq(
    "    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">",
    vim.api.nvim_get_current_line()
  )

  cleanup()
end)

minit.test("suggests next missing writeText line on an empty line", function()
  cleanup()

  minit.truthy(plan.load(".agent/test-plan.json"))
  nav.next()
  vim.api.nvim_buf_set_lines(0, 0, -1, false, {
    "<!doctype html>",
    "<html lang=\"pt-BR\">",
    "",
  })
  vim.api.nvim_win_set_cursor(0, { 3, 0 })
  inline.refresh()

  minit.truthy(state.inline)
  inline.accept_current()

  minit.eq("  <head>", vim.api.nvim_get_current_line())

  cleanup()
end)

minit.test("uses AI inline fallback when deterministic suggestions do not match", function()
  cleanup()

  config.setup({
    state_path = ".agent/yuumi-test-state.json",
    inline_ai_enabled = true,
    gpt_command = { "sh", "-c", "printf ' generated-by-ai'" },
  })
  minit.truthy(plan.load(".agent/test-plan.json"))
  nav.next()
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "custom" })
  vim.api.nvim_win_set_cursor(0, { 1, 6 })
  inline.refresh()

  minit.truthy(state.inline)
  inline.accept_current()

  minit.eq("custom generated-by-ai", vim.api.nvim_get_current_line())

  config.setup({ state_path = ".agent/yuumi-test-state.json" })
  cleanup()
end)

minit.test("accepts multiline AI inline fallback without nvim_buf_set_text errors", function()
  cleanup()

  config.setup({
    state_path = ".agent/yuumi-test-state.json",
    inline_ai_enabled = true,
    gpt_command = { "sh", "-c", "printf ' first\\nsecond'" },
  })
  minit.truthy(plan.load(".agent/test-plan.json"))
  nav.next()
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "custom" })
  vim.api.nvim_win_set_cursor(0, { 1, 6 })
  inline.refresh()

  minit.truthy(state.inline)
  minit.truthy(inline.accept_current())

  minit.eq({ "custom first", "second" }, vim.api.nvim_buf_get_lines(0, 0, 2, false))

  config.setup({ state_path = ".agent/yuumi-test-state.json" })
  cleanup()
end)

minit.test("accepts carriage-return AI inline fallback without nvim_buf_set_text errors", function()
  cleanup()

  config.setup({
    state_path = ".agent/yuumi-test-state.json",
    inline_ai_enabled = true,
    gpt_command = { "sh", "-c", "printf ' first\\rsecond'" },
  })
  minit.truthy(plan.load(".agent/test-plan.json"))
  nav.next()
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "custom" })
  vim.api.nvim_win_set_cursor(0, { 1, 6 })
  inline.refresh()

  minit.truthy(state.inline)
  minit.truthy(inline.accept_current())

  minit.eq({ "custom first", "second" }, vim.api.nvim_buf_get_lines(0, 0, 2, false))

  config.setup({ state_path = ".agent/yuumi-test-state.json" })
  cleanup()
end)

minit.test("returns suffix for insert-mode expr mappings without editing buffer", function()
  cleanup()

  minit.truthy(plan.load(".agent/test-plan.json"))
  nav.next()
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "    <meta name=\"viewport\" conte" })
  vim.api.nvim_win_set_cursor(0, { 1, 31 })
  inline.refresh()

  local suffix = inline.accept()

  minit.eq("nt=\"width=device-width, initial-scale=1.0\">", suffix)
  minit.eq("    <meta name=\"viewport\" conte", vim.api.nvim_get_current_line())

  cleanup()
end)
