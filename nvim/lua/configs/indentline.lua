local status_ok, ibl = pcall(require, "ibl")
if not status_ok then
	return
end

ibl.setup({
	indent = { char = "│" },
	scope = { enabled = true },
	exclude = {
		filetypes = {
			"help",
			"startify",
			"dashboard",
			"packer",
			"neogitstatus",
			"NvimTree",
			"Trouble",
			"text",
		},
		buftypes = { "terminal", "nofile" },
	},
})

vim.keymap.set('n', '<C-i>', ':IBLToggle<Enter>')
