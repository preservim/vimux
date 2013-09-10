if exists("g:loaded_vimux") || &cp
  finish
endif
let g:loaded_vimux = 1

command VimuxRunLastCommand :call VimuxRunLastCommand()
command VimuxCloseRunner :call VimuxCloseRunner()
command VimuxInspectRunner :call VimuxInspectRunner()
command VimuxScrollUpInspect :call VimuxScrollUpInspect()
command VimuxScrollDownInspect :call VimuxScrollDownInspect()
command VimuxInterruptRunner :call VimuxInterruptRunner()
command VimuxPromptCommand :call VimuxPromptCommand()
command VimuxClearRunnerHistory :call VimuxClearRunnerHistory()

function! VimuxRunLastCommand()
  if exists("g:VimuxRunnerPaneId")
    call VimuxRunCommand(g:VimuxLastCommand)
  else
    echo "No last vimux command."
  endif
endfunction

function! VimuxRunCommand(command, ...)
  if !exists("g:VimuxRunnerPaneId") || _VimuxHasPane(g:VimuxRunnerPaneId) == -1
    call VimuxOpenPane()
  endif

  let l:autoreturn = 1
  if exists("a:1")
    let l:autoreturn = a:1
  endif

  let resetSequence = _VimuxOption("g:VimuxResetSequence", "q C-u")
  let g:VimuxLastCommand = a:command

  call VimuxSendKeys(resetSequence)
  call VimuxSendText(a:command)

  if l:autoreturn == 1
    call VimuxSendKeys("Enter")
  endif
endfunction

function! VimuxSendText(text)
  call VimuxSendKeys('"'.escape(a:text, '"').'"')
endfunction

function! VimuxSendKeys(keys)
  if exists("g:VimuxRunnerPaneId")
    call system("tmux send-keys -t ".g:VimuxRunnerPaneId." ".a:keys)
  else
    echo "No vimux runner pane. Create one with VimuxOpenPane"
  endif
endfunction

function! VimuxOpenPane()
  let height = _VimuxOption("g:VimuxHeight", 20)
  let orientation = _VimuxOption("g:VimuxOrientation", "v")
  let nearestId = _VimuxNearestPaneId()

  if _VimuxOption("g:VimuxUseNearestPane", -1) == 1 && nearestId != -1
    let g:VimuxRunnerPaneId = nearestId
  else
    let g:VimuxRunnerPaneId = substitute(system('tmux split-window -P -F "#{pane_id}" -p '.height." -".orientation), "\\n$", "", "")
    call system("tmux last-pane")
  endif
endfunction

function! VimuxCloseRunner()
  if exists("g:VimuxRunnerPaneId")
    call system("tmux kill-pane -t ".g:VimuxRunnerPaneId)
    unlet g:VimuxRunnerPaneId
  endif
endfunction

function! VimuxInspectRunner()
  call system("tmux select-pane -t ".g:VimuxRunnerPaneId)
  call system("tmux copy-mode")
endfunction

function! VimuxScrollUpInspect()
  call VimuxInspectRunner()
  call system("tmux last-pane")
  call VimuxSendKeys("C-u")
endfunction

function! VimuxScrollDownInspect()
  call VimuxInspectRunner()
  call system("tmux last-pane")
  call VimuxSendKeys("C-d")
endfunction

function! VimuxInterruptRunner()
  call VimuxSendKeys("^c")
endfunction

function! VimuxClearRunnerHistory()
  if exists("g:VimuxRunnerPaneId")
    call system("tmux clear-history -t ".g:VimuxRunnerPaneId)
  endif
endfunction

function! VimuxPromptCommand()
  let l:command = input(_VimuxOption("g:VimuxPromptString", "Command? "))
  call VimuxRunCommand(l:command)
endfunction

function! _VimuxTmuxSession()
  return _VimuxTmuxProperty("S")
endfunction

function! _VimuxTmuxPaneId()
  return _VimuxTmuxProperty("{pane_id}")
endfunction

function! _VimuxTmuxWindowIndex()
  return _VimuxTmuxProperty("I")
endfunction

function! _VimuxNearestPaneId()
  let panes = split(system('tmux list-panes -F "#{pane_active}:#{pane_id}"'), "\n")

  for pane in panes
    if match(pane, "1:") == -1
      return split(pane, ":")[1]
    endif
  endfor

  return -1
endfunction

function! _VimuxOption(option, default)
  if exists(a:option)
    return eval(a:option)
  else
    return a:default
  endif
endfunction

function! _VimuxTmuxProperty(property)
    return substitute(system("tmux display -p '#".a:property."'"), '\n$', '', '')
endfunction

function! _VimuxHasPane(index)
  return match(system('tmux list-panes -F "#{pane_id}"'), a:index)
endfunction
