local blink = require("yuumi.blink")
local minit = require("tests.minit")
local plan = require("yuumi.plan")
local state = require("yuumi.state")

local function cleanup()
  state.reset()
  vim.cmd("enew!")
end

minit.test("blink source returns inline suggestions for current file", function()
  cleanup()

  minit.truthy(plan.load(".agent/current-plan.json"))
  vim.cmd.edit("examples/sample.lua")

  local source = blink.new({})
  local completions
  source:get_completions({}, function(result)
    completions = result.items
  end)

  minit.eq("local function greeting(name)", completions[1].insertText)
  minit.truthy(completions[1].documentation.value:match("Create a local function"))

  cleanup()
end)
