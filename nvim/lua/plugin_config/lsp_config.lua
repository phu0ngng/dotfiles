require("mason-lspconfig").setup()

local capabilities = require('cmp_nvim_lsp').default_capabilities(vim.lsp.protocol.make_client_capabilities())

require('lspsaga').setup({
  code_action_icon = "💡",
  symbol_in_winbar = {
    in_custom = false,
    enable = false,
    separator = ' ',
    show_file = true,
    file_formatter = ""
  },
})

vim.keymap.set("n", "gd", "<cmd>Lspsaga lsp_finder<CR>", { silent = true })
vim.keymap.set('n', 'K', '<Cmd>Lspsaga hover_doc<cr>', { silent = true })
vim.keymap.set({"n","v"}, "<leader>ca", "<cmd>Lspsaga code_action<CR>", { silent = true })
vim.keymap.set("n", "<leader>rn", "<cmd>Lspsaga rename<CR>", { silent = true })

require("lspconfig").lua_ls.setup {
  capabilities = capabilities,
  settings = {
    Lua = {
      diagnostics = {
        globals = { "vim" },
      },
      workspace = {
        library = {
          [vim.fn.expand "$VIMRUNTIME/lua"] = true,
          [vim.fn.stdpath "config" .. "/lua"] = true,
        },
      },
    },
  },
  autostart = true
}

require("lspconfig").solargraph.setup {
  capabilities = capabilities,
  autostart = true
}

require("lspconfig").pylsp.setup {
  capabilities = capabilities,
  autostart = true
}

require("lspconfig").texlab.setup{
  capabilities = capabilities,
  autostart = true
}
require("lspconfig").clangd.setup{
  capabilities = capabilities,
  autostart = true
}
require("lspconfig").julials.setup{
  on_new_config = function(new_config, _)
    local julia = vim.fn.expand("~/.julia/environments/nvim-lspconfig/bin/julia")
    if require'lspconfig'.util.path.is_file(julia) then
	  vim.notify("Hello!")
      new_config.cmd[1] = julia
    end
  end,
  capabilities = capabilities,
  autostart = true
}

require'toggle_lsp_diagnostics'.init({ start_on = true })
vim.keymap.set("n", "<Leader>c", "<cmd>ToggleDiag<CR>")
vim.keymap.set("n", "<Leader>cs", "<cmd>LspStart<CR>")  -- Start
vim.keymap.set("n", "<Leader>ch", "<cmd>LspStop<CR>")  -- Halt
vim.keymap.set("n", "<Leader>H", vim.lsp.buf.hover)
vim.keymap.set("n", "<Leader>q", vim.diagnostic.open_float)
