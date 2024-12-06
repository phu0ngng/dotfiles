local colorhue = os.getenv("TERMCOLORHUE")
local llt='auto'
if colorhue == "light" then
    vim.o.background='light'
    llt='ayu'
elseif true then
    vim.o.background='dark'
    llt='ayu'
end

local function diff_source()
  local gitsigns = vim.b.gitsigns_status_dict
  if gitsigns then
    return {
      added = gitsigns.added,
      modified = gitsigns.changed,
      removed = gitsigns.removed
    }
  end
end

require'lualine'.setup {
    options = {
    icons_enabled = true,
    theme = llt,
    component_separators = { left = ' ', right = ' '}, --TODO
    section_separators = { left = ' ', right = ' '},
    disabled_filetypes = {
      statusline = {},
      winbar = {},
    },
    ignore_focus = {},
    always_divide_middle = true,
    globalstatus = false,
    refresh = {
      statusline = 1000,
      tabline = 1000,
      winbar = 1000,
    }
  },
  sections = {
    lualine_a = {'mode'},
    lualine_b = {'branch'},
    lualine_c = {{'diff', source = diff_source}, },
    lualine_x = {'filetype', 'filename'},
    lualine_x = {{'filename', path = 1}},
    lualine_y = {'progress','location'},
    lualine_z = {'searchcount'}
  },
  inactive_sections = {
    lualine_a = {},
    lualine_b = {},
    lualine_c = {'filename'},
    lualine_x = {'location'},
    lualine_y = {},
    lualine_z = {}
  },
  tabline = {},
  winbar = {},
  inactive_winbar = {},
  extensions = {}
}
