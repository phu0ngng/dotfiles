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

-- Navigate vim panes better
vim.keymap.set('n', '<c-k>', ':wincmd k<CR>')
vim.keymap.set('n', '<c-j>', ':wincmd j<CR>')
vim.keymap.set('n', '<c-h>', ':wincmd h<CR>')
vim.keymap.set('n', '<c-l>', ':wincmd l<CR>')

vim.keymap.set('n', '<leader>r', ':set rnu!<CR>')
vim.keymap.set('n', '<leader>h', ':nohlsearch<CR>')
vim.keymap.set('n', '<leader>n', ':set nu!<CR>:exe "set signcolumn=" .. (&signcolumn == "yes" ? "no" : "yes")<CR>')
vim.keymap.set('n', '<F9>', ':let _s=@/<Bar>:%s/\\s\\+$//e<Bar>:let @/=_s<Bar>:nohl<CR>', {silent=true})

-- delete text without changing the internal registers
vim.keymap.set({'n', 'x'}, 'x', '"_x')
