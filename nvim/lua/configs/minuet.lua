local status_ok, minuet = pcall(require, "minuet")
if not status_ok then
  return
end

-- Switch provider at runtime via keymaps (see whichkey.lua, <leader>m*)
--   "claude"    → Anthropic API          ($ANTHROPIC_API_KEY)
--   "openai"    → OpenAI / Codex         ($OPENAI_API_KEY)
--   "local_qwen"→ llama.cpp + qwen2.5-coder  (localhost:8080)
--   "local_glm" → llama.cpp + CodeGeeX4/GLM  (localhost:8081)
--
-- Local model server examples:
--   llama-server -m qwen2.5-coder-3b-instruct-q4_k_m.gguf --port 8080 -ngl 99
--   llama-server -m codegeex4-all-9b-Q4_K_M.gguf          --port 8081 -ngl 99

-- Endpoints for each local model
local local_endpoints = {
  local_qwen = "http://localhost:8080/v1/completions",
  local_glm  = "http://localhost:8081/v1/completions",
}

local config = {
  provider      = "openai_fim_compatible",  -- local llama.cpp; switch with ,mc/,mo when API keys are ready
  n_completions = 1,
  context_window = 16000,

  -- Ghost text shown while typing
  virtualtext = {
    auto_trigger_ft = { "c", "cpp", "lua", "python" },
    keymap = {
      accept         = "<A-a>",
      accept_line    = "<A-o>",
      accept_n_lines = "<A-n>",
      prev           = "<A-[>",
      next           = "<A-]>",
      dismiss        = "<A-d>",
    },
  },

  provider_options = {

    -- ── Claude (Anthropic) ─────────────────────────────────────────────
    claude = {
      api_key    = "ANTHROPIC_API_KEY",  -- reads $ANTHROPIC_API_KEY
      model      = "claude-haiku-4-5",
      max_tokens = 512,
      stream     = true,
    },

    -- ── OpenAI / Codex ─────────────────────────────────────────────────
    openai = {
      api_key    = "OPENAI_API_KEY",     -- reads $OPENAI_API_KEY
      model      = "gpt-4.1-mini",
      max_tokens = 512,
      stream     = true,
    },

    -- ── llama.cpp local (endpoint swapped by MinuetSwitchProvider) ─────
    openai_fim_compatible = {
      api_key   = "TERM",
      name      = "llama.cpp",
      end_point = local_endpoints.local_qwen, -- default local model
      model     = "auto",  -- llama.cpp ignores this; model set at server start
      optional  = {
        max_tokens = 256,
        top_p      = 0.9,
      },
    },
  },
}

minuet.setup(config)

-- Runtime provider/endpoint switcher (called from whichkey keymaps)
local provider_labels = {
  claude     = "Claude (Anthropic)",
  openai     = "OpenAI / Codex",
  local_qwen = "llama.cpp · qwen2.5-coder (port 8080)",
  local_glm  = "llama.cpp · CodeGeeX4/GLM  (port 8081)",
}

function MinuetSwitchProvider(name)
  if name == "local_qwen" or name == "local_glm" then
    -- Both map to openai_fim_compatible; just swap the endpoint
    config.provider = "openai_fim_compatible"
    config.provider_options.openai_fim_compatible.end_point = local_endpoints[name]
  else
    config.provider = name
  end
  minuet.setup(config)
  vim.notify("Minuet → " .. (provider_labels[name] or name), vim.log.levels.INFO)
end
