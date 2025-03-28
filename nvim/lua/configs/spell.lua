vim.g.grammarous_jar_url = 'https://www.languagetool.org/download/LanguageTool-5.9.zip'
vim.keymap.set('n', '<leader>se', function()
  vim.opt.spell=true
  vim.opt.spelllang="en_us"
  print("Set spell check to English.")
  vim.api.nvim_command('GrammarousCheck --lang="en_us"')
end, {desc = 'Set spelling to English'})

vim.keymap.set('n', '<leader>sg', function()
  vim.opt.spell=true
  vim.opt.spelllang="de_de"
  print("Set spell check to German.")
  vim.api.nvim_command('GrammarousCheck --lang="de_de"')
end, {desc = 'Set spelling to German'})

vim.keymap.set('n', '<leader>so', function()
 vim.opt.spell=false
  print("Turned spell check off.")
  vim.api.nvim_command('GrammarousReset')
end, {desc = 'Turn spellcheck off'})
