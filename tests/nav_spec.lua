local board = require("yuumi.board")
local minit = require("tests.minit")
local nav = require("yuumi.nav")
local sidebar = require("yuumi.sidebar")
local state = require("yuumi.state")

local function setup_plan()
  state.plan = {
    version = 1,
    title = "Navigation plan",
    tasks = {
      {
        id = "task",
        file = "examples/sample.lua",
        summary = "Task",
        anchors = {
          { id = "first", line = 1, writeText = { "local first = 1" } },
          { id = "second", line = 1, writeText = { "local second = 2" } },
        },
      },
    },
  }
  state.plan_root = vim.uv.cwd()
  state.cursor = { task = 1, anchor = 1 }
  state.index_tasks()
end

local function cleanup()
  sidebar.close()
  board.close()
  local sample_buf = vim.fn.bufnr(vim.uv.cwd() .. "/examples/sample.lua")
  if sample_buf ~= -1 then
    pcall(vim.api.nvim_buf_delete, sample_buf, { force = true })
  end
  state.reset()
  vim.cmd("only!")
  vim.cmd("enew!")
end

minit.test("nav next does not open legacy board panels", function()
  cleanup()
  setup_plan()

  nav.next()

  minit.eq(2, state.cursor.anchor)
  minit.eq(nil, next(board.wins))

  cleanup()
end)

minit.test("nav done refreshes sidebar without opening board panels", function()
  cleanup()
  setup_plan()
  state.ai_review = { status = "approved", patch = "first" }
  vim.cmd.edit(vim.uv.cwd() .. "/examples/sample.lua")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "local first = 1" })
  sidebar.show()

  nav.mark_status("done")

  minit.eq(nil, next(board.wins))
  minit.truthy(sidebar.is_open())
  minit.eq("done", state.plan.tasks[1].anchors[1].status)

  cleanup()
end)
