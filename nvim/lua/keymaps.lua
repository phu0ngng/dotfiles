-- Syntax: vim.keymap.set({mode}, {lhs}, {rhs}, {opts})
-- Where mode is
--- n: Normal mode.
--- i: Insert mode.
--- x: Visual mode.
--- s: Selection mode.
--- v: Visual + Selection.
--- t: Terminal mode.
--- o: Operator-pending.
--- '': Yes, an empty string. Is the equivalent of n + v + o.

-- Leader key:
vim.g.mapleader = ','
vim.g.maplocalleader = ','

-- Navigate vim panes better
vim.keymap.set('n', '<leader>r', ':set rnu!<CR>')
vim.keymap.set('n', '<leader>h', ':nohlsearch<CR>')
vim.keymap.set('n', '<leader>n', ':set nu!<CR>:exe "set signcolumn=" .. (&signcolumn == "yes" ? "no" : "yes")<CR>')
vim.keymap.set('n', '<F9>', ':let _s=@/<Bar>:%s/\\s\\+$//e<Bar>:let @/=_s<Bar>:nohl<CR>', {silent=true})

-- delete text without changing the internal registers
vim.keymap.set({'n', 'x'}, 'x', '"_x')

-- Navigate buffers
vim.keymap.set('n', '<S-l>', ':bnext<CR>')
vim.keymap.set('n', '<S-h>', ':bprevious<CR>')
