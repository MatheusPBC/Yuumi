local board = require("yuumi.board")
local minit = require("tests.minit")
local plan = require("yuumi.plan")
local state = require("yuumi.state")

local function cleanup()
  state.reset()
  vim.cmd("enew!")
end

minit.test("builds board lines with plan files and current guidance", function()
  cleanup()

  minit.truthy(plan.load(".agent/test-plan.json"))
  state.cursor = { task = 1, anchor = 1 }

  local lines = board.lines()

  minit.eq("Yuumi Plan", lines[1])
  minit.truthy(table.concat(lines, "\n"):match("examples/index%.html"))
  minit.truthy(table.concat(lines, "\n"):match("Criar um HTML completo"))
  minit.truthy(table.concat(lines, "\n"):match("Instrucao:"))

  cleanup()
end)

minit.test("shows current file anchor details before global cursor details", function()
  cleanup()

  state.plan = {
    version = 1,
    title = "Multi file plan",
    tasks = {
      {
        id = "lua-task",
        file = "examples/sample.lua",
        status = "pending",
        summary = "Lua task",
        anchors = {
          {
            id = "lua-anchor",
            line = 1,
            endLine = 2,
            kind = "manual-edit",
            guidance = "Edit Lua file",
            writeText = { "local value = 1" },
            doneWhen = { "Lua file changed" },
          },
        },
      },
      {
        id = "html-task",
        file = "examples/index.html",
        status = "pending",
        summary = "HTML task",
        anchors = {
          {
            id = "html-anchor",
            line = 1,
            endLine = 2,
            kind = "manual-edit",
            guidance = "Edit HTML file",
            writeText = { "<!doctype html>" },
            doneWhen = { "HTML file changed" },
          },
        },
      },
    },
  }
  state.plan_root = vim.uv.cwd()
  state.cursor = { task = 1, anchor = 1 }
  state.index_tasks()
  vim.cmd.edit(vim.uv.cwd() .. "/examples/index.html")

  local text = table.concat(board.lines(), "\n")

  minit.truthy(text:match("Patch atual"))
  minit.truthy(text:match("Arquivo: examples/index%.html"))
  minit.truthy(text:match("Linha: 1"))
  minit.truthy(text:match("Edit HTML file"))
  minit.eq(nil, text:match("Edit Lua file"))

  cleanup()
end)

minit.test("renders writeText as exact lines to copy", function()
  cleanup()

  minit.truthy(plan.load(".agent/test-plan.json"))
  state.cursor = { task = 1, anchor = 1 }

  local text = table.concat(board.lines(), "\n")

  minit.truthy(text:match("Como deve ficar:"))
  minit.truthy(text:match("<!doctype html>"))
  minit.truthy(text:match("<html lang=\"pt%-BR\">"))

  cleanup()
end)

minit.test("shows stale status when done anchor text is missing", function()
  cleanup()

  state.plan = {
    version = 1,
    title = "Stale plan",
    tasks = {
      {
        id = "task",
        file = "examples/sample.lua",
        summary = "Add line",
        anchors = {
          {
            id = "anchor",
            line = 1,
            status = "done",
            guidance = "Add value",
            writeText = { "local value = 1" },
          },
        },
      },
    },
  }
  state.plan_root = vim.uv.cwd()
  state.cursor = { task = 1, anchor = 1 }
  state.index_tasks()
  vim.cmd.edit(vim.uv.cwd() .. "/examples/sample.lua")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "local other = 2" })

  local text = table.concat(board.lines(), "\n")

  minit.truthy(text:match("%[stale%]"))

  cleanup()
end)

minit.test("renders current patch as board-first execution guide", function()
  cleanup()

  state.plan = {
    version = 1,
    title = "Board plan",
    tasks = {
      {
        id = "task",
        file = "examples/sample.lua",
        summary = "Add debug log",
        anchors = {
          {
            id = "patch",
            line = 4,
            reason = "Show command dispatch inputs.",
            guidance = "Insert this log before publishing.",
            writeText = {
              "logger.info(",
              "    \"dispatch\",",
              ")",
            },
            doneWhen = { "Log appears before publish" },
          },
        },
      },
    },
  }
  state.plan_root = vim.uv.cwd()
  state.cursor = { task = 1, anchor = 1 }
  state.index_tasks()
  vim.cmd.edit(vim.uv.cwd() .. "/examples/sample.lua")

  local text = table.concat(board.lines(), "\n")

  minit.truthy(text:match("Patch atual"))
  minit.truthy(text:match("Arquivo: examples/sample%.lua"))
  minit.truthy(text:match("Linha: 4"))
  minit.truthy(text:match("Status: pending"))
  minit.truthy(text:match("Explicacao:"))
  minit.truthy(text:match("Show command dispatch inputs%."))
  minit.truthy(text:match("Como deve ficar:"))
  minit.truthy(text:match("logger%.info%("))

  cleanup()
end)
