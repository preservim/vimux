-- ~/.dotfiles/base/config/nvim/lua/plugins.lua
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)


-- Only move on if we can require Packer.
local ok, lazy = pcall(require, "lazy")

if not ok then
    print('lazy.nvim could not be laaded')
    return
end

lazy.setup({
	{
		dir=vim.env.TEST_PLUGIN,
		config=true
	},
	{
		'numToStr/Navigator.nvim',
		config=true
	},
})
vim.keymap.set('n', "<C-h>", require('Navigator').left)
vim.keymap.set('n', "<C-k>", require('Navigator').up)
vim.keymap.set('n', "<C-l>", require('Navigator').right)
vim.keymap.set('n', "<C-j>", require('Navigator').down)
vim.keymap.set('n', "<C-p>", require('Navigator').previous)
