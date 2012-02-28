if !has("ruby")
  finish
end

function! RunVimTmuxCommand(command)
  let g:_VimTmuxCmd = a:command
  ruby CurrentTmuxSession.new.run_shell_command(Vim.evaluate("g:_VimTmuxCmd"))
endfunction

function! ClearVimTmuxWindow()
  unlet g:_VimTmuxRunnerPane
endfunction

function! CloseVimTmuxWindows()
  ruby CurrentTmuxSession.new.close_other_panes
  unlet g:_VimTmuxRunnerPane
endfunction

ruby << EOF
class TmuxSession
  def initialize(session, window, pane)
    @session = session
    @window = window
    @pane = pane
    if Vim.evaluate('exists("g:_VimTmuxRunnerPane")') != 0
      @runner_pane = Vim.evaluate('g:_VimTmuxRunnerPane')
    else
      @runner_pane = nil
    end
  end

  def current_panes
    `tmux list-panes`.split("\n").map do |line|
      line.split(':').first
    end
  end

  def active_pane_id
    `tmux list-panes`.split("\n").map do |line|
      return line.split[-2] if line =~ /\(active\)/
    end
  end

  def target(args={})
    "#{args.fetch(:session, @session)}:#{args.fetch(:window, @window)}.#{args.fetch(:pane, @pane)}"
  end

  def runner_pane
    if @runner_pane.nil?
      run("split-window -p 20")
      @runner_pane = active_pane_id
      Vim.command("let g:_VimTmuxRunnerPane = '#{@runner_pane}'")
    end

    `tmux list-panes`.split("\n").map do |line|
      return line.split(':').first if line =~ /#{@runner_pane}/
    end
  end

  def run_shell_command(command)
    send(command, target(:pane => runner_pane))
    move_up_pane
  end

  def close_other_panes
    run("kill-pane -a")
  end

  def move_up_pane
    run("select-pane -t #{target}")
  end

  def send(command, target)
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
