local board = require("yuumi.board")
local minit = require("tests.minit")
local plan = require("yuumi.plan")
local state = require("yuumi.state")

local function cleanup()
  state.reset()
  vim.cmd("enew!")
end

minit.test("builds board lines with plan files and current guidance", function()
  cleanup()

  minit.truthy(plan.load(".agent/test-plan.json"))
  state.cursor = { task = 1, anchor = 1 }

  local lines = board.lines()

  minit.eq("Yuumi Plan", lines[1])
  minit.truthy(table.concat(lines, "\n"):match("examples/index%.html"))
  minit.truthy(table.concat(lines, "\n"):match("Criar um HTML completo"))
  minit.truthy(table.concat(lines, "\n"):match("Write:"))

  cleanup()
end)

minit.test("shows current file anchor details before global cursor details", function()
  cleanup()

  state.plan = {
    version = 1,
    title = "Multi file plan",
    tasks = {
      {
        id = "lua-task",
        file = "examples/sample.lua",
        status = "pending",
        summary = "Lua task",
        anchors = {
          {
            id = "lua-anchor",
            line = 1,
            endLine = 2,
            kind = "manual-edit",
            guidance = "Edit Lua file",
            writeText = { "local value = 1" },
            doneWhen = { "Lua file changed" },
          },
        },
      },
      {
        id = "html-task",
        file = "examples/index.html",
        status = "pending",
        summary = "HTML task",
        anchors = {
          {
            id = "html-anchor",
            line = 1,
            endLine = 2,
            kind = "manual-edit",
            guidance = "Edit HTML file",
            writeText = { "<!doctype html>" },
            doneWhen = { "HTML file changed" },
          },
        },
      },
    },
  }
  state.plan_root = vim.uv.cwd()
  state.cursor = { task = 1, anchor = 1 }
  state.index_tasks()
  vim.cmd.edit(vim.uv.cwd() .. "/examples/index.html")

  local text = table.concat(board.lines(), "\n")

  minit.truthy(text:match("Current file"))
  minit.truthy(text:match("examples/index%.html:1"))
  minit.truthy(text:match("Edit HTML file"))
  minit.eq(nil, text:match("Edit Lua file"))

  cleanup()
end)

minit.test("renders writeText as exact lines to copy", function()
  cleanup()

  minit.truthy(plan.load(".agent/test-plan.json"))
  state.cursor = { task = 1, anchor = 1 }

  local text = table.concat(board.lines(), "\n")

  minit.truthy(text:match("Write exactly:"))
  minit.truthy(text:match("<!doctype html>"))
  minit.truthy(text:match("<html lang=\"pt%-BR\">"))

  cleanup()
end)
