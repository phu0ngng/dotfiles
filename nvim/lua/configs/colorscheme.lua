vim.o.termguicolors = true

-- Returns the current hour (0-23) in Pacific Time (PST/PDT, America/Los_Angeles).
-- Uses the system `date` command with TZ override so it works correctly regardless
-- of what timezone the host machine is configured with.
-- Falls back to a pure-Lua UTC-8 calculation if the system call fails.
local function get_pacific_hour()
  local ok, handle = pcall(io.popen, "TZ='America/Los_Angeles' date +'%H' 2>/dev/null")
  if ok and handle then
    local result = handle:read("*l")
    handle:close()
    local hour = tonumber(result)
    if hour then return hour end
  end
  -- Fallback: UTC - 8 (standard PST, ignores DST)
  local utc = os.date("!*t")
  return (utc.hour - 8) % 24
end

-- TERMCOLORHUE env var overrides auto-detection ("light" or "dark").
-- If unset, pick theme based on Pacific Time: 07:00–19:00 → light, otherwise → dark.
local colorhue = os.getenv("TERMCOLORHUE")
if not colorhue then
  local hour = get_pacific_hour()
  colorhue = (hour >= 7 and hour < 19) and "light" or "dark"
end

if colorhue == "light" then
  vim.o.background = "light"
  vim.cmd [[ colorscheme dayfox ]]  -- alternatives: dawnfox
else
  vim.o.background = "dark"
  vim.cmd [[ colorscheme nightfox ]] -- alternatives: nordfox
end
