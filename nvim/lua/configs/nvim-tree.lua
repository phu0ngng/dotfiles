require("nvim-tree").setup {
  update_focused_file = {
    enable      = true,
    update_root = true,
  },
  renderer = {
    root_folder_label = ":t",
    icons = {
      web_devicons = {
        file   = { enable = true,  color = true },
        folder = { enable = false, color = true },
      },
      show = {
        file         = true,
        folder       = true,
        folder_arrow = true,
        git          = true,
        modified     = true,
        diagnostics  = true,
        bookmarks    = true,
      },
      -- glyphs intentionally omitted: nvim-tree's built-in defaults
      -- contain the correct Nerd Font bytes for all icons.
    },
  },
  diagnostics = {
    enable       = true,
    show_on_dirs = true,
  },
  view = {
    width         = 30,
    adaptive_size = true,
    side          = "left",
  },
  filters = {
    dotfiles = true,
  },
  sort = {
    sorter = "case_sensitive",
  },
}

vim.keymap.set('n', '<C-n>', ':NvimTreeFindFileToggle<CR>')
