local minit = require("tests.minit")
local nav = require("yuumi.nav")
local plan = require("yuumi.plan")
local state = require("yuumi.state")
local validate = require("yuumi.validate")

local function cleanup()
  state.reset()
  vim.cmd("enew!")
end

minit.test("validates writeText lines already present in buffer", function()
  cleanup()

  minit.truthy(plan.load(".agent/test-plan.json"))
  nav.next()
  vim.api.nvim_buf_set_lines(0, 0, -1, false, {
    "<!doctype html>",
    "<html lang=\"pt-BR\">",
    "  <head>",
  })

  local result = validate.current_buffer()

  minit.eq(3, result.ok)
  minit.truthy(result.missing > 0)
  minit.eq(0, result.different)

  cleanup()
end)

minit.test("reports different lines that look close but do not match", function()
  cleanup()

  minit.truthy(plan.load(".agent/test-plan.json"))
  nav.next()
  vim.api.nvim_buf_set_lines(0, 0, -1, false, {
    "<!doctype html>",
    "<html lang=\"en\">",
  })

  local result = validate.current_buffer()
  local text = table.concat(validate.lines(result), "\n")

  minit.eq(1, result.ok)
  minit.eq(1, result.different)
  minit.truthy(text:match("Different"))
  minit.truthy(text:match("expected: <html lang=\"pt%-BR\">"))
  minit.truthy(text:match("actual:   <html lang=\"en\">"))

  cleanup()
end)

minit.test("validates the selected anchor when cursor is outside anchor range", function()
  cleanup()

  state.plan = {
    version = 1,
    title = "Active patch plan",
    tasks = {
      {
        id = "task",
        file = "examples/sample.lua",
        summary = "Add expected line",
        anchors = {
          {
            id = "anchor",
            line = 1,
            writeText = { "local expected = 1" },
          },
        },
      },
    },
  }
  state.cursor = { task = 1, anchor = 1 }
  state.index_tasks()
  vim.cmd.edit(vim.uv.cwd() .. "/examples/sample.lua")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, {
    "local expected = 1",
    "local cursor_is_here = true",
  })
  vim.api.nvim_win_set_cursor(0, { 2, 0 })

  local result, err = validate.current_buffer()

  minit.eq(nil, err)
  minit.eq(1, result.ok)
  minit.eq("anchor", result.anchor.id)

  cleanup()
end)
