if vim.g.loaded_yuumi == 1 then
  return
end

vim.g.loaded_yuumi = 1

require("yuumi").setup()
