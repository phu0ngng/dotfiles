local util = require 'lspconfig.util'

return {
  cmd = { 'pylsp' },
  filetypes = { 'python' },
  root_dir = function(fname)
    local root_files = {
      'pyproject.toml',
      'setup.py',
      'setup.cfg',
      'requirements.txt',
      'Pipfile',
    }
    return util.root_pattern(unpack(root_files))(fname)
      or vim.fs.dirname(vim.fs.find('.git', { path = fname, upward = true })[1])
  end,
  single_file_support = true,
  --- pycodestyle and pyflakes are enabled by default, so they need to be disabled
  settings = {
    pylsp = {
      plugins = {
        pycodestyle = {
          enabled = true,
          maxLineLength = 100
        },
        pyflakes = { enabled = false },
        pylint = {
          enabled = true,
          args = {'--max-line-length=100'}
        }
      }
    }
  },
}
