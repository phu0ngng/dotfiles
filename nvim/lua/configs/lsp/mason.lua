
local servers = {
  "lua_ls",
  "clangd",
  "pylsp",
}

local settings = {
	ui = {
		border = "none",
		icons = {
			package_installed = "◍",
			package_pending = "◍",
			package_uninstalled = "◍",
		},
	},
	log_level = vim.log.levels.INFO,
	max_concurrent_installers = 4,
}

require("mason").setup(settings)
require("mason-lspconfig").setup({
	ensure_installed = servers,
	automatic_installation = false,
	handlers = {
		function(server_name)
			local opts = {
				on_attach = require("configs.lsp.handlers").on_attach,
				capabilities = require("configs.lsp.handlers").capabilities,
			}
			local require_ok, conf_opts = pcall(require, "configs.lsp.settings." .. server_name)
			if require_ok then
				opts = vim.tbl_deep_extend("force", conf_opts, opts)
			end
			vim.lsp.config(server_name, opts)
			vim.lsp.enable(server_name)
		end,
	},
})
