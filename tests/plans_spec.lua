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
