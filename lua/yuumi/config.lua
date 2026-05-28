local M = {}

M.defaults = {
  plan_path = ".agent/current-plan.json",
  state_path = ".agent/yuumi-state.json",
  highlight_group = "YuumiAnchor",
  virtual_text_prefix = "yuumi: ",
  inline_debounce_ms = 80,
  accept_keymap = "<M-y>",
}

M.options = vim.deepcopy(M.defaults)

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})
end

return M
