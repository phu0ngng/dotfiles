local null_ls_status_ok, null_ls = pcall(require, "null-ls")
if not null_ls_status_ok then
	return
end

-- https://github.com/jose-elias-alvarez/null-ls.nvim/tree/main/lua/null-ls/builtins/formatting
--[[ local formatting = null_ls.builtins.formatting ]]
-- https://github.com/jose-elias-alvarez/null-ls.nvim/tree/main/lua/null-ls/builtins/diagnostics
local diagnostics = null_ls.builtins.diagnostics


null_ls.setup({
	debug = false,
	sources = {
		--[[ formatting.prettier.with({args = { "--no-semi", "--single-quote", "--jsx-single-quote" } }), ]]
		--[[ formatting.black.with({ args = { "--fast" } }), ]]
		--[[ formatting.stylua, ]]
    diagnostics.pylint,
    diagnostics.cpplint.with({args = { "—filter", "-legal/copyright", "--linelength=120" } }),
    --[[ diagnostics.flake8, ]]
	},
})
