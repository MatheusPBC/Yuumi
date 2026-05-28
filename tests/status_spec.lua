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

minit.test("formats rich virtual guidance lines", function()
  local task = { file = "lua/example.lua", summary = "Edit example" }
  local anchor = {
    line = 7,
    guidance = "Crie a função manualmente.",
    removeText = "Remova o print antigo.",
    doneWhen = { "A função existe" },
  }

  local lines = marks.virtual_lines(task, anchor)

  minit.eq("  Yuumi plan: Edit example", lines[1][1][1])
  minit.eq("  Write: Crie a função manualmente.", lines[2][1][1])
  minit.eq("  Remove: Remova o print antigo.", lines[3][1][1])
  minit.eq("  Done: A função existe", lines[4][1][1])
end)
