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
