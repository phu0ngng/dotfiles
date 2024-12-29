vim.o.termguicolors = true
local xornot = os.getenv("NVIMNOXRESOURCE")
--if xornot ~= "1" then  -- # ~= not equal
--    require('xresources')
if true then --TODO
    local colorhue = os.getenv("TERMCOLORHUE")
    if colorhue == "light" then
        vim.o.background='light'
        vim.cmd [[ colorscheme dayfox ]] --or dawnfox
    elseif true then
        vim.o.background='dark'
        vim.cmd [[ colorscheme nightfox ]] --or nordfox
    end
end
