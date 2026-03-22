local status_ok, which_key = pcall(require, "which-key")
if not status_ok then
  return
end

which_key.setup({
  plugins = {
    marks = true,
    registers = true,
    spelling = {
      enabled = true,
      suggestions = 20,
    },
    presets = {
      operators = false,
      motions = true,
      text_objects = true,
      windows = true,
      nav = true,
      z = true,
      g = true,
    },
  },
  icons = {
    breadcrumb = "»",
    separator = "➜",
    group = "+",
  },
  keys = {
    scroll_down = "<c-d>",
    scroll_up = "<c-u>",
  },
  win = {
    border = "rounded",
    padding = { 2, 2 },
    winblend = 0,
  },
  layout = {
    height = { min = 4, max = 25 },
    width = { min = 20, max = 50 },
    spacing = 3,
    align = "left",
  },
  show_help = true,
  triggers = { { "<leader>", mode = { "n", "v" } } },
})

which_key.add({
  -- Top-level
  {
    "<leader>b",
    "<cmd>lua require('telescope.builtin').buffers(require('telescope.themes').get_dropdown{previewer = false})<cr>",
    desc = "Buffers",
  },
  { "<leader>e", "<cmd>NvimTreeToggle<cr>",  desc = "Explorer" },
  { "<leader>w", "<cmd>w!<CR>",              desc = "Save" },
  { "<leader>q", "<cmd>q!<CR>",              desc = "Quit" },
  { "<leader>c", "<cmd>bdelete!<CR>",        desc = "Close Buffer" },
  { "<leader>h", "<cmd>nohlsearch<CR>",      desc = "No Highlight" },
  {
    "<leader>f",
    "<cmd>lua require('telescope.builtin').find_files(require('telescope.themes').get_dropdown{previewer = false})<cr>",
    desc = "Find files",
  },
  { "<leader>F", "<cmd>Telescope live_grep theme=ivy<cr>", desc = "Find Text" },

  -- Lazy
  { "<leader>p",  group = "Lazy" },
  { "<leader>pi", "<cmd>Lazy install<cr>", desc = "Install" },
  { "<leader>ps", "<cmd>Lazy sync<cr>",    desc = "Sync" },
  { "<leader>pS", "<cmd>Lazy<cr>",         desc = "Status" },
  { "<leader>pu", "<cmd>Lazy update<cr>",  desc = "Update" },

  -- Git
  { "<leader>g",  group = "Git" },
  { "<leader>gj", "<cmd>lua require 'gitsigns'.next_hunk()<cr>",          desc = "Next Hunk" },
  { "<leader>gk", "<cmd>lua require 'gitsigns'.prev_hunk()<cr>",          desc = "Prev Hunk" },
  { "<leader>gl", "<cmd>lua require 'gitsigns'.blame_line()<cr>",         desc = "Blame" },
  { "<leader>gp", "<cmd>lua require 'gitsigns'.preview_hunk()<cr>",       desc = "Preview Hunk" },
  { "<leader>gr", "<cmd>lua require 'gitsigns'.reset_hunk()<cr>",         desc = "Reset Hunk" },
  { "<leader>gR", "<cmd>lua require 'gitsigns'.reset_buffer()<cr>",       desc = "Reset Buffer" },
  { "<leader>gs", "<cmd>lua require 'gitsigns'.stage_hunk()<cr>",         desc = "Stage Hunk" },
  { "<leader>gu", "<cmd>lua require 'gitsigns'.undo_stage_hunk()<cr>",    desc = "Undo Stage Hunk" },
  { "<leader>go", "<cmd>Telescope git_status<cr>",                        desc = "Open changed file" },
  { "<leader>gb", "<cmd>Telescope git_branches<cr>",                      desc = "Checkout branch" },
  { "<leader>gc", "<cmd>Telescope git_commits<cr>",                       desc = "Checkout commit" },
  { "<leader>gd", "<cmd>Gitsigns diffthis HEAD<cr>",                      desc = "Diff" },

  -- LSP
  { "<leader>l",  group = "LSP" },
  { "<leader>la", "<cmd>lua vim.lsp.buf.code_action()<cr>",               desc = "Code Action" },
  { "<leader>ld", "<cmd>Telescope diagnostics bufnr=0<cr>",               desc = "Document Diagnostics" },
  { "<leader>lw", "<cmd>Telescope diagnostics<cr>",                       desc = "Workspace Diagnostics" },
  { "<leader>lf", "<cmd>lua vim.lsp.buf.format{async=true}<cr>",          desc = "Format" },
  { "<leader>li", "<cmd>LspInfo<cr>",                                     desc = "Info" },
  { "<leader>lI", "<cmd>Mason<cr>",                                       desc = "Mason" },
  { "<leader>lj", "<cmd>lua vim.diagnostic.goto_next()<CR>",              desc = "Next Diagnostic" },
  { "<leader>lk", "<cmd>lua vim.diagnostic.goto_prev()<cr>",              desc = "Prev Diagnostic" },
  { "<leader>ll", "<cmd>lua vim.lsp.codelens.run()<cr>",                  desc = "CodeLens Action" },
  { "<leader>lq", "<cmd>lua vim.diagnostic.setloclist()<cr>",             desc = "Quickfix" },
  { "<leader>lr", "<cmd>lua vim.lsp.buf.rename()<cr>",                    desc = "Rename" },
  { "<leader>ls", "<cmd>Telescope lsp_document_symbols<cr>",              desc = "Document Symbols" },
  { "<leader>lS", "<cmd>Telescope lsp_dynamic_workspace_symbols<cr>",     desc = "Workspace Symbols" },

  -- Search
  { "<leader>s",  group = "Search" },
  { "<leader>sb", "<cmd>Telescope git_branches<cr>",  desc = "Checkout branch" },
  { "<leader>sc", "<cmd>Telescope colorscheme<cr>",   desc = "Colorscheme" },
  { "<leader>sh", "<cmd>Telescope help_tags<cr>",     desc = "Find Help" },
  { "<leader>sM", "<cmd>Telescope man_pages<cr>",     desc = "Man Pages" },
  { "<leader>sr", "<cmd>Telescope oldfiles<cr>",      desc = "Open Recent File" },
  { "<leader>sR", "<cmd>Telescope registers<cr>",     desc = "Registers" },
  { "<leader>sk", "<cmd>Telescope keymaps<cr>",       desc = "Keymaps" },
  { "<leader>sC", "<cmd>Telescope commands<cr>",      desc = "Commands" },

  -- Minuet AI completion
  { "<leader>m",  group = "Minuet AI" },
  { "<leader>mc", "<cmd>lua MinuetSwitchProvider('claude')<cr>",      desc = "Use Claude (Anthropic)" },
  { "<leader>mo", "<cmd>lua MinuetSwitchProvider('openai')<cr>",      desc = "Use OpenAI / Codex" },
  { "<leader>mq", "<cmd>lua MinuetSwitchProvider('local_qwen')<cr>",  desc = "Use qwen2.5-coder (port 8080)" },
  { "<leader>mg", "<cmd>lua MinuetSwitchProvider('local_glm')<cr>",   desc = "Use CodeGeeX4/GLM (port 8081)" },

  -- Terminal
  { "<leader>t",  group = "Terminal" },
  { "<leader>tf", "<cmd>terminal<cr>",              desc = "Terminal (full)" },
  { "<leader>th", "<cmd>split | terminal<cr>",      desc = "Terminal (horizontal)" },
  { "<leader>tv", "<cmd>vsplit | terminal<cr>",     desc = "Terminal (vertical)" },
})
