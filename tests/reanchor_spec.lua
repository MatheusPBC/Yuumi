local minit = require("tests.minit")
local reanchor = require("yuumi.reanchor")

minit.test("reanchors by anchorText in current buffer", function()
  local anchor = { line = 1, endLine = 1, anchorText = "target_call()" }
  vim.cmd("enew!")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, {
    "before()",
    "target_call()",
    "after()",
  })

  minit.truthy(reanchor.anchor_in_buffer(0, anchor))
  minit.eq(2, anchor.line)
  minit.eq(2, anchor.endLine)
end)
