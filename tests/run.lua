vim.opt.runtimepath:append(vim.uv.cwd())

require("yuumi.config").setup({ state_path = ".agent/yuumi-test-state.json" })

local minit = require("tests.minit")

require("tests.state_spec")
require("tests.inline_spec")
require("tests.status_spec")
require("tests.reset_spec")
require("tests.validation_spec")
require("tests.reanchor_spec")
require("tests.gpt_spec")
require("tests.blink_spec")
require("tests.session_spec")
require("tests.docs_spec")
require("tests.path_spec")
require("tests.load_spec")

minit.run()
