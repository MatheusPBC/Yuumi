local M = {}

local function is_yuumi_buf(buf)
  return vim.bo[buf].filetype == "yuumi"
end

local function is_sidebar_buf(buf)
  return is_yuumi_buf(buf) and vim.api.nvim_buf_get_name(buf):match("Yuumi Plan$") ~= nil
end

function M.close_floats()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local config = vim.api.nvim_win_get_config(win)
    local buf = vim.api.nvim_win_get_buf(win)
    if config.relative ~= "" and is_yuumi_buf(buf) then
      pcall(vim.api.nvim_win_close, win, true)
    end
  end
end

function M.close_sidebars(except_win, except_buf)
  local buffers = {}
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if win ~= except_win then
      local config = vim.api.nvim_win_get_config(win)
      local buf = vim.api.nvim_win_get_buf(win)
      if config.relative == "" and is_sidebar_buf(buf) then
        pcall(vim.api.nvim_win_close, win, true)
        buffers[buf] = true
      end
    end
  end

  for buf in pairs(buffers) do
    if buf ~= except_buf and vim.api.nvim_buf_is_valid(buf) then
      pcall(vim.api.nvim_buf_delete, buf, { force = true })
    end
  end
end

return M
