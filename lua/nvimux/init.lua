local config = require("nvimux.config")
local tmux = require("nvimux.tmux")
local utils = require("nvimux.utils")

local M = {
}

M.setup = function (user_opts)
  config.setup(user_opts)
end

M.prompt_command = function (...)
  local completion = if config.get('command_shell') then 'shellcmd' else nil end
  local command = nil
  if #arg > 0 then
    command = ''
    for _,v in ipairs(arg) do
      command = command .. tostring(v) .. " "
    end
  end

  opts = {
    prompt = config.get('prompt_string'),
    completion = completion,
    default = command,
  }

  vim.ui.input(opts, function(command)
    if config.get('expand_command') then
      local expanded_command = {}
      for value in string.gmatch(command, "%S+") do
        table.insert(expanded_command, vim.fn.expand(value))
      end
      command = ''
      for _, v in ipairs(expanded_command) do
        command = command .. ' '  .. v
      end
    end
    M.run(command)
  end)
end


M.clear_history = function()
  utils.clear_history()
end

M.clear_terminal_screen = function()
  utils.send_keys('C-l')
end

M.interrupt_runner = function()
  utils.send_keys('^c')
end

M.inspect_runner = function()
  utils.select()
  utils.copy_mode()
end

M.inspect_scroll_up = function()
  M.inspect_runner()
  utils.last()
  utils.send_keys('C-u')
end

M.inspect_scroll_down = function()
  M.inspect_runner()
  utils.last()
  utils.send_keys('C-d')
end

M.zoom_runner = function ()
  utils.zoom()
end

M.close_runner = function ()
  utils.close()
end

M.toggle = function ()
  utils.toggle()
end
return M
