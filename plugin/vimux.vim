if exists("g:loaded_vimux") || &cp
  finish
endif
let g:loaded_vimux = 1

if !has("ruby")
  finish
end


" New style commands with 'normalized' names
command VimuxRunLastCommand :call VimuxRunLastCommand()
command VimuxCloseRunner :call VimuxCloseRunner()
command VimuxClosePanes :call VimuxClosePanes()
command VimuxCloseWindows :call VimuxCloseWindows()
command VimuxInspectRunner :call VimuxInspectRunner()
command VimuxScrollUpInspect :call VimuxScrollUpInspect()
command VimuxScrollDownInspect :call VimuxScrollDownInspect()
command VimuxInterruptRunner :call VimuxInterruptRunner()
command VimuxPromptCommand :call VimuxPromptCommand()
command VimuxClearRunnerHistory :call VimuxClearRunnerHistory()

" DEPRECATED
command RunLastVimTmuxCommand :call VimuxRunLastCommand()
command CloseVimTmuxRunner :call VimuxCloseRunner()
command CloseVimTmuxPanes :call VimuxClosePanes()
command CloseVimTmuxWindows :call VimuxCloseWindows()
command InspectVimTmuxRunner :call VimuxInspectRunner()
command InterruptVimTmuxRunner :call VimuxInterruptRunner()
command PromptVimTmuxCommand :call VimuxPromptCommand()

" utility functions
" -----------------
function s:StripStr(string)
  let new_string = substitute(substitute(a:string, '\A\s\+', '', 'g'), '\s\+\z', '', 'g')
  return new_string
endfunction

" private functions
" -----------------
function s:IsInTmux()
  return system('echo $TMUX') =~ '\a\+'
endfunction

" old method:  TmuxSession#_run
function s:TmuxRun(command)
  system('tmux '.a:command)
endfunction

" old method:  CurrentTmuxSession#get_session
function s:GetSession()
  return s:StripStr(s:TmuxRun("display -p '#S'"))
endfunction

" old method:  CurrentTmuxSession#get_property
function s:GetTmuxProperty(type, match)
  return split(s:TmuxRun('list-'.a:type.' | grep '.a:match), ':')[0]
endfunction

" old method:  CurrentTmuxSession#initialize
function s:Initialize()
  if s:IsInTmux()
    let g:VimuxCurrentTmuxSession = s:GetSession()
    let g:VimuxCurrentTmuxWindow = s:GetTmuxProperty('window', 'active')
    let g:VimuxCurrentTmuxPane = s:GetTmuxProperty('pane', 'active')
    let g:VimuxCurrentRunnerPane = s:VimCachedRunnerPane()
  elseif
    echo 'You are not in a tmux session'
  endif
endfunction

" old method:  TmuxSession#_send_command
function s:SendCommandToTmux(command, target, auto_return)
  s:TmuxRun('send-keys -t '.target.' "'.substitute(a:command, '"', '\\"', 'g').'"'
  if a:auto_return == 1
    s:TmuxRun('send-keys -t '.target.' Enter'
  endif
endfunction

" old method:  TmuxSession#target
function s:TmuxTargetPane(args)
  get(a:args, 'session', g:VimuxCurrentTmuxSession).':'.get(a:args, 'window', g:VimuxCurrentTmuxWindow).'.'.get(a:args, 'pane', g:VimuxCurrentTmuxPane)
endfunction

" old method:  TmuxSession#active_pane_id
function s:TmuxActivePaneId()
  "for line in split(s:TmuxRun('list-panes'), '\n')
    "if line =~ '\(active\)'
      "return split(line)[-2]
    "endif
  "endfor
  "return split(s:TmuxRun('list-panes | grep "\(active\)"'), ':')[0]
  return split(s:TmuxRun('list-panes | grep "\(active\)"'))[-2]
endfunction

" old method:  TmuxSession#nearest_inactive_pane_id
function s:TmuxNearestInactivePaneId()
  "let panes = split(s:TmuxRun('list-panes'), '\n')
  "for pane in panes
    "if !(pane =~ '\(active\)')
      "return split(pane, ':')[0]
    "endif
  "endfor
  let panes = split(s:TmuxRun('list-panes | grep "^.*[^(active)]$"'), '\n')
  return len(panes) > 0 ? split(panes[0], ':')[0] : 0
endfunction

" old method: TmuxSession#height
function s:TmuxRunnerPaneHeight()
  if exists("g:VimuxHeight")
    return g:VimuxHeight
  else
    return 20
  endif
endfunction

" old method: TmuxSession#orientation
function s:TmuxRunnerPaneOrientation()
  if exists("g:VimuxOrientation") && (g:VimuxOrientation == 'v' || g:VimuxOrientation == 'h')
    return '-'.g:VimuxOrientation
  else
    return '-v'
  endif
endfunction

" old method:  TmuxSession#runner_pane
function s:VimuxRunnerPane()
  if !exists(g:_VimTmuxRunnerPane)
    let use_nearest_pane = exists("g:VimuxUseNearestPane")
    if use_nearest_pane && s:NearestInactivePaneId()
      s:TmuxRun('select-pane -t '.s:TmuxTargetPane({'pane': s:NearestInactivePaneId()}))
    else
      s:TmuxRun('split-window -p '.s:TmuxRunnerPaneHeight().' '.s:TmuxRunnerPaneOrientation)
    endif
    let g:_VimTmuxRunnerPane = s:TmuxActivePaneId()
    s:SendCommandToTmux('cd '.system('pwd'), s:TmuxTargetPane({'pane': g:_VimTmuxRunnerPane))
  endif

  for line in split(s:TmuxRun('list-panes'), '\n')
    if line =~ g:_VimTmuxRunnerPane
      return split(line, ':')[0]
    endif
  endfor

  VimuxClearWindow()
  return s:VimuxRunnerPane()
endfunction

" old method:  TmuxSession#reset_sequence
function s:TmuxResetSequence()
  if exists('g:VimuxResetSequence')
    return g:VimuxResetSequence
  else
    return 'q C-u'
  endif
endfunction

" old method:  TmuxSession#reset_shell
function s:TmuxResetRunnerPane()
  s:TmuxRun('send-keys -t '.TmuxTargetPane({'pane': s:VimuxRunnerPane}).' '.s:TmuxResetSequence)
endfunction

" old method:  TmuxSession#_move_up_pane
function s:TmuxReturnToVim()
  s:TmuxRun('select-pane -t '.s:TmuxTargetPane)
endfunction

" old method:  TmuxSession#run_shell_command
function s:TmuxRunShellCommand(command, auto_return)
  s:TmuxResetRunnerPane()
  s:SendCommandToTmux(a:command, s:TmuxTargetPane({'pane': s:VimuxRunnerPane}), a:auto_return)
  s:TmuxReturnToVim()
endfunction

" old method:  TmuxSession#interrupt_runner
function s:TmuxInterruptRunner()
  s:TmuxRun('send-keys -t '.TmuxTargetPane({'pane': s:VimuxRunnerPane}).' ^c')
endfunction

" old method:  TmuxSession#close_runner_pane
function s:TmuxCloseRunnerPane()
  s:TmuxRun('kill-pane -t '.TmuxTargetPane({'pane': s:VimuxRunnerPane}))
endfunction

" old method:  TmuxSession#close_other_panes
" This function needs some work... it kills every pane including the one you
" are in... probably not what you want...
function s:TmuxCloseRunnerPane()
  if len(split(s:TmuxRun('list-panes'), '\n')) > 1
    s:TmuxRun('kill-pane -a')
  endif
endfunction

" old method:  TmuxSession#vim_cached_runner_pane
function s:VimCachedRunnerPane()
  if exists("g:_VimTmuxRunnerPane") && type(g:_VimTmuxRunnerPane) == type('')
    return g:_VimTmuxRunnerPane
  else
    return 0
  endif
endfunction

" new style functions
function VimuxRunCommand(command, ...)
  let l:autoreturn = 1

  if exists("a:1")
    let l:autoreturn = a:1
  endif

  let g:_VimTmuxCmd = a:command

  if l:autoreturn == 1
    ruby CurrentTmuxSession.new.run_shell_command(Vim.evaluate("g:_VimTmuxCmd"))
  else
    ruby CurrentTmuxSession.new.run_shell_command(Vim.evaluate("g:_VimTmuxCmd"), false)
  endif
endfunction

" deprecated!
function RunVimTmuxCommand(command, ...)
  " TODO replace me with the direct function call!
  let l:autoreturn = 1

  if exists("a:1")
    let l:autoreturn = a:1
  endif

  let g:_VimTmuxCmd = a:command

  if l:autoreturn == 1
    ruby CurrentTmuxSession.new.run_shell_command(Vim.evaluate("g:_VimTmuxCmd"))
  else
    ruby CurrentTmuxSession.new.run_shell_command(Vim.evaluate("g:_VimTmuxCmd"), false)
  endif
endfunction


function VimuxRunLastCommand()
  if exists("g:_VimTmuxCmd")
    ruby CurrentTmuxSession.new.run_shell_command(Vim.evaluate("g:_VimTmuxCmd"))
  else
    echo "No last command"
  endif
endfunction

" deprecated!
function RunLastVimTmuxCommand()
  call VimuxRunLastCommand()
endfunction


function VimuxClearWindow()
  if exists("g:_VimTmuxRunnerPane")
    unlet g:_VimTmuxRunnerPane
  end
endfunction

" deprecated!
function ClearVimTmuxWindow()
  call VimuxClearWindow()
endfunction


" deprecated!
function CloseVimTmuxWindows()
  call VimuxCloseWindows()
endfunction


function VimuxCloseRunner()
  ruby CurrentTmuxSession.new.close_runner_pane
  call VimuxClearWindow()
endfunction

" deprecated!
function CloseVimTmuxRunner()
  call VimuxCloseRunner()
endfunction


function VimuxClosePanes()
  ruby CurrentTmuxSession.new.close_other_panes
  call VimuxClearWindow()
endfunction

" deprecated!
function CloseVimTmuxPanes()
  call VimuxClosePanes()
endfunction


function VimuxInterruptRunner()
  ruby CurrentTmuxSession.new.interrupt_runner
endfunction

" deprecated!
function InterruptVimTmuxRunner()
  call VimuxInterruptRunner()
endfunction

function VimuxScrollDownInspect()
  ruby CurrentTmuxSession.new.inspect_scroll_down
endfunction

function VimuxScrollUpInspect()
  ruby CurrentTmuxSession.new.inspect_scroll_up
endfunction

function VimuxInspectRunner()
  ruby CurrentTmuxSession.new.inspect_runner
endfunction

" deprecated!
function InspectVimTmuxRunner()
  call VimuxInspectRunner()
endfunction


function VimuxPromptCommand()
  let l:command = input("Command? ")
  call VimuxRunCommand(l:command)
endfunction

" deprecated!
function PromptVimTmuxCommand()
  call VimuxPromptCommand()
endfunction


function VimuxClearRunnerHistory()
  ruby CurrentTmuxSession.new.clear_runner_history
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

  def clear_runner_history
    _run("clear-history -t #{target(:pane => runner_pane)}")
  end

  def height
    if Vim.evaluate('exists("g:VimuxHeight")') != 0
      Vim.evaluate('g:VimuxHeight')
    else
      20
    end
  end

  def orientation
    if Vim.evaluate('exists("g:VimuxOrientation")') != 0 && ["h", "v"].include?(Vim.evaluate('g:VimuxOrientation'))
      "-#{Vim.evaluate('g:VimuxOrientation')}"
    else
      "-v"
    end
  end

  def reset_sequence
    if Vim.evaluate('exists("g:VimuxResetSequence")') != 0
      "#{Vim.evaluate('g:VimuxResetSequence')}"
    else
      "q C-u"
    end
  end

  def inspect_runner
    _run("select-pane -t #{target(:pane => runner_pane)}")
    _run("copy-mode")
    _move_up_pane
  end

  def inspect_send_command(cmd)
    t = target(:pane => runner_pane)
    _run("select-pane -t #{t}")
    _run("copy-mode")
    _send_command(cmd, t, false)
    _move_up_pane
  end

  def inspect_scroll_up
    inspect_send_command("C-u")
  end

  def inspect_scroll_down
    inspect_send_command("C-d")
  end

  def current_panes
    _run('list-panes').split("\n").map do |line|
      line.split(':').first
    end
  end

  def active_pane_id
    _run('list-panes').split("\n").map do |line|
      return line.split[-2] if line =~ /\(active\)/
    end
  end

  def target(args={})
    "#{args.fetch(:session, @session)}:#{args.fetch(:window, @window)}.#{args.fetch(:pane, @pane)}"
  end

  def runner_pane
    if @runner_pane.nil?
      use_nearest_pane = Vim.evaluate('exists("g:VimuxUseNearestPane")') != 0
      if use_nearest_pane && nearest_inactive_pane_id
        _run("select-pane -t #{target(:pane => nearest_inactive_pane_id)}")
      else
        _run("split-window -p #{height} #{orientation}")
      end
      @runner_pane = active_pane_id
      _send_command("cd #{`pwd`}", target(:pane => runner_pane))
      Vim.command("let g:_VimTmuxRunnerPane = '#{@runner_pane}'")
    end

    _run('list-panes').split("\n").map do |line|
      return line.split(':').first if line =~ /#{@runner_pane}/
    end

    @runner_pane = nil
    runner_pane
  end

  def interrupt_runner
    _run("send-keys -t #{target(:pane => runner_pane)} ^c")
  end

  def run_shell_command(command, auto_return = true)
    reset_shell
    _send_command(command, target(:pane => runner_pane), auto_return)
    _move_up_pane
  end

  def close_runner_pane
    _run("kill-pane -t #{target(:pane => runner_pane)}")
  end

  def close_other_panes
    if _run("list-panes").split("\n").length > 1
      _run("kill-pane -a")
    end
  end

  def reset_shell
    _run("send-keys -t #{target(:pane => runner_pane)} #{reset_sequence}")
  end

  def nearest_inactive_pane_id
    panes = _run("list-pane").split("\n")
    pane = panes.find { |p| p !~ /active/ }
    pane ? pane.split(':').first : nil
  end

  def _move_up_pane
    _run("select-pane -t #{target}")
  end

  def _send_command(command, target, auto_return = true)
    _run("send-keys -t #{target} \"#{command.gsub('"', '\"')}\"")
    _run("send-keys -t #{target} Enter") if auto_return
  end

  def _run(command)
    `tmux #{command}`
  end
end

class CurrentTmuxSession < TmuxSession
  def initialize
    if tmux?
      session = self.get_session
      window = self.get_property(:active, :window)
      pane = self.get_property(:active, :pane)

      super(session, window, pane)
    else
      raise "You are not in a tmux session"
    end
  end

  def get_property(match, type)
    _run("list-#{type.to_s}").split("\n").each do |line|
      return line.split(':').first if line =~ /\(#{match.to_s}\)/
    end
  end

  def get_session
    _run("display -p '#S'").strip
  end

  def tmux?
    `echo $TMUX` =~ /.+/ ? true : false
  end
end
EOF
