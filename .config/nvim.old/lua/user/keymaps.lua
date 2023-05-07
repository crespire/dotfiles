-- leader to space
vim.keymap.set('', '<Space>', '<Nop>', opts)
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Modes
--   normal_mode = "n",
--   insert_mode = "i",
--   visual_mode = "v",
--   visual_block_mode = "x",
--   term_mode = "t",
--   command_mode = "c",

-- Mormal Mode Rebinds
-- Explorer - should be hijacked by nvim-tree once I get that set up
vim.keymap.set("n", "<leader>e", ":NvimTreeToggle<cr>", { desc = 'Toggle File Explorer' })

-- Resize with arrows
vim.keymap.set('n', '<C-Up>', ':resize +2<cr>')
vim.keymap.set('n', '<C-Down>', ':resize -2<cr>')
vim.keymap.set('n', '<C-Right>', ':vertical resize +2<cr>')
vim.keymap.set('n', '<C-Left>', ':vertical resize -2<cr>')

-- Navigate buffers
vim.keymap.set('n', '<S-l>', ':bnext<cr>')
vim.keymap.set('n', '<S-h>', ':bprevious<cr>')

-- Visual Mode Binds
-- Stay in indent mode
vim.keymap.set('v', '<', '<gv')
vim.keymap.set('v', '>', '>gv')

-- Move line up and down
vim.keymap.set('v', '<A-j>', ":m .+1<cr>==", { noremap = true })
vim.keymap.set('v', '<A-k>', ":m .-2<cr>==", { noremap = true })

-- Move line block up and down
vim.keymap.set('x', '<A-j>', ":m '>+1<cr>gv=gv", { noremap = true })
vim.keymap.set('x', '<A-k>', ":m '<-2<cr>gv=gv", { noremap = true })


-- Toggle Trouble
vim.keymap.set('n', '<leader>xx', ':TroubleToggle<cr>', { desc = 'Toggle Trouble List' })

