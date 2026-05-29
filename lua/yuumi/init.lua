local commands = require("yuumi.commands")
local board = require("yuumi.board")
local config = require("yuumi.config")
local inline = require("yuumi.inline")
local marks = require("yuumi.marks")

local M = {}

function M.setup(opts)
  config.setup(opts)
  marks.setup_highlights()
  commands.create()

  vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost" }, {
    group = vim.api.nvim_create_augroup("YuumiMarks", { clear = true }),
    callback = function(event)
      marks.render_buffer(event.buf)
      board.refresh()
    end,
  })

  vim.api.nvim_create_autocmd({ "CursorMovedI", "TextChangedI" }, {
    group = vim.api.nvim_create_augroup("YuumiInline", { clear = true }),
    callback = function()
      inline.refresh()
    end,
  })

  if config.options.accept_keymap then
    vim.keymap.set("i", config.options.accept_keymap, function()
      return inline.accept()
    end, { expr = true, desc = "Accept Yuumi inline suggestion" })
  end
end

return M
