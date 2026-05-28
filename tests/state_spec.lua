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
  nav.mark_status("done")

  local file = assert(io.open(config.options.state_path, "r"))
  local persisted = vim.json.decode(file:read("*a"))
  file:close()

  minit.eq("done", persisted.anchors["task-1:anchor-1"].status)

  cleanup()
end)
