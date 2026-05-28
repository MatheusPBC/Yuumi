local minit = require("tests.minit")
local plan = require("yuumi.plan")

minit.test("validates inline suggestion shape", function()
  local err = plan.validate({
    version = 1,
    tasks = {
      {
        file = "x.lua",
        anchors = {
          {
            line = 1,
            inlineSuggestions = {
              { trigger = "local" },
            },
          },
        },
      },
    },
  })

  minit.eq("tasks[1].anchors[1].inlineSuggestions[1].insertText must be a string", err)
end)

minit.test("validates doneWhen shape", function()
  local err = plan.validate({
    version = 1,
    tasks = {
      {
        file = "x.lua",
        anchors = {
          { line = 1, doneWhen = { 1 } },
        },
      },
    },
  })

  minit.eq("tasks[1].anchors[1].doneWhen[1] must be a string", err)
end)
