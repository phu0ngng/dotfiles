-- Setup minuet-ai.
local status_ok, minuet = pcall(require, "minuet")
if not status_ok then
  return
end

minuet.setup {
  lsp = {
    enabled_ft = { 'toml', 'lua', 'cpp' },
    -- Enables automatic completion triggering using `vim.lsp.completion.enable`
    enabled_auto_trigger_ft = { 'cpp', 'lua' },
  },
  virtualtext = {
    auto_trigger_ft = {},
    keymap = {
      -- accept whole completion
      accept = '<A-a>',
      -- accept one line
      accept_line = '<A-o>',
      -- accept n lines (prompts for number)
      accept_n_lines = '<A-n>',
      -- Cycle to previous completion item, or manually invoke completion
      prev = '<A-[>',
      -- Cycle to next completion item, or manually invoke completion
      next = '<A-]>',
      dismiss = '<A-d>',
    },
  },
  provider = 'openai_fim_compatible',
  n_completions = 1,
  provider_options = {
    openai_fim_compatible = {
      api_key = 'TERM', -- Just use TERM; no real API key needed for Ollama local
      name = 'Ollama',
      end_point = 'http://localhost:11434/v1/completions', -- Ollama default endpoint
      model = 'qwen2.5-coder:3b',
      optional = {
        max_tokens = 256,
        top_p = 0.9,
      },
    },
  },
}
