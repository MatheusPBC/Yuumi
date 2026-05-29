local util = require("yuumi.util")

local M = {}

local plan_dirs = {
  ".agent/plans",
  ".agent",
}

local function is_plan_file(name)
  return name:match("%.json$") and name:match("plan")
end

function M.list()
  local items = {}

  for _, plan_dir in ipairs(plan_dirs) do
    local resolved_dir = util.resolve_existing_path(plan_dir)
    local handle = resolved_dir and vim.uv.fs_scandir(resolved_dir) or nil

    if handle then
      while true do
        local name, kind = vim.uv.fs_scandir_next(handle)
        if not name then
          break
        end

        if kind == "file" and is_plan_file(name) then
          table.insert(items, { label = name, path = plan_dir .. "/" .. name })
        end
      end
    end
  end

  table.sort(items, function(left, right)
    return left.path < right.path
  end)

  return items
end

function M.select(callback)
  local items = M.list()

  if #items == 0 then
    util.notify("No Yuumi plans found in .agent/plans or .agent", vim.log.levels.WARN)
    return
  end

  vim.ui.select(items, {
    prompt = "Yuumi plans",
    format_item = function(item)
      return item.path
    end,
  }, function(item)
    if item then
      callback(item.path)
    end
  end)
end

return M
