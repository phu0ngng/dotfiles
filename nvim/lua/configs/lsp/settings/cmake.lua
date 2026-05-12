local util = require 'lspconfig.util'

return {
  cmd = { 'cmake-language-server' },
  filetypes = { 'cmake' },
  root_dir = function(fname)
    return util.root_pattern('CMakePresets.json', 'CTestConfig.cmake', 'build', 'cmake')(fname)
      or vim.fs.dirname(vim.fs.find('.git', { path = fname, upward = true })[1])
  end,
  single_file_support = true,
  init_options = {
    buildDirectory = 'build',
  },
}
