local minit = require("tests.minit")
local plans = require("yuumi.plans")

minit.test("shows cwd and searched paths when no plans are found", function()
  local original_cwd = vim.uv.cwd()
  local temp_dir = vim.fn.tempname()
  vim.fn.mkdir(temp_dir, "p")
  vim.uv.chdir(temp_dir)

  local message = nil
  local original_notify = vim.notify
  vim.notify = function(text)
    message = text
  end

  plans.select(function() end)

  vim.notify = original_notify
  vim.uv.chdir(original_cwd)

  minit.truthy(message:match("No Yuumi plans found in"))
  minit.truthy(message:match(vim.pesc(temp_dir)))
  minit.truthy(message:match("cwd:"))
  minit.truthy(message:match(":YuumiLoad /absolute/path/to/plan%.json"))
end)

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
