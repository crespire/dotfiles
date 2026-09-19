-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

-- Open all folds on buffer load. `normal!` is required: plain `normal` applies
-- buffer-local mappings, and Neo-tree binds `z` to close_all_nodes, which raises
-- while the tree window is still mounting.
vim.api.nvim_create_autocmd({ "BufWinEnter", "BufReadPost", "FileReadPost" }, {
  callback = function(event)
    if vim.bo[event.buf].buftype ~= "" then
      return
    end
    vim.cmd("normal! zR")
  end,
})

-- Show vertical rule at 72 chars in commit messages
vim.api.nvim_create_autocmd("FileType", {
  pattern = "gitcommit",
  callback = function()
    vim.opt_local.colorcolumn = "72"
  end,
})
