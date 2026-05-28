local minit = require("tests.minit")
local util = require("yuumi.util")

local function read(path)
  local content = assert(util.read_file(path))
  return content
end

minit.test("README documents plan contract and GPT command model", function()
  local content = read("README.md")

  minit.truthy(content:match("current%-plan%.json"))
  minit.truthy(content:match("gpt_command"))
  minit.truthy(content:match("OPENAI_API_KEY"))
  minit.truthy(content:match("blink%.cmp"))
end)
