local commands = require("yuumi.commands")
local minit = require("tests.minit")
local state = require("yuumi.state")

local opened = false

minit.test("load command opens task picker after loading plan", function()
  state.reset()
  opened = false

  commands.load({ args = ".agent/current-plan.json" }, function()
    opened = true
  end)

  minit.truthy(opened)
  minit.eq("Yuumi example plan", state.plan.title)
end)
