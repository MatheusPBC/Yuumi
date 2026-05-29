local minit = require("tests.minit")
local marks = require("yuumi.marks")
local plan = require("yuumi.plan")
local state = require("yuumi.state")

local original_cwd = vim.uv.cwd()

local function cleanup()
  state.reset()
  vim.cmd("cd " .. vim.fn.fnameescape(original_cwd))
  vim.cmd("enew!")
end

minit.test("loads relative plan from current buffer project when cwd differs", function()
  cleanup()

  vim.cmd.edit(original_cwd .. "/examples/sample.lua")
  vim.cmd("cd /tmp")

  minit.truthy(plan.load(".agent/current-plan.json"))
  minit.eq("Yuumi example plan", state.plan.title)

  cleanup()
end)

minit.test("renders target file anchors using plan root when cwd differs", function()
  cleanup()

  vim.cmd.edit(original_cwd .. "/examples/sample.lua")
  vim.cmd("cd /tmp")

  minit.truthy(plan.load(".agent/current-plan.json"))
  marks.render_buffer(0)

  local extmarks = vim.api.nvim_buf_get_extmarks(0, state.namespace, 0, -1, {})
  minit.eq(1, #extmarks)

  cleanup()
end)
