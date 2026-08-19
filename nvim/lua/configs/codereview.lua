vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = function()
    require("codereview").setup({
      default_base = "main",
      default_context_lines = 10,
      review_dir = ".review",
      gitignore = true,
    })
  end,
})
