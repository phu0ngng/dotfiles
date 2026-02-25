-- vim.o.termguicolors = true
-- local xornot = os.getenv("NVIMNOXRESOURCE")
-- --if xornot ~= "1" then  -- # ~= not equal
-- --    require('xresources')
-- if true then --TODO
--     local colorhue = os.getenv("TERMCOLORHUE")
--     if colorhue == "light" then
--         vim.o.background='light'
--         vim.cmd [[ colorscheme dayfox ]] --or dawnfox
--     elseif true then
--         vim.o.background='dark'
--         vim.cmd [[ colorscheme nightfox ]] --or nordfox
--     end
-- end
--
vim.o.termguicolors = true

local colorhue = os.getenv("TERMCOLORHUE")
local utc_hour = tonumber(os.date("%H"))
local pst_hour = (utc_hour - 8 ) % 24  -- Convert UTC → PST (handles wraparound)

if colorhue == "light" or (pst_hour >= 6 and pst_hour < 18) then
  vim.o.background = 'light'
  vim.cmd [[colorscheme dayfox]]
else
  vim.o.background = 'dark'
  vim.cmd [[colorscheme nightfox]]
end

