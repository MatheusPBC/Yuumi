local minit = require("tests.minit")
local nav = require("yuumi.nav")
local persist = require("yuumi.persist")
local plan = require("yuumi.plan")
local state = require("yuumi.state")
local util = require("yuumi.util")
local config = require("yuumi.config")

local function cleanup()
  os.remove(config.options.state_path)
  state.reset()
end

minit.test("resets persisted status and clears anchor statuses", function()
  cleanup()

  minit.truthy(plan.load(".agent/current-plan.json"))
  nav.next()
  nav.mark_status("done")
  minit.truthy(vim.uv.fs_stat(util.resolve_path(config.options.state_path)))

  persist.reset()

  minit.eq(nil, state.plan.tasks[1].anchors[1].status)
  minit.eq(nil, vim.uv.fs_stat(util.resolve_path(config.options.state_path)))

  cleanup()
end)
