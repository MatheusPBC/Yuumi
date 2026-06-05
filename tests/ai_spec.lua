local ai = require("yuumi.ai")
local commands = require("yuumi.commands")
local config = require("yuumi.config")
local minit = require("tests.minit")
local state = require("yuumi.state")

local function cleanup()
  config.setup({ state_path = ".agent/yuumi-test-state.json" })
  state.reset()
  vim.cmd("enew!")
end

local function setup_plan()
  state.plan = {
    version = 1,
    title = "AI first plan",
    tasks = {
      {
        id = "task",
        file = "examples/sample.lua",
        summary = "Add AI guided log",
        anchors = {
          {
            id = "patch",
            line = 1,
            reason = "Expose parsed command inputs.",
            guidance = "Insert the structured log before validation.",
            writeText = { "logger.info('parsed')" },
          },
        },
      },
    },
  }
  state.plan_root = vim.uv.cwd()
  state.cursor = { task = 1, anchor = 1 }
  state.index_tasks()
  vim.cmd.edit(vim.uv.cwd() .. "/examples/sample.lua")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "local current = true" })
end

minit.test("builds AI check payload for current patch", function()
  cleanup()
  setup_plan()

  local payload = ai.build_payload("check")

  minit.eq("check", payload.action)
  minit.eq("AI first plan", payload.plan.title)
  minit.eq("examples/sample.lua", payload.patch.file)
  minit.eq("patch", payload.patch.id)
  minit.eq("Expose parsed command inputs.", payload.patch.reason)
  minit.eq("logger.info('parsed')", payload.expected[1])
  minit.truthy(payload.validation.missing > 0)
  minit.truthy(payload.buffer:match("local current = true"))

  cleanup()
end)

minit.test("AI check requires configured provider command", function()
  cleanup()
  setup_plan()

  local result, err = ai.check_current()

  minit.eq(nil, result)
  minit.truthy(err:match("No Yuumi AI command configured"))

  cleanup()
end)

minit.test("AI check stores provider output in state", function()
  cleanup()
  setup_plan()
  config.setup({ state_path = ".agent/yuumi-test-state.json", ai_command = { "cat" } })

  local result, err = ai.check_current()

  minit.eq(nil, err)
  minit.eq("reviewed", result.status)
  minit.truthy(result.output:match('"action":"check"'))
  minit.eq(result, state.ai_review)

  cleanup()
end)

minit.test("AI check runs provider from plan root", function()
  cleanup()
  setup_plan()
  config.setup({
    state_path = ".agent/yuumi-test-state.json",
    ai_command = { "sh", "-c", "pwd; cat >/dev/null" },
  })

  local result, err = ai.check_current()

  minit.eq(nil, err)
  minit.eq(vim.uv.cwd() .. "\n", result.output)

  cleanup()
end)

minit.test("YuumiCheck command runs AI review", function()
  cleanup()
  setup_plan()
  config.setup({ state_path = ".agent/yuumi-test-state.json", ai_command = { "cat" } })
  commands.create()

  vim.cmd.YuumiCheck()

  minit.eq("reviewed", state.ai_review.status)
  minit.truthy(state.ai_review.output:match('"action":"check"'))

  cleanup()
end)
