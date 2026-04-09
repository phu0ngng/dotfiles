local M = {}

local status_cmp_ok, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
if not status_cmp_ok then
	return
end

M.capabilities = vim.lsp.protocol.make_client_capabilities()
M.capabilities.textDocument.completion.completionItem.snippetSupport = true
M.capabilities = cmp_nvim_lsp.default_capabilities(M.capabilities)

M.setup = function()
	vim.diagnostic.config({
		virtual_text = false,
		signs = {
			text = {
				[vim.diagnostic.severity.ERROR] = "E",
				[vim.diagnostic.severity.WARN]  = "W",
				[vim.diagnostic.severity.HINT]  = "H",
				[vim.diagnostic.severity.INFO]  = "I",
			},
		},
		update_in_insert = true,
		underline = true,
		severity_sort = true,
		float = {
			focusable = true,
			style = "minimal",
			border = "rounded",
			source = true,
			header = "",
			prefix = "",
		},
	})

	vim.lsp.handlers["textDocument/hover"] = function(err, result, ctx, config)
		config = vim.tbl_extend("force", config or {}, { border = "rounded" })
		vim.lsp.handlers.hover(err, result, ctx, config)
	end

	vim.lsp.handlers["textDocument/signatureHelp"] = function(err, result, ctx, config)
		config = vim.tbl_extend("force", config or {}, { border = "rounded" })
		vim.lsp.handlers.signature_help(err, result, ctx, config)
	end
end

local function lsp_keymaps(bufnr)
	local opts = { noremap = true, silent = true, buffer = bufnr }
	vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)
	vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
	vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
	vim.keymap.set("n", "gI", vim.lsp.buf.implementation, opts)
	vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
	vim.keymap.set("n", "gl", vim.diagnostic.open_float, opts)
	vim.keymap.set("n", "<leader>lf", function() vim.lsp.buf.format({ async = true }) end, opts)
	vim.keymap.set("n", "<leader>li", "<cmd>LspInfo<cr>", opts)
	vim.keymap.set("n", "<leader>lI", "<cmd>Mason<cr>", opts)
	vim.keymap.set("n", "<leader>la", vim.lsp.buf.code_action, opts)
	vim.keymap.set("n", "<leader>lj", vim.diagnostic.goto_next, opts)
	vim.keymap.set("n", "<leader>lk", vim.diagnostic.goto_prev, opts)
	vim.keymap.set("n", "<leader>lr", vim.lsp.buf.rename, opts)
	vim.keymap.set("n", "<leader>ls", vim.lsp.buf.signature_help, opts)
	vim.keymap.set("n", "<leader>lq", vim.diagnostic.setloclist, opts)
end

M.on_attach = function(client, bufnr)
	if client.name == "tsserver" then
		client.server_capabilities.documentFormattingProvider = false
	end

	if client.name == "lua_ls" then
		client.server_capabilities.documentFormattingProvider = false
	end

	lsp_keymaps(bufnr)

	-- Signature hints while typing
	local sig_ok, lsp_signature = pcall(require, "lsp_signature")
	if sig_ok then
		lsp_signature.on_attach({
			bind = true,
			hint_enable = false,
			floating_window = true,
			handler_opts = { border = "rounded" },
			toggle_key = "<C-k>",
		}, bufnr)
	end

	local status_ok, illuminate = pcall(require, "illuminate")
	if not status_ok then
		return
	end
	illuminate.on_attach(client)
end

M.setup()  -- initialise diagnostics & LSP handlers

return M
