if exists("g:loaded_vimux") || &cp
  finish
endif
let g:loaded_vimux = 1


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


" Utility Functions
" -----------------

function s:StripStr(string)
  let new_string = substitute(substitute(a:string, '\A\s\+', '', 'g'), '\s\+\z', '', 'g')
  return new_string
endfunction

" -----------------


" Private Functions
" -----------------

" old method:  TmuxSession#tmux?
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

" old method:  TmuxSession#vim_cached_runner_pane
function s:VimCachedRunnerPane()
  if exists("g:_VimTmuxRunnerPane") && type(g:_VimTmuxRunnerPane) == type('')
    return g:_VimTmuxRunnerPane
  else
    return 0
  endif
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
    s:SendCommandToTmux('cd '.system('pwd'), s:TmuxTargetPane({'pane': g:_VimTmuxRunnerPane), 1)
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
  s:TmuxRun('send-keys -t '.s:TmuxTargetPane({'pane': s:VimuxRunnerPane}).' '.s:TmuxResetSequence)
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

" old method:  TmuxSession#inspect_runner
function s:TmuxInspectRunner()
  s:TmuxRun('select-pane -t '.s:TmuxTargetPane({'pane': s:VimuxRunnerPane}))
  s:TmuxRun('copy-mode')
  s:TmuxReturnToVim()
endfunction

" old method:  TmuxSession#inspect_send_command
function s:TmuxInspectSendCommand(command)
  let target_pane = s:TmuxTargetPane({'pane': s:VimuxRunnerPane})
  s:TmuxRun('select-pane -t '.target_pane)
  s:TmuxRun('copy-mode')
  s:SendCommandToTmux(a:command, target_pane, 0)
  s:TmuxReturnToVim()
endfunction

" old method:  TmuxSession#inspect_scroll_up
function s:TmuxInspectScrollUp()
  s:TmuxInspectSendCommand('C-u')
endfunction

" old method:  TmuxSession#inspect_scroll_down
function s:TmuxInspectScrollDown()
  s:TmuxInspectSendCommand('C-d')
endfunction

" old method:  TmuxSession#clear_runner_history
function s:TmuxClearRunnerHistory()
  s:TmuxRun('clear-history -t '.s:TmuxTargetPane({'pane': s:VimuxRunnerPane}))
endfunction

" old method:  TmuxSession#interrupt_runner
function s:TmuxInterruptRunner()
  s:TmuxRun('send-keys -t '.s:TmuxTargetPane({'pane': s:VimuxRunnerPane}).' ^c')
endfunction

" old method:  TmuxSession#close_runner_pane
function s:TmuxCloseRunnerPane()
  s:TmuxRun('kill-pane -t '.s:TmuxTargetPane({'pane': s:VimuxRunnerPane}))
endfunction

" old method:  TmuxSession#current_panes    NOT IN USE
function s:TmuxCurrentPanes()
  result = []
  for line in split(s:TmuxRun('list-panes'), '\n')
    add(result, split(line, ':')[0])
  endfor
  return result
endfunction

" old method:  TmuxSession#close_other_panes
" This function needs some work... it kills every pane including the one you
" are in... probably not what you want...
function s:TmuxCloseOtherPanes()
  if len(split(s:TmuxRun('list-panes'), '\n')) > 1
    s:TmuxRun('kill-pane -a')
  endif
endfunction

" -----------------


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


" vim:set ft=vim ff=unix ts=4 sw=2 sts=2:
