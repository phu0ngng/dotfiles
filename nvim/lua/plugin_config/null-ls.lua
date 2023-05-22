local null_ls = require("null-ls")

null_ls.setup({
    sources = {
        null_ls.builtins.formatting.stylua,
        -- sh
        null_ls.builtins.diagnostics.shellcheck,
        -- C++
--        null_ls.builtins.diagnostics.clang_check,
--        null_ls.builtins.diagnostics.cppcheck,
        null_ls.builtins.diagnostics.cpplint,
        null_ls.builtins.formatting.clang_format,
        -- Make
        null_ls.builtins.diagnostics.checkmake,
        -- Tex
        null_ls.builtins.diagnostics.chktex,
        -- Spelling
        null_ls.builtins.completion.spell,
        -- Python
--        null_ls.builtins.diagnostics.flake8,
        null_ls.builtins.diagnostics.pylint,
--        null_ls.builtins.formatting.autopep8,
        null_ls.builtins.formatting.black,
    },
})

local notify = vim.notify
vim.notify = function(msg, ...)
    if msg:match("warning: multiple different client offset_encodings") then
        return
    end

    notify(msg, ...)
end
