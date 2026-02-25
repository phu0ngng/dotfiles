-- Setup nvim-cmp.
local status_ok, npairs = pcall(require, "nvim-autopairs")
if not status_ok then
  return
end

npairs.setup {
  check_ts = true,
  ts_config = {
    lua = { "string", "source" },
    javascript = { "string", "template_string" },
    java = false,
  },
  disable_filetype = { "TelescopePrompt", "spectre_panel" },
  fast_wrap = {
    map = "<M-e>",
    chars = { "{", "[", "(", '"', "'" },
    pattern = string.gsub([[ [%'%"%)%>%]%)%}%,] ]], "%s+", ""),
    offset = 0, -- Offset from pattern match
    end_key = "$",
    keys = "qwertyuiopzxcvbnmasdfghjkl",
    check_comma = true,
    highlight = "PmenuSel",
    highlight_grey = "LineNr",
  },
}

-- Defer cmp integration until VimEnter so cmp is guaranteed to be fully loaded
vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = function()
    local cmp_ok, cmp = pcall(require, "cmp")
    if not cmp_ok then return end
    local pairs_ok, cmp_autopairs = pcall(require, "nvim-autopairs.completion.cmp")
    if not pairs_ok then return end
    cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done())
  end,
})
