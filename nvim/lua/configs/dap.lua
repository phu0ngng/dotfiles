local dap =require"dap"
local dapui = require"dapui"

local virtual_env = os.getenv("VIRTUAL_ENV")
local python_bin
if virtual_env then
    python_bin = virtual_env .. "/bin/python"
else
    python_bin = "python" -- adjust this to your system's python path if needed
end
require("dap-python").setup(python_bin)
dapui.setup()
dap.configurations.lua = {
  {
    type = 'nlua',
    request = 'attach',
    name = "Attach to running Neovim instance",
  },
  {
    type = 'python',
    request = 'attach',
    name = "Attach to running pdb session file",
  },
}
dap.adapters.nlua = function(callback, config)
  callback({ type = 'server', host = config.host or "127.0.0.1", port = config.port or 8086 })
end

dap.configurations.c = {
  {
    name = "Launch",
    type = "gdb",
    request = "launch",
    program = function()
      return vim.fn.input('Path to executable: ', vim.fn.getcwd() .. '/', 'file')
    end,
    cwd = "${workspaceFolder}",
    stopAtBeginningOfMainSubprogram = false,
  },
}

dap.configurations.cpp = {
  {
    name = 'Launch',
    type = 'lldb',
    request = 'launch',
    program = function()
      return vim.fn.input('Path to executable: ', vim.fn.getcwd() .. '/', 'file')
    end,
    cwd = '${workspaceFolder}',
    stopOnEntry = false,
    args = {},
    runInTerminal = false,
  },
}

dap.adapters.python = {
  type = "executable",
  command = "python", -- use "which python" command and provide the python path
  args = {
    "-m",
    "debugpy.adapter",
  },
}

dap.inputs = {
          {
              id= "myPrompt",
              type= "pickString",
              description= "Program to run: ",
              default= "foobar"
          }
}

local function select_file()
  -- Run `select_file` within a coroutine to allow async file input
  return coroutine.create(function()
    local result = nil
    vim.ui.input({ prompt = "Enter file path: " }, function(input)
      result = input
      coroutine.resume(coroutine.running(), input)  -- Resume coroutine with user input
    end)
    coroutine.yield()  -- Yield to wait for `vim.ui.input` to complete
    return result  -- This will be returned as the selected file path
  end)
end


dap.configurations.python = {
  {
    type = "python",
    request = "launch",
    name = "Launch Current file",
    program = "${file}", -- This configuration will launch the current file if used.
    console= "integratedTerminal",

  },
  {
    type = "python",
    request = "launch",
    name = "Launch OTHER file",
    program = function()
      local co = select_file()  -- Create coroutine for `select_file`
      coroutine.resume(co)      -- Start coroutine
      local _, path = coroutine.resume(co)  -- Resume to get the selected path
      return path
    end,
    console= "integratedTerminal"
  },
  {
    name= "Pytest: Current File",
    type= "python",
    request= "launch",
    module= "pytest",
    args= {
      "${file}",
      "-sv",
      "--log-cli-level=INFO",
      "--log-file=tc_medusa.log"
    },
    console= "integratedTerminal",
  },
  {
    name= "Profile python: Current File",
    type= "python",
    request= "launch",
    module= "cProfile",
    args= {
      "-o",
      "/tmp/profile.dat",
      "${file}"
    },
    console= "integratedTerminal",
  },
}

dap.adapters.gdb = {
  type = "executable",
  command = "gdb",
  args = { "-i", "dap" }
}

dap.adapters.lldb = {
  type = 'executable',
  command = '/sbin/lldb-vscode', -- adjust as needed, must be absolute path
  name = 'lldb'
}

dap.listeners.before.attach.dapui_config = function()
  dapui.open()
end
dap.listeners.before.launch.dapui_config = function()
  dapui.open()
end
dap.listeners.before.event_terminated.dapui_config = function()
  dapui.close()
end
dap.listeners.before.event_exited.dapui_config = function()
  dapui.close()
end

vim.api.nvim_create_autocmd("FileType", {
    pattern = "dap-float",
    callback = function()
        vim.api.nvim_buf_set_keymap(0, "n", "q", "<cmd>close!<CR>", { noremap = true, silent = true })
        vim.api.nvim_buf_set_keymap(0, "n", "<Esc>", "<cmd>close!<CR>", { noremap = true, silent = true })
    end
})

-- Colors
vim.api.nvim_set_hl(0, 'DapBreakpoint', { ctermbg = 0, fg = '#993939', bg = '#31353f' })
vim.api.nvim_set_hl(0, 'DapLogPoint', { ctermbg = 0, fg = '#61afef', bg = '#31353f' })
vim.api.nvim_set_hl(0, 'DapStopped', { ctermbg = 0, fg = '#98c379', bg = '#31353f' })

vim.fn.sign_define('DapBreakpoint', { text='', texthl='DapBreakpoint', linehl='DapBreakpoint', numhl='DapBreakpoint' })
vim.fn.sign_define('DapBreakpointCondition', { text='ﳁ', texthl='DapBreakpoint', linehl='DapBreakpoint', numhl='DapBreakpoint' })
vim.fn.sign_define('DapBreakpointRejected', { text='', texthl='DapBreakpoint', linehl='DapBreakpoint', numhl= 'DapBreakpoint' })
vim.fn.sign_define('DapLogPoint', { text='', texthl='DapLogPoint', linehl='DapLogPoint', numhl= 'DapLogPoint' })
vim.fn.sign_define('DapStopped', { text='', texthl='DapStopped', linehl='DapStopped', numhl= 'DapStopped' })
--

--Keybindings
vim.api.nvim_set_keymap('n', '<space>b', [[:lua require"dap".toggle_breakpoint()<CR>]], { noremap = true })
vim.api.nvim_set_keymap('n', '<space>l', [[:lua require"dap".toggle_breakpoint(nil, nil, vim.fn.input('Log point message: '))<CR>]], { noremap = true})
vim.api.nvim_set_keymap('n', '<space>c', [[:lua require"dap".continue()<CR>]], { noremap = true })
vim.api.nvim_set_keymap('n', '<space><space>', [[:lua require"dap".pause()<CR>]], { noremap = true })
vim.api.nvim_set_keymap('n', '<space>n', [[:lua require"dap".step_over()<CR>]], { noremap = true })
vim.api.nvim_set_keymap('n', '<space>s', [[:lua require"dap".step_into()<CR>]], { noremap = true })
vim.api.nvim_set_keymap('n', '<space>h', [[:lua require"dap.ui.widgets".hover()<CR>]], { noremap = true }) -- hover
vim.api.nvim_set_keymap('n', '<space>=', [[:lua require"dap.ui".eval()<CR>]], { noremap = true }) -- eval
vim.api.nvim_set_keymap('n', '<space>m', [[:lua require"dap".run_to_cursor()<CR>]], { noremap = true })  -- Mouse [ run to cursor ]
vim.api.nvim_set_keymap('n', '<space><Esc>', [[:lua require"dap".terminate()<CR>]], { noremap = true })  -- Mouse [ run to cursor ]
vim.api.nvim_set_keymap('n', '<F9>', [[:lua require"osv".launch({port = 8086})<CR>]], { noremap = true })
