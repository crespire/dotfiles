-- Options to set
vim.opt.nu = true
vim.opt.relativenumber = true

vim.g.markdown_recommend_style = 0
vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true

vim.opt.cursorline = true
vim.opt.wrap = true
vim.opt.textwidth = 80

vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.undodir = os.getenv('HOME') .. '/.vim/undodir'
vim.opt.undofile = true

vim.opt.hlsearch = false
vim.opt.incsearch = true

vim.opt.termguicolors = true

vim.opt.scrolloff = 8
vim.opt.splitbelow = true
vim.opt.splitright = true

vim.opt.colorcolumn = '80'

vim.opt.foldmethod = "expr"
vim.foldexpre= "nvim_treesitter#foldexpre()"
