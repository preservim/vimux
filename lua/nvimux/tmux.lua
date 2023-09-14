local config = require("nvimux.config")

local M = { }

M.exe = function (...)
  local command = config.user_opts.tmux
  for _,v in ipairs(arg) do
    command = command .. tostring(v) .. " "
  end
  if config.user_opts.debug then
    print('[vimux] Run command "' .. command .. '"')
  end
  if vim.env.TMUX == nil then
    vim.message("Not in a tmux session (TMUX environment variable not found)")
  else
    vim.system(command)
  end
end

M.send_keys = function(keys)
    M.exe('send-keys -t '.. M.runner_index .. ' ' .. keys)
end

M.get_property = function(name)
 return M.exe("display -p '".. name .."'")
end



return M
