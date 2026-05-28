local config = require("yuumi.config")
local gpt = require("yuumi.gpt")
local minit = require("tests.minit")

minit.test("runs configured GPT command with JSON payload", function()
  config.setup({ gpt_command = { "cat" } })

  local result = gpt.run_command({ action = "Explain", file = "x.lua" })

  minit.truthy(result:match('"action":"Explain"'))
  minit.truthy(result:match('"file":"x.lua"'))

  config.setup({})
end)
