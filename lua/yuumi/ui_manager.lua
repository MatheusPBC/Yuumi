local M = {}

function M.refresh()
  local ok, sidebar = pcall(require, "yuumi.sidebar")
  if ok and sidebar.is_open() then
    sidebar.refresh()
  end
end

return M
