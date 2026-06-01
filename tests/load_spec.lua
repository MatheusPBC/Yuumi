local commands = require("yuumi.commands")
local minit = require("tests.minit")
local nav = require("yuumi.nav")
local plan = require("yuumi.plan")
local state = require("yuumi.state")

local opened = false

minit.test("load command opens task picker after loading plan", function()
  state.reset()
  opened = false

  commands.load({ args = ".agent/current-plan.json" }, function()
    opened = true
  end)

  minit.truthy(opened)
  minit.eq("Yuumi example plan", state.plan.title)
end)

minit.test("load command without args opens plan picker", function()
  state.reset()
  local selected_prompt = nil
  local original_select = vim.ui.select

  vim.ui.select = function(items, opts, callback)
    selected_prompt = opts.prompt
    callback(items[1])
  end

  commands.load({ args = "" })

  vim.ui.select = original_select
  minit.eq("Yuumi plans", selected_prompt)
  minit.truthy(state.plan)
end)

minit.test("explicit load path still loads that plan directly", function()
  state.reset()

  minit.truthy(plan.load(".agent/current-plan.json"))
  minit.eq("Yuumi example plan", state.plan.title)
end)

minit.test("YuumiFiles lists unique files instead of every anchor", function()
  state.reset()
  state.plan = {
    version = 1,
    title = "Two file plan",
    tasks = {
      {
        id = "first",
        file = "src/one.py",
        summary = "First file",
        anchors = {
          { id = "one-a", line = 10 },
          { id = "one-b", line = 20 },
        },
      },
      {
        id = "second",
        file = "src/two.py",
        summary = "Second file",
        anchors = {
          { id = "two-a", line = 30 },
          { id = "two-b", line = 40 },
          { id = "two-c", line = 50 },
        },
      },
    },
  }
  state.index_tasks()

  local item_count = nil
  local original_select = vim.ui.select
  vim.ui.select = function(items)
    item_count = #items
  end

  nav.files()

  vim.ui.select = original_select
  minit.eq(2, item_count)
end)

minit.test("normalizes version 2 patches into grouped tasks", function()
  local normalized = plan.normalize({
    version = 2,
    title = "Patch plan",
    patches = {
      {
        id = "one-a",
        file = "src/one.py",
        summary = "First patch",
        locator = { afterText = "a", beforeText = "b" },
        insert = { "logger.info('a')" },
        doneWhen = { "First patch exists" },
      },
      {
        id = "one-b",
        file = "src/one.py",
        summary = "Second patch",
        locator = { afterText = "b", beforeText = "c" },
        insert = { "logger.info('b')" },
        doneWhen = { "Second patch exists" },
      },
      {
        id = "two-a",
        file = "src/two.py",
        summary = "Third patch",
        locator = { afterText = "x", beforeText = "y" },
        insert = { "logger.info('x')" },
        doneWhen = { "Third patch exists" },
      },
    },
  })

  minit.eq(1, normalized.version)
  minit.eq(2, #normalized.tasks)
  minit.eq("src/one.py", normalized.tasks[1].file)
  minit.eq(2, #normalized.tasks[1].anchors)
  minit.eq("guided-patch", normalized.tasks[1].anchors[1].kind)
  minit.eq("insert-between", normalized.tasks[1].anchors[1].patch.mode)
  minit.eq("logger.info('a')", normalized.tasks[1].anchors[1].patch.writeText[1])
end)

minit.test("Yuumi command opens plan picker when no plan is loaded", function()
  state.reset()
  local selected_prompt = nil
  local original_select = vim.ui.select

  vim.ui.select = function(items, opts, callback)
    selected_prompt = opts.prompt
    callback(items[1])
  end

  commands.main()

  vim.ui.select = original_select
  minit.eq("Yuumi plans", selected_prompt)
  minit.truthy(state.plan)
end)

minit.test("Yuumi command opens patch picker when a plan is loaded", function()
  state.reset()
  state.plan = {
    version = 1,
    title = "Patch plan",
    tasks = {
      {
        id = "first",
        file = "src/one.py",
        summary = "First file",
        anchors = { { id = "one-a", line = 10 } },
      },
    },
  }

  local selected_prompt = nil
  local original_select = vim.ui.select
  vim.ui.select = function(_, opts)
    selected_prompt = opts.prompt
  end

  commands.main()

  vim.ui.select = original_select
  minit.eq("Yuumi patches", selected_prompt)
end)

minit.test("done status is not persisted when writeText is missing", function()
  state.reset()
  state.plan = {
    version = 1,
    title = "Done guard plan",
    tasks = {
      {
        id = "task",
        file = "examples/sample.lua",
        summary = "Add line",
        anchors = {
          {
            id = "anchor",
            line = 1,
            writeText = { "local expected = 1" },
          },
        },
      },
    },
  }
  state.plan_root = vim.uv.cwd()
  state.cursor = { task = 1, anchor = 1 }
  state.index_tasks()
  vim.cmd.edit(vim.uv.cwd() .. "/examples/sample.lua")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "local actual = 2" })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })

  nav.mark_status("done")

  minit.eq(nil, state.plan.tasks[1].anchors[1].status)
end)
