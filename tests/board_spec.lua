local board = require("yuumi.board")
local minit = require("tests.minit")
local plan = require("yuumi.plan")
local sidebar = require("yuumi.sidebar")
local state = require("yuumi.state")

local function cleanup()
  sidebar.close()
  board.close()
  state.reset()
  vim.cmd("only!")
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
  minit.truthy(text:match("Linhas alvo: 1%-2"))
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
  minit.truthy(text:match("Linhas alvo: 4%-6"))
  minit.truthy(text:match("Status: ● pending"))
  minit.truthy(text:match("= Por que ="))
  minit.truthy(text:match("Show command dispatch inputs%."))
  minit.truthy(text:match("= Codigo esperado ="))
  minit.truthy(text:match("logger%.info%("))

  cleanup()
end)

minit.test("renders AI review panel from latest check", function()
  cleanup()

  state.plan = {
    version = 1,
    title = "AI review board plan",
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
  state.ai_review = {
    status = "reviewed",
    patch = "patch",
    output = "approved: patch matches the intent",
  }
  state.index_tasks()

  local text = table.concat(board.lines(), "\n")

  minit.truthy(text:match("AI Review"))
  minit.truthy(text:match("reviewed"))
  minit.truthy(text:match("approved: patch matches the intent"))

  cleanup()
end)

minit.test("renders multiline AI review errors as safe buffer lines", function()
  cleanup()

  state.plan = {
    version = 1,
    title = "AI error board plan",
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
  state.ai_review = {
    status = "blocked",
    patch = "patch",
    error = "Reading additional input from stdin...\nNot inside a trusted directory",
  }
  state.index_tasks()

  local lines = board.lines()

  for _, line in ipairs(lines) do
    minit.eq(nil, line:match("\n"))
  end

  cleanup()
end)

minit.test("renders current patch target line range", function()
  cleanup()

  state.plan = {
    version = 1,
    title = "Line range plan",
    tasks = {
      {
        id = "task",
        file = "examples/sample.lua",
        summary = "Add block",
        anchors = {
          {
            id = "patch",
            line = 8,
            endLine = 12,
            guidance = "Replace block",
            writeText = { "local value = 1" },
          },
        },
      },
    },
  }
  state.plan_root = vim.uv.cwd()
  state.cursor = { task = 1, anchor = 1 }
  state.index_tasks()

  local text = table.concat(board.lines(), "\n")

  minit.truthy(text:match("Linhas alvo: 8%-12"))
  minit.eq(nil, text:match("Linha: 8"))

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

  minit.truthy(text:match("3 patches"))
  minit.truthy(text:match("1 done"))
  minit.truthy(text:match("1 pending"))
  minit.truthy(text:match("skipped"))
  minit.truthy(text:match("= Arquivos ="))
  minit.truthy(text:match("= Patch atual ="))
  minit.truthy(text:match("= Por que ="))
  minit.truthy(text:match("= Fazer ="))
  minit.truthy(text:match("= Codigo esperado ="))
  minit.truthy(text:match("= Checklist ="))

  cleanup()
end)

minit.test("opens lazygit-style board panel windows", function()
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

  minit.truthy(board.wins.status)
  minit.truthy(board.wins.patches)
  minit.truthy(board.wins.files)
  minit.truthy(board.wins.actions)
  minit.truthy(board.wins.preview)
  minit.truthy(board.wins.diagnostics)
  minit.eq(37, vim.api.nvim_win_get_config(board.wins.status).width)
  minit.eq(60, vim.api.nvim_win_get_config(board.wins.preview).width)

  board.close()
  vim.o.columns = original_columns
  cleanup()
end)

minit.test("toggles board zoom size", function()
  cleanup()

  local original_columns = vim.o.columns
  local original_lines = vim.o.lines
  vim.o.columns = 120
  vim.o.lines = 40
  state.plan = {
    version = 1,
    title = "Zoom board plan",
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
  local normal_config = vim.api.nvim_win_get_config(board.win)
  board.toggle_zoom()
  local zoom_config = vim.api.nvim_win_get_config(board.win)
  board.toggle_zoom()
  local restored_config = vim.api.nvim_win_get_config(board.win)

  minit.eq(37, normal_config.width)
  minit.eq(41, zoom_config.width)
  minit.eq(4, zoom_config.height)
  minit.eq(37, restored_config.width)

  board.close()
  vim.o.columns = original_columns
  vim.o.lines = original_lines
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
  local groups = {}

  for _, buf in pairs(board.bufs) do
    for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buf, -1, 0, -1, { details = true })) do
      groups[mark[4].hl_group] = true
    end
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

  minit.truthy(text:match("smartly_send"))
  minit.truthy(text:match("smartly_ingest"))

  cleanup()
end)

minit.test("renders lazygit-style workbench panels", function()
  cleanup()

  state.plan = {
    version = 1,
    title = "Workbench plan",
    tasks = {
      {
        id = "task",
        file = "examples/sample.lua",
        summary = "Add log",
        anchors = {
          {
            id = "patch",
            line = 4,
            guidance = "Insert log",
            writeText = {
              "logger.info(",
              "  \"dispatch\",",
              ")",
            },
            doneWhen = { "Log exists" },
          },
        },
      },
    },
  }
  state.plan_root = vim.uv.cwd()
  state.cursor = { task = 1, anchor = 1 }
  state.index_tasks()

  local text = table.concat(board.lines(), "\n")

  minit.truthy(text:match("%[1%]%-Status"))
  minit.truthy(text:match("%[2%]%-Patches"))
  minit.truthy(text:match("%[3%]%-Arquivos"))
  minit.truthy(text:match("%[4%]%-Acoes"))
  minit.truthy(text:match("%[0%]%-Patch / Preview esperado"))
  minit.truthy(text:match("%[5%]%-Validate / Diagnostics"))
  minit.truthy(text:match("logger%.info%("))

  cleanup()
end)

minit.test("keeps workbench lines within board width", function()
  cleanup()

  local original_columns = vim.o.columns
  vim.o.columns = 100
  state.plan = {
    version = 1,
    title = "Add AppSync debug logs",
    tasks = {
      {
        id = "send",
        file = "src/handlers/smartly_send_device_command_appsync/function/lambda_function.py",
        summary = "Guided patches for a very long lambda path",
        anchors = {
          {
            id = "log-parsed-command-input",
            line = 1,
            reason = "Shows the command input parsed before validation.",
            guidance = "Insert this structured log before the validation branch.",
            writeText = {
              "logger.info(",
              "    \"AppSync device command input parsed\",",
              "    extra={",
              "        \"request_id\": request_id,",
              "        \"device_lookup_id\": device_lookup_id,",
              "        \"command_type\": command_type,",
              "        \"has_payload\": payload is not None,",
              "        \"user_id\": user_id,",
              "    },",
              ")",
            },
            doneWhen = { "The log appears before validation" },
          },
        },
      },
    },
  }
  state.plan_root = vim.uv.cwd()
  state.cursor = { task = 1, anchor = 1 }
  state.index_tasks()

  local max_width = math.min(vim.o.columns - 4, math.max(84, math.floor(vim.o.columns * 0.82)))
  for _, line in ipairs(board.lines()) do
    if vim.fn.strdisplaywidth(line) > max_width then
      error(string.format("line exceeds board width %d: %s", max_width, line))
    end
  end

  vim.o.columns = original_columns
  cleanup()
end)

minit.test("board open toggles panel windows closed", function()
  cleanup()

  state.plan = {
    version = 1,
    title = "Toggle board plan",
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
  minit.truthy(board.wins.status and vim.api.nvim_win_is_valid(board.wins.status))

  board.open()
  minit.eq(nil, next(board.wins))

  cleanup()
end)

minit.test("board close removes orphan yuumi floating windows", function()
  cleanup()

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].filetype = "yuumi"
  local win = vim.api.nvim_open_win(buf, false, {
    relative = "editor",
    row = 1,
    col = 1,
    width = 30,
    height = 5,
    border = "single",
    title = " [3]-Arquivos ",
  })

  minit.truthy(vim.api.nvim_win_is_valid(win))
  board.close()
  minit.eq(false, vim.api.nvim_win_is_valid(win))

  cleanup()
end)

minit.test("board refresh does not open closed board", function()
  cleanup()
  minit.truthy(plan.load(".agent/test-plan.json"))

  board.refresh()

  minit.eq(nil, next(board.wins))

  cleanup()
end)

minit.test("board open closes orphan Yuumi Plan sidebar splits", function()
  cleanup()

  state.plan = {
    version = 1,
    title = "Sidebar cleanup plan",
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

  sidebar.show()
  local win = sidebar.win

  minit.truthy(vim.api.nvim_win_is_valid(win))

  board.open()

  minit.eq(false, vim.api.nvim_win_is_valid(win))
  minit.truthy(board.wins.status and vim.api.nvim_win_is_valid(board.wins.status))

  cleanup()
end)

minit.test("enter on files panel opens selected patch", function()
  cleanup()

  state.plan = {
    version = 1,
    title = "File navigation plan",
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

  board.open()
  local selected_line = nil
  for line, action in pairs(board.line_actions.files) do
    if action.task_index == 1 and action.anchor_index == 2 then
      selected_line = line
      break
    end
  end

  minit.truthy(selected_line)
  vim.api.nvim_win_set_cursor(board.wins.files, { selected_line, 0 })

  minit.truthy(board.open_selected("files"))
  minit.eq(2, state.cursor.anchor)
  minit.eq(nil, next(board.wins))
  minit.truthy(vim.api.nvim_buf_get_name(0):match("examples/sample%.lua"))

  cleanup()
end)
