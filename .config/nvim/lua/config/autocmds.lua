-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

-- Open all folds on Buffer Load
vim.api.nvim_create_autocmd({ "BufRead", "BufWinEnter", "BufReadPost", "FileReadPost" }, { command = "normal zR" })

-- Show vertical rule at 72 chars in commit messages
vim.api.nvim_create_autocmd("FileType", {
  pattern = "gitcommit",
  callback = function()
    vim.opt_local.colorcolumn = "72"
  end,
})
