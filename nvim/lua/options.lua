-- Ensure UTF-8 locale so Nerd Font icons render correctly.
-- Some servers default to POSIX/C locale which is ASCII-only.
if not os.getenv("LANG") or os.getenv("LANG") == "" or os.getenv("LANG") == "POSIX" or os.getenv("LANG") == "C" then
  vim.env.LANG = "en_US.UTF-8"
end

vim.g.mapleader = ','
vim.g.maplocalleader = ','

-- Suppress tbl_islist deprecation for plugins not yet updated for nvim 0.11
-- vim.islist is the new name (0.10+); vim.tbl_isarray is an intermediate alias
local _islist = vim.islist or vim.tbl_isarray
if _islist then
  vim.tbl_islist = _islist
end

--[[ vim.o.netrw_silent=1 ]]
vim.o.cmdheight=0

vim.opt.backspace = '2'
vim.opt.showcmd = true
vim.opt.laststatus = 2
vim.opt.autowrite = true
vim.opt.cursorline = true
vim.opt.autoread = true

-- use spaces for tabs and whatnot
vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.shiftwidth = 2
vim.opt.shiftround = true
vim.opt.expandtab = true
vim.opt.smartindent = true
--vim.opt.wrap = false

vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.undodir = os.getenv("HOME") .. "/.vim/undodir"
vim.opt.undofile = true

--Line numbers
vim.wo.number = true
vim.g.netrw_browse_split = 0
vim.g.netrw_banner = 1
vim.g.netrw_winsize = 25

vim.opt.hlsearch = false
vim.opt.incsearch = true

--vim.opt.termguicolors = true

vim.opt.scrolloff = 8
vim.opt.signcolumn = "yes"
vim.opt.isfname:append("@-@")

vim.opt.updatetime = 50
vim.loader.enable() -- built-in bytecode cache (replaces impatient.nvim)

vim.opt.textwidth = 100
vim.opt.hlsearch = true
vim.api.nvim_create_autocmd("BufEnter", { pattern = "*.inc,*.hpp,*.cu, *.h", command = [[setlocal filetype=cpp]] })

-- Delete trailing spaces before saving
vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = "*",
  command = [[%s/\s\+$//e]]
})

-- Use whichever python3 is on PATH; avoids hardcoding a machine-specific path
vim.g.python3_host_prog = vim.fn.exepath("python3")
vim.env.PATH = vim.env.PATH .. ':' .. vim.env.HOME .. '/.local/bin'
