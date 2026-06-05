local cleanup = require("yuumi.ui_cleanup")
local minit = require("tests.minit")

local function reset_windows()
  cleanup.close_floats()
  cleanup.close_sidebars()
  vim.cmd("only!")
  vim.cmd("enew!")
end

minit.test("ui cleanup closes Yuumi floating windows", function()
  reset_windows()

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].filetype = "yuumi"
  local win = vim.api.nvim_open_win(buf, false, {
    relative = "editor",
    row = 1,
    col = 1,
    width = 20,
    height = 4,
  })

  minit.truthy(vim.api.nvim_win_is_valid(win))

  cleanup.close_floats()

  minit.eq(false, vim.api.nvim_win_is_valid(win))
  reset_windows()
end)

minit.test("ui cleanup closes Yuumi Plan sidebar splits", function()
  reset_windows()

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].filetype = "yuumi"
  vim.api.nvim_buf_set_name(buf, "Yuumi Plan")
  vim.cmd("botright vertical new")
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, buf)

  minit.truthy(vim.api.nvim_win_is_valid(win))

  cleanup.close_sidebars()

  minit.eq(false, vim.api.nvim_win_is_valid(win))
  minit.eq(false, vim.api.nvim_buf_is_valid(buf))
  reset_windows()
end)
