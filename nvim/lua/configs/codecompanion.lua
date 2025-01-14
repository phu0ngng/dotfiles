local status_ok, companion = pcall(require, "codecompanion")
if not status_ok then
  return
end

companion.setup({
  adapters = {
    ollama = function()
      return require("codecompanion.adapters").extend("ollama", {
        name = "ollama",
        model = "llama3.3", -- or any other model you prefer
      })
    end,
  },
  strategies = {
    chat = { adapter = "ollama" },
    inline = { adapter = "ollama" },
    agent = { adapter = "ollama" },
  },
})

