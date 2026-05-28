local minit = require("tests.minit")
local nav = require("yuumi.nav")
local persist = require("yuumi.persist")
local plan = require("yuumi.plan")
local state = require("yuumi.state")
local config = require("yuumi.config")

local function cleanup()
  os.remove(config.options.state_path)
  state.reset()
  vim.cmd("enew!")
end

minit.test("persists last plan path and cursor", function()
  cleanup()

  minit.truthy(plan.load(".agent/current-plan.json"))
  nav.next()
  persist.save()

  local session = persist.read_session()
  minit.eq(".agent/current-plan.json", session.plan_path)
  minit.eq(1, session.cursor.task)
  minit.eq(1, session.cursor.anchor)

  cleanup()
end)

minit.test("loads last plan from persisted session", function()
  cleanup()

  minit.truthy(plan.load(".agent/current-plan.json"))
  nav.next()
  persist.save()
  state.reset()

  minit.truthy(plan.resume())
  minit.eq("Yuumi example plan", state.plan.title)
  minit.eq(1, state.cursor.anchor)

  cleanup()
end)
