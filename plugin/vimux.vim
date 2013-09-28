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
  if exists("g:VimuxRunnerIndex")
    call VimuxRunCommand(g:VimuxLastCommand)
  else
    echo "No last vimux command."
  endif
endfunction

function! VimuxRunCommand(command, ...)
  if !exists("g:VimuxRunnerIndex") || _VimuxHasRunner(g:VimuxRunnerIndex) == -1
    call VimuxOpenRunner()
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
  if exists("g:VimuxRunnerIndex")
    call system("tmux send-keys -t ".g:VimuxRunnerIndex." ".a:keys)
  else
    echo "No vimux runner pane/window. Create one with VimuxOpenRunner"
  endif
endfunction

function! VimuxOpenRunner()
  let height = _VimuxOption("g:VimuxHeight", 20)
  let orientation = _VimuxOption("g:VimuxOrientation", "v")
  let nearestIndex = _VimuxNearestIndex()

  if _VimuxOption("g:VimuxUseNearest", 1) == 1 && nearestIndex != -1
    let g:VimuxRunnerIndex = nearestIndex
  else
    call system("tmux split-window -p ".height." -".orientation)
    let g:VimuxRunnerIndex = _VimuxTmuxIndex()
    call system("tmux last-pane")
  endif
endfunction

function! VimuxCloseRunner()
  if exists("g:VimuxRunnerIndex")
    call system("tmux kill-pane -t ".g:VimuxRunnerIndex)
    unlet g:VimuxRunnerIndex
  endif
endfunction

function! VimuxInspectRunner()
  call system("tmux select-pane -t ".g:VimuxRunnerIndex)
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
  if exists("g:VimuxRunnerIndex")
    call system("tmux clear-history -t ".g:VimuxRunnerIndex)
  endif
endfunction

function! VimuxPromptCommand()
  let l:command = input(_VimuxOption("g:VimuxPromptString", "Command? "))
  call VimuxRunCommand(l:command)
endfunction

function! _VimuxTmuxSession()
  return _VimuxTmuxProperty("S")
endfunction

function! _VimuxTmuxIndex()
  return _VimuxTmuxProperty("P")
endfunction

function! _VimuxTmuxWindowIndex()
  return _VimuxTmuxProperty("I")
endfunction

function! _VimuxNearestIndex()
  let panes = split(system("tmux list-panes"), "\n")

  for pane in panes
    if match(pane, "(active)") == -1
      return split(pane, ":")[0]
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

function! _VimuxHasRunner(index)
  return match(system("tmux list-panes"), a:index.":")
endfunction
