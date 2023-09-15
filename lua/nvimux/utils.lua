local config = require("nvimux.config")
local tmux = require("nvimux.tmux")

local M = {
	runner_index = nil,
}

M.check = function()
	if not tmux.is_executable() then
		vim.notify("Cannot execute '" .. config.get("tmux") .. "' command", vim.log.levels.ERROR)
	end
end

M.has_runner = function(index)
	local runner_type = config.user_opts.runner_type
	return string.gmatch(tmux.exe({ "list-" .. runner_type .. "s", "-F", "'#{" .. runner_type .. "_id}'" }), index)
end

M.set_runner_name = function()
	local target_name = config.user_opts.runner_name
	if target_name == nil or target_name == "" then
		return
	end

	local runner_type = config.user_opts.runner_type
	if runner_type == "window" then
		tmux.exe({ "rename-window ", target_name })
	elseif runner_type == "pane" then
		tmux.exe({ "select-pane", "-T", target_name })
	end
end

M.get_target_filter = function()
	local target_name = config.user_opts.runner_name
	if target_name == nil or target_name == "" then
		return
	end

	local runner_type = config.user_opts.runner_type
	if runner_type == "window" then
		return " -f '#{==:#{window_name}," .. target_name .. "}'"
	elseif runner_type == "pane" then
		return " -f '#{==:#{pane_title}," .. target_name .. "}'"
	end
end

M.get_nearest_runner = function()
	-- Try finding the runner in the current window/session, optionally using a
	-- name/title filter
	local runner_type = config.user_opts.runner_type
	local filter = M.get_target_filter() or ""
	local views = tmux.exe({
		"list-" .. runner_type .. "s",
		"-F",
		"'#{" .. runner_type .. "_active}:#{" .. runner_type .. "_id}'",
	})
	local pattern = "1:"
	for view in string.gmatch(views, "[^\r\n]+") do
		if string.sub(view, 1, #pattern) == #pattern then
			return string.sub(view, 2)
		end
	end

	return ""
end

M.get_existing_runner_id = function()
	local runner_type = config.user_opts.runner_type
	local query = config.get("runner_query")[runner_type]
	if query == nil or query == "" then
		if config.get("use_nearest") then
			return M.get_nearest_runner()
		else
			return ""
		end
	end
	local current_id = M.get_current_index()
	local message = tmux.exe({ "select-" .. runner_type, "-t", query })
	if message ~= nil and message ~= "" then
		local runner = M.get_current_index()
		if runner ~= current_id then
			tmux.exe("last-" .. runner_type)
		end
	end
	return ""
end

M.get_current_index = function()
	local runner_type = config.user_opts.runner_type
	if runner_type == "pane" then
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
	local height = config.get("height")
	local orientation = config.get("orientation")
	return { "-p", height, "-" .. orientation }
end

M.select = function()
	if M.runner_index ~= nil then
		local runner_type = config.user_opts.runner_type
		tmux.exe({ "select-" .. runner_type, "-t", M.runner_index })
	end
end

M.clear_history = function()
	if M.runner_index ~= nil then
		tmux.exe({ "clear-history", "-t", M.runner_index })
	end
end

M.copy_mode = function(type)
	if M.runner_index ~= nil then
		tmux.exec("copy-mode")
	end
end

M.last = function(type)
	local runner_type = type or config.user_opts.runner_type
	tmux.exe("last-" .. runner_type)
end

M.send_keys = function(keys)
	if M.runner_index ~= nil then
		tmux.send_keys(M.runner_index, keys)
	end
end

M.send_text = function(text)
	M.send_keys(string.gsub(text, "[\n]*$", ""))
end

M.zoom = function()
	local runner_type = config.user_opts.runner_type
	if runner_type == "pane" then
		tmux.exe({ "resize-pane", "-Z", "-t", M.runner_index })
	else
		tmux.exe({ "select-" .. runner_type, "-t", runner_type })
	end
end

M.close = function()
	local runner_type = config.get("runner_type")
	tmux.exe({ "kill-" .. runner_type, "-t", M.runner_index })
end

M.runner_exists = function()
  if M.runner_index == nil then
    return false
  end
  if tmux.get_property("#{pane_id}", M.runner_index) == M.runner_index then
    return true
  end
  return false
end

M.reset_runner = function()
	if M.runner_index then
		local mode = tmux.get_property("#{pane_mode}", M.runner_index)
		local reset_sequences = config.get("reset_mode_sequence")
		if reset_sequences[mode] ~= nil then
			tmux.send_keys(M.runner_index, reset_sequences[mode])
		end
    local cmd_reset_sequence = config.get("reset_cmdline_sequence")
		if cmd_reset_sequence ~= nil then
			tmux.send_keys(M.runner_index, cmd_reset_sequence)
		end
	end
end

M.toggle = function()
	if tmux.runner_exists() then
		return
	end
	local runner_type = config.user_opts.runner_type
	if runner_type == "pane" then
		M.runner_index = tmux.exe({ "break-pane", "-d", "-s", M.runner_index, "-P", "-F", "'#{window_id}'" })
		M.user_opts.runner_type = "window"
	else
		tmux.exe({ "join-pane", "-s", M.runner_index, M.get_pane_options() })
		M.user_opts.runner_type = "pane"
		M.runner_index = M.get_current_index()
		M.last()
	end
end

M.open = function()
	local existing_id = M.get_existing_runner_id()
	if existing_id ~= "" then
		M.runner_index = existing_id
	else
		local extra_args = config.get("open_extra_args")
		local runner_type = config.user_opts.runner_type
		if runner_type == "pane" then
			tmux.exe({ "split-window", M.get_pane_options(), extra_args })
		else
			tmux.exe({ "new-window", extra_args })
		end
		M.runner_index = M.get_current_index()
		M.set_runner_name()
		M.last()
	end
end

M.expand_command = function(command)
  if config.get("expand_command") then
    local expanded_command = {}
    for value in string.gmatch(command, "%S+") do
      table.insert(expanded_command, vim.fn.expand(value))
    end
    command = ""
    for _, v in ipairs(expanded_command) do
      command = command .. " " .. v
    end
  end
  return command
end

return M
