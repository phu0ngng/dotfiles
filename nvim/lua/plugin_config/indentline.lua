local status_ok, ibl = pcall(require, "ibl")
if not status_ok then
	return
end

local status_ok_2, icons = pcall(require, "plugin_config.icons")
if not status_ok_2 then
	return
end

vim.g.ibl_buftype_exclude = { "terminal", "nofile" }
vim.g.ibl_filetype_exclude = {
	"help",
	"startify",
	"dashboard",
	"packer",
	"neogitstatus",
	"NvimTree",
	"Trouble",
  "text",
}
vim.g.ibl_char = icons.ui.LineMiddle
vim.g.ibl_context_char = icons.ui.LineMiddle
vim.g.ibl_show_trailing_blankline_indent = false
vim.g.ibl_show_first_indent_level = true
vim.g.ibl_use_treesitter = true
vim.g.ibl_show_current_context = true

ibl.setup({
	-- show_end_of_line = true,
	-- space_char_blankline = " ",
	-- show_current_context_start = true,
})

vim.keymap.set('n', '<C-l>', ':IBLToggle<Enter>')
