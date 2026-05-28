local M = {}

M.defaults = {
  plan_path = ".agent/current-plan.json",
  state_path = ".agent/yuumi-state.json",
  highlight_group = "YuumiAnchor",
  virtual_text_prefix = "yuumi: ",
  show_virtual_lines = true,
  open_files_on_load = true,
  inline_debounce_ms = 80,
  accept_keymap = "<M-y>",
  gpt_command = nil,
}

M.options = vim.deepcopy(M.defaults)

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})
end

return M
