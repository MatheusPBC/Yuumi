local minit = require("tests.minit")
local plans = require("yuumi.plans")

minit.test("lists Yuumi plan json files from .agent", function()
  local items = plans.list()
  local labels = table.concat(vim.tbl_map(function(item)
    return item.path
  end, items), "\n")

  minit.truthy(labels:match("%.agent/current%-plan%.json"))
  minit.truthy(labels:match("%.agent/html%-plan%.json"))
  minit.truthy(labels:match("%.agent/test%-plan%.json"))
end)

minit.test("lists Yuumi plan json files from .agent/plans", function()
  local dir = vim.uv.cwd() .. "/.agent/plans"
  vim.fn.mkdir(dir, "p")
  local file = io.open(dir .. "/nested-plan.json", "w")
  file:write('{"version":1,"title":"Nested","tasks":[]}')
  file:close()

  local items = plans.list()
  local labels = table.concat(vim.tbl_map(function(item)
    return item.path
  end, items), "\n")

  minit.truthy(labels:match("%.agent/plans/nested%-plan%.json"))
  os.remove(dir .. "/nested-plan.json")
end)
