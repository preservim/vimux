if !has("ruby")
  finish
end

command RunLastVimTmuxCommand :call RunLastVimTmuxCommand()
command CloseVimTmuxPanes :call CloseVimTmuxPanes()
command CloseVimTmuxWindows :call CloseVimTmuxWindows()
command InspectVimTmuxRunner :call InspectVimTmuxRunner()
command InterruptVimTmuxRunner :call InterruptVimTmuxRunner()
command PromptVimTmuxCommand :call PromptVimTmuxCommand()

function! RunVimTmuxCommand(command)
  let g:_VimTmuxCmd = a:command
  ruby CurrentTmuxSession.new.run_shell_command(Vim.evaluate("g:_VimTmuxCmd"))
endfunction

function! RunLastVimTmuxCommand()
  if exists("g:_VimTmuxCmd")
    ruby CurrentTmuxSession.new.run_shell_command(Vim.evaluate("g:_VimTmuxCmd"))
  else
    echo "No last command"
  endif
endfunction

function! ClearVimTmuxWindow()
  if exists("g:_VimTmuxRunnerPane")
    unlet g:_VimTmuxRunnerPane
  end
endfunction

function! CloseVimTmuxWindows()
  ruby CurrentTmuxSession.new.close_other_panes
  call ClearVimTmuxWindow()
  echoerr "CloseVimTmuxWindows is deprecated, use CloseVimTmuxPanes"
endfunction

function! CloseVimTmuxPanes()
  ruby CurrentTmuxSession.new.close_other_panes
  call ClearVimTmuxWindow()
endfunction

function! InterruptVimTmuxRunner()
  ruby CurrentTmuxSession.new.interrupt_runner
endfunction

function! InspectVimTmuxRunner()
  ruby CurrentTmuxSession.new.inspect_runner
endfunction

function! PromptVimTmuxCommand()
  let l:command = input("Command? ")
  call RunVimTmuxCommand(l:command)
endfunction

ruby << EOF
class TmuxSession
  def initialize(session, window, pane)
    @session = session
    @window = window
    @pane = pane
    @runner_pane = vim_cached_runner_pane
  end

  def vim_cached_runner_pane
    if Vim.evaluate('exists("g:_VimTmuxRunnerPane")') != 0
      Vim.evaluate('g:_VimTmuxRunnerPane')
    else
      nil
    end
  end

  def vim_cached_runner_pane=(runner_pane)
    Vim.command("let g:_VimTmuxRunnerPane = '#{runner_pane}'")
  end

  def clear_vim_cached_runner_pane
    Vim.command("unlet g:_VimTmuxRunnerPane")
  end

  def height
    if Vim.evaluate('exists("g:VimuxHeight")') != 0
      Vim.evaluate('g:VimuxHeight')
    else
      20
    end
  end

  def inspect_runner
    run("select-pane -t #{target(:pane => runner_pane)}")
    run("copy-mode")
  end

  def current_panes
    run('list-panes').split("\n").map do |line|
      line.split(':').first
    end
  end

  def active_pane_id
    run('list-panes').split("\n").map do |line|
      return line.split[-2] if line =~ /\(active\)/
    end
  end

  def target(args={})
    "#{args.fetch(:session, @session)}:#{args.fetch(:window, @window)}.#{args.fetch(:pane, @pane)}"
  end

  def runner_pane
    if @runner_pane.nil?
      run("split-window -p #{height}")
      @runner_pane = active_pane_id
      Vim.command("let g:_VimTmuxRunnerPane = '#{@runner_pane}'")
    end

    run('list-panes').split("\n").map do |line|
      return line.split(':').first if line =~ /#{@runner_pane}/
    end

    @runner_pane = nil
    clear_vim_cached_runner_pane
    runner_pane
  end

  def interrupt_runner
    run("send-keys -t #{target(:pane => runner_pane)} ^c")
  end

  def run_shell_command(command)
    send_command(command, target(:pane => runner_pane))
    move_up_pane
  end

  def close_other_panes
    # if run("list-panes").split("\n").length > 1
      run("kill-pane -a")
    # end
  end

  def move_up_pane
    run("select-pane -t #{target}")
  end

  def send_command(command, target)
    run("send-keys -t #{target} '#{command.gsub("'", "\'")}'")
    run("send-keys -t #{target} Enter")
  end

  def run(command)
    `tmux #{command}`
  end
end

class CurrentTmuxSession < TmuxSession
  def initialize
    session = self.get_property(:attached, :session)
    window = self.get_property(:active, :window)
    pane = self.get_property(:active, :pane)

    super(session, window, pane)
  end

  def get_property(match, type)
    run("list-#{type.to_s}").split("\n").each do |line|
      return line.split(':').first if line =~ /\(#{match.to_s}\)/
    end
  end
end
EOF
