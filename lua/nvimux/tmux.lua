local config = require("nvimux.config")

local M = {}

local function all_trim(s)
   return s:match( "^%s*(.-)%s*$" )
end

M.is_executable = function()
	local command = config.get("tmux_command")
	return vim.fn.executable(command) == 1
end

M.exe = function(cmd)
	local command = { config.get("tmux_command") }
	local dbg_command = command[1]

	if type(cmd) == "string" then
		cmd = { cmd }
	end

	for _, v in ipairs(cmd) do
		if type(v) == "table" then
			vim.tbl_extend("force", command, v)
		else
			table.insert(command, tostring(v))
		end
		dbg_command = dbg_command .. " " .. tostring(v)
	end
	if vim.env.TMUX == nil then
		vim.message("Not in a tmux session (TMUX environment variable not found)")
	else
		local result = vim.system(command):wait()
		return all_trim(result.stdout)
	end
	return ""
end

M.send_keys = function(runner, keys)
	M.exe({ "send-keys", "-t", runner, keys })
end

M.get_property = function(name, runner)
  command = { "display" }
  if runner ~= nil then
    table.insert(command, '-t')
    table.insert(command, runner)
  end
  table.insert(command, '-p')
  table.insert(command, name)
	return M.exe(command)
end

return M
