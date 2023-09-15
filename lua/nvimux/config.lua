local M = {}

---@type user_options
M.default_opts = {
  height = 20,
  orientation = "v",
  use_nearest = true,
  reset_mode_sequence = {
    ["copy-mode"] = "q",
  },
  reset_cmdline_sequence = "C-u",
  prompt_string = "Command? ",
  runner_type = "pane",
  runner_name = "",
  tmux_command = "tmux",
  open_extra_args = {},
  expand_command = false,
  close_on_exit = false,
  command_shell = true,
  runner_query = {},
  keys = {
    clear_screen = "C-l",
  }
}

-- Stores the global user-set options for the plugin.
M.user_opts = nil

-- Setup the global user options for all files.
---@param user_opts user_options|nil The user-defined options to be merged with default_opts.
M.setup = function(user_opts)
  M.user_opts = vim.tbl_deep_extend("keep", user_opts, M.default_opts)
end

M.get = function(config_value_name)
  return M.user_opts[config_value_name]

end

return M
