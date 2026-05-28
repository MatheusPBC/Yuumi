vim.opt.runtimepath:append(vim.uv.cwd())

local minit = require("tests.minit")

require("tests.state_spec")
require("tests.inline_spec")

minit.run()
