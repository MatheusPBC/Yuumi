local minit = require("tests.minit")
local plan = require("yuumi.plan")
local nav = require("yuumi.nav")
local state = require("yuumi.state")
local config = require("yuumi.config")

local function cleanup()
  os.remove(config.options.state_path)
  state.reset()
end

minit.test("persists anchor status to disk", function()
  cleanup()

  minit.truthy(plan.load(".agent/current-plan.json"))
  nav.next()
  state.ai_review = { status = "approved", patch = "anchor-1" }
  nav.mark_status("done")

  local file = assert(io.open(config.options.state_path, "r"))
  local persisted = vim.json.decode(file:read("*a"))
  file:close()

  minit.eq("done", persisted.anchors["task-1:anchor-1"].status)

  cleanup()
end)

minit.test("does not mark done without approved AI review", function()
  cleanup()

  state.plan = {
    version = 1,
    title = "AI approval plan",
    tasks = {
      {
        id = "task",
        file = "examples/sample.lua",
        summary = "Add expected line",
        anchors = {
          { id = "anchor", line = 1, writeText = { "local expected = 1" } },
        },
      },
    },
  }
  state.plan_root = vim.uv.cwd()
  state.cursor = { task = 1, anchor = 1 }
  state.index_tasks()
  vim.cmd.edit(vim.uv.cwd() .. "/examples/sample.lua")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "local expected = 1" })

  nav.mark_status("done")

  minit.eq(nil, state.plan.tasks[1].anchors[1].status)

  cleanup()
end)
