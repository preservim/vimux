local config = require("nvimux.config")
local tmux = require("nvimux.tmux")
local utils = require("nvimux.utils")

local M = {
	last_command = {},
}

M.setup = function(user_opts)
	config.setup(user_opts)
	utils.check()
  M.setup_commands()
end

M.prompt_command = function(prefix)
	local completion = ""
	if config.get("command_shell") then
		completion = "shellcmd"
	end
  local prompt = config.get("prompt_string")
  prefix = prefix or ""

	local opts = {
		prompt = prompt .. prefix,
		completion = completion,
		default = command,
	}

	vim.ui.input(opts, function(command)
    if command ~= nil then
      M.run(prefix .. command)
    end
	end)
end

M.run = function(command, autoreturn)
	if not utils.runner_exists() then
		utils.open()
	end
	autoreturn = autoreturn or true
	table.insert(M.last_command, command)
	utils.reset_runner()
	utils.send_text(utils.expand_command(command))
	if autoreturn then
		utils.send_keys("Enter")
	end
end

M.run_last = function()
	if #M.last_command > 0 then
		M.run(M.last_command[#M.last_command])
	end
end

M.clear_history = function()
	utils.clear_history()
end

M.clear_terminal_screen = function()
	utils.send_keys("C-l")
end

M.interrupt_runner = function()
	utils.send_keys("^c")
end

M.inspect_runner = function()
	utils.select()
	utils.copy_mode()
end

M.inspect_scroll_up = function()
	M.inspect_runner()
	utils.last()
	utils.send_keys("C-u")
end

M.inspect_scroll_down = function()
	M.inspect_runner()
	utils.last()
	utils.send_keys("C-d")
end

M.zoom_runner = function()
	utils.zoom()
end

M.close_runner = function()
	utils.close()
end

M.toggle = function()
	utils.toggle()
end

local CMDS = {
	{
		name = "VimuxRunCommand",
		opts = { desc = "nvimux: run command", nargs = "*", complete = "shellcmd" },
		command = function(c)
			M.run(c.args)
		end,
	},
	{
		name = "VimuxRunLastCommand",
		opts = { desc = "nvimux: rerun last command", bar = true },
		command = function()
			M.run_last()
		end,
	},
	{
		name = "VimuxOpenRunner",
		opts = { desc = "nvimux: open runner", bar = true },
		command = function()
			utils.open()
		end,
	},
	{
		name = "VimuxCloseRunner",
		opts = { desc = "nvimux: close runner", bar = true },
		command = function()
			M.close_runner()
		end,
	},
	{
		name = "VimuxZoomRunner",
		opts = { desc = "nvimux: zoom runner", bar = true },
		command = function()
			M.zoom_runner()
		end,
	},
	{
		name = "VimuxInspectRunner",
		opts = { desc = "nvimux: inspect runner", bar = true },
		command = function()
			M.inspect_runner()
		end,
	},
	{
		name = "VimuxScrollUpInspect",
		opts = { desc = "nvimux: scroll runner up", bar = true },
		command = function()
			M.inspect_scroll_down()
		end,
	},
	{
		name = "VimuxScrollDownInspect",
		opts = { desc = "nvimux: scroll runner down", bar = true },
		command = function()
			M.inspect_scroll_down()
		end,
	},
	{
		name = "VimuxInterruptRunner",
		opts = { desc = "nvimux: interrupt running", bar = true },
		command = function()
			M.interrupt_runner()
		end,
	},
	{
		name = "VimuxPromptCommand",
		opts = { desc = "nvimux: interrupt running", nargs = "*" },
		command = function(c)
			M.prompt_command(c.args)
		end,
	},
	{
		name = "VimuxClearTerminalScreen",
		opts = { desc = "nvimux: interrupt running", bar = true },
		command = function()
			M.clear_terminal_screen()
		end,
	},
	{
		name = "VimuxClearRunnerHistory",
		opts = { desc = "nvimux: interrupt running", bar = true },
		command = function()
			M.clear_history()
		end,
	},
	{
		name = "VimuxTogglePane",
		opts = { desc = "nvimux: interrupt running", bar = true },
		command = function()
			M.toggle()
		end,
	},
}

M.setup_commands = function()
	for _, cmd in ipairs(CMDS) do
		local opts = vim.tbl_extend("force", cmd.opts, { force = true })
		vim.api.nvim_create_user_command(cmd.name, cmd.command, opts)
	end
end
return M
