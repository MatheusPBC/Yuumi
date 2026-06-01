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
  minit.truthy(table.concat(lines, "\n"):match("= Fazer ="))

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

  minit.truthy(text:match("= Codigo esperado ="))
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

  minit.truthy(text:match("! stale"))

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
  minit.truthy(text:match("Status: ● pending"))
  minit.truthy(text:match("= Por que ="))
  minit.truthy(text:match("Show command dispatch inputs%."))
  minit.truthy(text:match("= Codigo esperado ="))
  minit.truthy(text:match("logger%.info%("))

  cleanup()
end)

minit.test("renders organized sections with progress summary", function()
  cleanup()

  state.plan = {
    version = 1,
    title = "Organized plan",
    tasks = {
      {
        id = "first",
        file = "src/handlers/very/long/path/to/first/lambda_function.py",
        summary = "First file",
        anchors = {
          { id = "one", line = 10, status = "done", writeText = { "first()" } },
          {
            id = "two",
            line = 20,
            reason = "Explain second patch.",
            guidance = "Apply second patch.",
            writeText = { "second()" },
            doneWhen = { "Second patch exists" },
          },
        },
      },
      {
        id = "second",
        file = "src/handlers/second/lambda_function.py",
        summary = "Second file",
        anchors = {
          { id = "three", line = 30, status = "skipped", writeText = { "third()" } },
        },
      },
    },
  }
  state.plan_root = vim.uv.cwd()
  state.cursor = { task = 1, anchor = 2 }
  state.index_tasks()
  vim.cmd.edit(vim.uv.cwd() .. "/src/handlers/very/long/path/to/first/lambda_function.py")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "first()", "placeholder" })

  local text = table.concat(board.lines(), "\n")

  minit.truthy(text:match("3 patches · 1 done · 1 pending · 0 stale · 1 skipped"))
  minit.truthy(text:match("= Arquivos ="))
  minit.truthy(text:match("= Patch atual ="))
  minit.truthy(text:match("= Por que ="))
  minit.truthy(text:match("= Fazer ="))
  minit.truthy(text:match("= Codigo esperado ="))
  minit.truthy(text:match("= Checklist ="))
  minit.truthy(text:match("%.%.%./to/first/lambda_function%.py"))

  cleanup()
end)

minit.test("opens a wider board window", function()
  cleanup()

  local original_columns = vim.o.columns
  vim.o.columns = 120
  state.plan = {
    version = 1,
    title = "Wide board plan",
    tasks = {
      {
        id = "task",
        file = "examples/sample.lua",
        summary = "Task",
        anchors = { { id = "anchor", line = 1, writeText = { "local value = 1" } } },
      },
    },
  }
  state.plan_root = vim.uv.cwd()
  state.cursor = { task = 1, anchor = 1 }
  state.index_tasks()

  board.open()
  local config = vim.api.nvim_win_get_config(board.win)

  minit.eq(52, config.width)

  board.close()
  vim.o.columns = original_columns
  cleanup()
end)

minit.test("renders plan queue with current and next patches", function()
  cleanup()

  state.plan = {
    version = 1,
    title = "Queue plan",
    tasks = {
      {
        id = "task",
        file = "examples/sample.lua",
        summary = "Task",
        anchors = {
          { id = "first", line = 1, status = "done", writeText = { "first()" } },
          { id = "second", line = 2, writeText = { "second()" } },
          { id = "third", line = 3, writeText = { "third()" } },
        },
      },
    },
  }
  state.plan_root = vim.uv.cwd()
  state.cursor = { task = 1, anchor = 2 }
  state.index_tasks()

  local text = table.concat(board.lines(), "\n")

  minit.truthy(text:match("= Plano ="))
  minit.truthy(text:match("▶ current%s+second"))
  minit.truthy(text:match("○ next%s+third"))
  minit.eq(nil, text:match("next%s+first"))

  cleanup()
end)

minit.test("adds board highlights for sections and statuses", function()
  cleanup()

  state.plan = {
    version = 1,
    title = "Highlight plan",
    tasks = {
      {
        id = "task",
        file = "examples/sample.lua",
        summary = "Task",
        anchors = {
          { id = "anchor", line = 1, writeText = { "local value = 1" } },
        },
      },
    },
  }
  state.plan_root = vim.uv.cwd()
  state.cursor = { task = 1, anchor = 1 }
  state.index_tasks()

  board.open()
  local extmarks = vim.api.nvim_buf_get_extmarks(board.buf, -1, 0, -1, { details = true })
  local groups = {}

  for _, mark in ipairs(extmarks) do
    groups[mark[4].hl_group] = true
  end

  minit.truthy(groups.YuumiBoardSection)
  minit.truthy(groups.YuumiBoardPending)
  minit.truthy(groups.YuumiBoardKey)

  board.close()
  cleanup()
end)

minit.test("truncates lambda paths with enough parent context", function()
  cleanup()

  state.plan = {
    version = 1,
    title = "Lambda path plan",
    tasks = {
      {
        id = "send",
        file = "src/handlers/smartly_send_device_command_appsync/function/lambda_function.py",
        summary = "Send command",
        anchors = { { id = "send-log", line = 1, writeText = { "logger.info('send')" } } },
      },
      {
        id = "ingest",
        file = "src/handlers/smartly_ingest_devices_appsync/function/lambda_function.py",
        summary = "Ingest devices",
        anchors = { { id = "ingest-log", line = 1, writeText = { "logger.info('ingest')" } } },
      },
    },
  }
  state.plan_root = vim.uv.cwd()
  state.cursor = { task = 1, anchor = 1 }
  state.index_tasks()

  local text = table.concat(board.lines(), "\n")

  minit.truthy(text:match("%.%.%./smartly_send_device_command_appsync/function/lambda_function%.py"))
  minit.truthy(text:match("%.%.%./smartly_ingest_devices_appsync/function/lambda_function%.py"))

  cleanup()
end)
