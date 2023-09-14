local config = require("nvimux.config")
local tmux = require("nvimux.tmux")

local M = {
  runner_index = nil
}

M.has_runner = function(index)
  local runner_type = config.user_opts.runner_type
  return string.gmatch(tmux.tmux('list-'..runner_type.."s -F '#{"..runner_type.."_id}'"), index)
end

M.set_runner_name = function()
  local target_name = config.user_opts.runner_name
  if target_name == nil or target_name == '' then
    return
  end

  local runner_type = config.user_opts.runner_type
  if runner_type == 'window' then
    tmux.exe('rename-window '..target_name)
  elseif runner_type == 'pane' then
    tmux.exe('select-pane -T '..target_name)
  end
end

M.get_target_filter = function()
  local target_name = config.user_opts.runner_name
  if target_name == nil or target_name == '' then
    return
  end

  local runner_type = config.user_opts.runner_type
  if runner_type == 'window' then
    return " -f '#{==:#{window_name},"..target_name.."}'"
  elseif runner_type == 'pane' then
    return " -f '#{==:#{pane_title},"..target_name.."}'"
  end
end


M.get_nearest_runner = function()
  -- Try finding the runner in the current window/session, optionally using a
  -- name/title filter
  local runner_type = config.user_opts.runner_type
  local filter = M.get_target_filter()
  local views = tmux.exe('list-'..runner_type.."s -F '#{"..runner_type..'_active}:#{'..runner_type.."_id}'" .. filter)
  local pattern = '1:'
  for view in string.gmatch(views, "\n+") do
    if string.sub(view, 1, #pattern) == #pattern then
      return string.sub(view, 2)
    end
  end

  return ''
end

M.get_existing_runner_id = function()
  local runner_type = config.user_opts.runner_type
  local query = config.get('runner_query')[runner_type]
  if query == nil or query == '' then
    if config.get('use_nearest') then
      return M.get_nearest_runner()
    else
      return ''
    end
  end
  local current_id = M.get_current_index()
  local message = tmux.exe('select-'.. runner_type..' -t ' .. query)
  if message ~= nil and message ~= '' then
    local runner =  M.get_current_index()
    if runner ~= current_id then
      tmux.exe('last-'.. runner_type)
    end
  end
  return ''
end

M.get_current_index = function()
  local runner_type = config.user_opts.runner_type
  if runner_type == 'pane' then
    return M.get_pane_id()
  else
    return M.get_window_id()
  end
end

M.get_pane_id = function()
  return tmux.get_property("#{pane_id}")
end

M.get_window_id = function()
  return tmux.get_property("#{window_id}")
end

M.get_session = function()
  return tmux.get_property("#S")
end

M.get_pane_options = function()
  local height = config.get('height')
  local orientation = config.get('orientation')
  return '-p '..height..' -'..orientation
end

M.select = function()
  if M.runner_index ~= nil then
    local runner_type = config.user_opts.runner_type
    tmux.exe('select-'..runner_type .. ' -t '.. M.runner_index)
  end
end

M.clear_history = function()
  if M.runner_index ~= nil then
    tmux.exe('clear-history -t '.. M.runner_index)
  end
end

M.copy_mode = function(type)
  if M.runner_index ~= nil then
    tmux.exec('copy-mode')
  end
end

M.last = function(type)
  local runner_type = type or config.user_opts.runner_type
  tmux.exec('last-' .. runner_type)
end

M.send_keys = function(keys)
  if M.runner_index ~= nil then
    tmux.send_keys(keys)
  end
end

M.send_text = function(text)
  M.send_keys(vim.fn.shellescape(text))
end

M.zoom = function()
  local runner_type = config.user_opts.runner_type
  if runner_type == 'pane' then
    tmux.exe('resize-pane -Z -t '.. M.runner_index)
  else
    tmux.exe('select-'.. runner_type..' -t ' .. runner_type)
  end
end

M.close = function ()
  local runner_type = config.get('runner_type')
  tmux.exe('kill-'..runner_type..' -t '.. M.runner_index)
end

M.runner_exists = function ()
  return M.runner_index ~= nil
end

M.toggle = function ()
  if tmux.runner_exists() then
    return
  end
  local runner_type = config.user_opts.runner_type
  if runner_type == 'pane' then
    M.runner_index = tmux.exe('break-pane -d -s '..M.runner_index.." -P -F '#{window_id}'")
    M.user_opts.runner_type = 'window'
  else
    tmux.exe('join-pane -s '..M.runner_index..' '..M.get_pane_options())
    M.user_opts.runner_type = 'pane'
    M.runner_index = M.get_current_index()
    M.last()
  end
end

M.open = function()

  local existing_id = M.get_existing_runner_id()
  if existing_id ~= '' then
    M.runner_index = existing_id
  else
    local extra_args = config.get('open_extra_args')
    local runner_type = config.user_opts.runner_type
    if runner_type == 'pane' then
      tmux.exe('split-window '..M.get_pane_options()..' '..extra_args)
    else
      tmux.exe('new-window '..extra_args)
    end
    M.runner_index = M.get_current_index()
    M.set_runner_name()
    M.last()
  end
end

M.run = function

return M
