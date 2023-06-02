local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

local plugins = {
  ---
  -- List of plugins
  --- Colorthemes
  {'folke/tokyonight.nvim'},
  {'EdenEast/nightfox.nvim'},
  --- Color changes based on background
  {'lnhrnndz/xresources-nvim'},
  {'nvim-tree/nvim-web-devicons'}, -- For icons
  --- Plugin Manager in separated config files
  {'wbthomason/packer.nvim'},
  --- Tmux navigator
  { 'christoomey/vim-tmux-navigator',  name = 'tmux-navigator'},
  --- Lualine (bottom bar)
  { 'nvim-lualine/lualine.nvim', dependencies = {'nvim-tree/nvim-web-devicons'}},
  --- Highlighting
  {'nvim-treesitter/nvim-treesitter', run = ":TSUpdate"},
  --- File explorer
  {'nvim-tree/nvim-tree.lua'},
  --- Save undo as a tree
  {'mbbill/undotree'},
  --- Git signs / decorations
  {'lewis6991/gitsigns.nvim'},
  --- Search for whatever codesnip online in a separated window
  {'RishabhRD/nvim-cheat.sh', name = 'cheat', dependencies = {'RishabhRD/popfix'}},

  --- Autocompletion with cmp
  {'hrsh7th/nvim-cmp'}, -- The completion plugin
  {'hrsh7th/cmp-buffer'}, -- buffer completions
  {'hrsh7th/cmp-path'}, -- path completions
  {'hrsh7th/cmp-cmdline'}, -- cmdline completions
  {'saadparwaiz1/cmp_luasnip'}, -- snippet completions

  --snippets
  {'L3MON4D3/LuaSnip'}, --snippet engine
  {'rafamadriz/friendly-snippets'}, -- a bunch of snippets to use

  -- Autopairs
  {'windwp/nvim-autopairs'}, --Autopairs, integrates with both cmp and treesitter

  -- Easy comments
  {'numToStr/Comment.nvim'},
  {'JoosepAlviste/nvim-ts-context-commentstring'},

  --- Language server configuration
  {'neovim/nvim-lspconfig'},
  {'williamboman/mason.nvim'},
  {'williamboman/mason-lspconfig.nvim'},
  {'nvim-lua/plenary.nvim'},
  {'jose-elias-alvarez/null-ls.nvim'},

  -- Telescope
  {'nvim-telescope/telescope.nvim', tag = '0.1.0', dependencies = {'nvim-lua/plenary.nvim'}},
  {'nvim-lua/popup.nvim'}, --Popup API 
  {'nvim-telescope/telescope-media-files.nvim'},

  -- Indentline
  {'lukas-reineke/indent-blankline.nvim'},

  --- Grammarly 
  {'rhysd/vim-grammarous',lazy=false, name='grammarous'},
  --- Open files at your last edit position
  {'farmergreg/vim-lastplace'},

  -- Auto folds TODO
}

local opts = {}

require("lazy").setup(plugins, opts)
