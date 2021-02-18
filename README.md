# Vimux: easily interact with tmux from vim

[![Vint](https://github.com/preservim/vimux/workflows/Vint/badge.svg)](https://github.com/preservim/vimux/actions?workflow=Vint)
[![Check](https://github.com/preservim/vimux/workflows/Check/badge.svg)](https://github.com/preservim/vimux/actions?workflow=Check)

![vimux](https://www.braintreepayments.com/blog/content/images/blog/vimux3.png)

Vimux was originally inspired by [tslime.vim](https://github.com/jgdavey/tslime.vim/network), a plugin that lets you send input to tmux. While tslime.vim works well, it wasn't optimized for the use case of having a smaller tmux pane used to run tests or play with a REPL. The goal of Vimux is to make interacting with tmux from vim effortless.

By default, when you call `VimuxRunCommand` vimux will create a 20% tall horizontal pane under your current tmux pane and execute a command in it without losing the focus on vim. Once that pane exists, whenever you call `VimuxRunCommand` again the command will be executed in that pane. A frequent use case  is wanting to rerun commands over and over. An example of this is running the current file through rspec. Rather than typing that over and over `VimuxRunLastCommand` will execute the last command called with `VimuxRunCommand`.

## Installation

With **[vim-bundle](https://github.com/preservim/vim-bundle)**: `vim-bundle install preservim/vimux`
With **[Vundle](https://github.com/gmarik/Vundle.vim)**: `Plugin 'preservim/vimux'` in your .vimrc

Otherwise download the latest [tarball](https://github.com/preservim/vimux/tarball/master), extract it and move `plugin/vimux.vim` inside `~/.vim/plugin`. If you're using [pathogen](https://github.com/tpope/vim-pathogen), then move the entire folder extracted from the tarball into `~/.vim/bundle`.

_Notes:_ 

* Vimux assumes a reasonably new version of tmux. Some older versions might work but it is recommended to use the latest stable release.

## Usage

The full documentation is available [online](https://raw.github.com/preservim/vimux/master/doc/vimux.txt) and accessible inside vim via `:help vimux`

## Platform-specific Plugins

* [vim-vroom](https://github.com/skalnik/vim-vroom) runner for rspec, cucumber and test/unit; vimux support via `g:vroom_use_vimux`
* [vimux-ruby-test](https://github.com/pgr0ss/vimux-ruby-test) a set of commands to easily run ruby tests
* [vimux-cucumber](https://github.com/cloud8421/vimux-cucumber) run Cucumber Features through Vimux
* [vim-turbux](https://github.com/jgdavey/vim-turbux) Turbo Ruby testing with tmux
* [vimux-pyutils](https://github.com/julienr/vimux-pyutils) A set of functions for vimux that allow to run code blocks in ipython
* [vimux-nose-test](https://github.com/pitluga/vimux-nose-test) Run nose tests in vimux
* [vimux-golang](https://github.com/benmills/vimux-golang) Run go tests in vimux
* [vimux-zeus](https://github.com/jingweno/vimux-zeus) Run zeus commands in vimux
* [vimix](https://github.com/spiegela/vimix) Run Elixir mix commands in vimux
* [vimux-cargo](https://github.com/jtdowney/vimux-cargo) run rust tests and projects using cargo and vimux
* [vimux-bazel-test](https://github.com/pgr0ss/vimux-bazel-test) Run bazel tests in vimux
* [vimux-jest-test](https://github.com/tyewang/vimux-jest-test) Run jest tests in vimux
