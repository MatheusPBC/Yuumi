local board = require("yuumi.board")
local commands = require("yuumi.commands")
local minit = require("tests.minit")
local sidebar = require("yuumi.sidebar")
local state = require("yuumi.state")

local function setup_plan()
  state.plan = {
    version = 1,
    title = "Sidebar plan",
    tasks = {
      {
        id = "task",
        file = "examples/sample.lua",
        summary = "Task",
        anchors = { { id = "patch", line = 1, writeText = { "local value = 1" } } },
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
  state.reset()
  vim.cmd("only!")
  vim.cmd("enew!")
end

minit.test("sidebar opens as persistent right split", function()
  cleanup()
  setup_plan()
  vim.cmd.edit(vim.uv.cwd() .. "/examples/sample.lua")
  local source_win = vim.api.nvim_get_current_win()

  sidebar.show()

  minit.truthy(sidebar.is_open())
  minit.eq(source_win, vim.api.nvim_get_current_win())
  minit.eq("yuumi", vim.bo[sidebar.buf].filetype)
  minit.eq("", vim.api.nvim_win_get_config(sidebar.win).relative)
  minit.truthy(table.concat(vim.api.nvim_buf_get_lines(sidebar.buf, 0, -1, false), "\n"):match("AI Review"))

  cleanup()
end)

minit.test("sidebar toggle hides without closing source window", function()
  cleanup()
  setup_plan()
  vim.cmd.edit(vim.uv.cwd() .. "/examples/sample.lua")
  local source_win = vim.api.nvim_get_current_win()

  sidebar.toggle()
  minit.truthy(sidebar.is_open())
  sidebar.toggle()

  minit.eq(false, sidebar.is_open())
  minit.eq(true, vim.api.nvim_win_is_valid(source_win))

  cleanup()
end)

minit.test("YuumiBoard command toggles sidebar split", function()
  cleanup()
  setup_plan()
  commands.create()

  vim.cmd.YuumiBoard()
  minit.truthy(sidebar.is_open())
  minit.eq("", vim.api.nvim_win_get_config(sidebar.win).relative)

  vim.cmd.YuumiBoard()
  minit.eq(false, sidebar.is_open())

  cleanup()
end)

minit.test("YuumiBoard command closes legacy floating board panels", function()
  cleanup()
  setup_plan()
  commands.create()

  board.open()
  minit.truthy(board.wins.status and vim.api.nvim_win_is_valid(board.wins.status))

  vim.cmd.YuumiBoard()

  minit.eq(nil, next(board.wins))
  minit.truthy(sidebar.is_open())

  cleanup()
end)

minit.test("YuumiBoard command closes orphan sidebar splits", function()
  cleanup()
  setup_plan()
  commands.create()

  local orphan_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[orphan_buf].filetype = "yuumi"
  vim.api.nvim_buf_set_name(orphan_buf, "Yuumi Plan")
  vim.cmd("botright vertical new")
  local orphan_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(orphan_win, orphan_buf)

  minit.truthy(vim.api.nvim_win_is_valid(orphan_win))

  vim.cmd.YuumiBoard()

  minit.eq(false, vim.api.nvim_win_is_valid(orphan_win))
  minit.truthy(sidebar.is_open())

  cleanup()
end)

minit.test("sidebar opens selected patch in source window", function()
  cleanup()
  setup_plan()
  table.insert(state.plan.tasks[1].anchors, { id = "second", line = 2, writeText = { "local second = 2" } })
  vim.cmd.edit(vim.uv.cwd() .. "/examples/sample.lua")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "local value = 1", "local second = 2" })
  vim.bo.modified = false
  local source_win = vim.api.nvim_get_current_win()

  sidebar.show()
  local selected_line
  for line, action in pairs(sidebar.line_actions) do
    if action.anchor_index == 2 then
      selected_line = line
      break
    end
  end

  minit.truthy(selected_line)
  vim.api.nvim_set_current_win(sidebar.win)
  vim.api.nvim_win_set_cursor(sidebar.win, { selected_line, 0 })

  minit.eq(true, sidebar.open_selected())

  minit.eq(source_win, vim.api.nvim_get_current_win())
  minit.eq(2, state.cursor.anchor)
  minit.truthy(sidebar.is_open())

  cleanup()
end)
