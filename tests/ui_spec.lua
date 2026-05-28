local minit = require("tests.minit")
local ui = require("yuumi.ui")

local function close_floating_windows()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_config(win).relative ~= "" then
      vim.api.nvim_win_close(win, true)
    end
  end
end

minit.test("toggles a float with the same title", function()
  close_floating_windows()

  local win = ui.float({ "first" }, { title = "Yuumi Check" })
  minit.truthy(vim.api.nvim_win_is_valid(win))

  local toggled = ui.float({ "second" }, { title = "Yuumi Check" })
  minit.eq(nil, toggled)
  minit.eq(false, vim.api.nvim_win_is_valid(win))

  close_floating_windows()
end)
