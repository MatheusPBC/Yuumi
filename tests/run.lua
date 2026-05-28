vim.opt.runtimepath:append(vim.uv.cwd())

local minit = require("tests.minit")

require("tests.state_spec")
require("tests.inline_spec")
require("tests.status_spec")
require("tests.reset_spec")
require("tests.validation_spec")
require("tests.reanchor_spec")
require("tests.gpt_spec")

minit.run()
