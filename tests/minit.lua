local M = {}

local tests = {}

function M.test(name, fn)
  table.insert(tests, { name = name, fn = fn })
end

function M.eq(expected, actual)
  if vim.deep_equal(expected, actual) then
    return
  end

  error(string.format("expected %s, got %s", vim.inspect(expected), vim.inspect(actual)), 2)
end

function M.truthy(value)
  if value then
    return
  end

  error("expected truthy value", 2)
end

function M.run()
  local failed = 0

  for _, case in ipairs(tests) do
    local ok, err = pcall(case.fn)

    if ok then
      print("ok - " .. case.name)
    else
      failed = failed + 1
      print("not ok - " .. case.name)
      print(err)
    end
  end

  if failed > 0 then
    error(string.format("%d test(s) failed", failed))
  end
end

return M
