local marks = require("yuumi.marks")
local minit = require("tests.minit")
local ui = require("yuumi.ui")

minit.test("formats status in picker labels and virtual text", function()
  local task = { file = "lua/example.lua", summary = "Edit example" }
  local anchor = { line = 7, status = "done" }

  minit.eq("[done] lua/example.lua:7 Edit example", ui.task_label(task, anchor))
  minit.eq("yuumi: [done] Edit example", marks.virtual_text(task, anchor))
  minit.eq("YuumiAnchorDone", marks.highlight_group(anchor))
end)
