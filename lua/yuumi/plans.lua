local util = require("yuumi.util")

local M = {}

local plan_dirs = {
  ".agent/plans",
  ".agent",
}

local function is_plan_file(name)
  return name:match("%.json$") and name:match("plan")
end

local function searched_paths()
  local items = {}

  for _, plan_dir in ipairs(plan_dirs) do
    table.insert(items, util.resolve_existing_path(plan_dir) or util.join_path(util.root(), plan_dir))
  end

  return items
end

local function add_item(items, seen, path)
  if not path or seen[path] then
    return
  end

  seen[path] = true
  table.insert(items, {
    label = vim.fn.fnamemodify(path, ":."),
    path = vim.fn.fnamemodify(path, ":."),
  })
end

local function scan_recursive_plans(root, items, seen)
  local patterns = {
    "**/.agent/*plan*.json",
    "**/.agent/plans/*plan*.json",
  }

  for _, pattern in ipairs(patterns) do
    for _, path in ipairs(vim.fn.globpath(root, pattern, false, true)) do
      if is_plan_file(path) then
        add_item(items, seen, path)
      end
    end
  end
end

function M.list()
  local items = {}
  local seen = {}

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
          local path = plan_dir .. "/" .. name
          if not seen[path] then
            seen[path] = true
            table.insert(items, { label = name, path = path })
          end
        end
      end
    end
  end

  if #items == 0 then
    scan_recursive_plans(util.root(), items, seen)
  end

  table.sort(items, function(left, right)
    return left.path < right.path
  end)

  return items
end

function M.select(callback)
  local items = M.list()

  if #items == 0 then
    local paths = searched_paths()
    util.notify(
      string.format(
        "No Yuumi plans found in %s or %s (cwd: %s). Use :YuumiLoad /absolute/path/to/plan.json",
        paths[1],
        paths[2],
        util.root()
      ),
      vim.log.levels.WARN
    )
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
