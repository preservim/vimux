"if exists("g:loaded_vimux") || &cp
"  finish
"endif
let g:loaded_vimux = 1

command! -nargs=* VimuxRunCommand :call VimuxRunCommand(<args>)
command! VimuxRunLastCommand :call VimuxRunLastCommand()
command! VimuxCloseRunner :call VimuxCloseRunner()
command! VimuxZoomRunner :call VimuxZoomRunner()
command! VimuxInspectRunner :call VimuxInspectRunner()
command! VimuxScrollUpInspect :call VimuxScrollUpInspect()
command! VimuxScrollDownInspect :call VimuxScrollDownInspect()
command! VimuxInterruptRunner :call VimuxInterruptRunner()
command! -nargs=? VimuxPromptCommand :call VimuxPromptCommand(<args>)
command! VimuxClearRunnerHistory :call VimuxClearRunnerHistory()
command! VimuxTogglePane :call VimuxTogglePane()
command! VimuxStatus :call VimuxStatus()

function! VimuxRunCommandInDir(command, useFile)
    let l:file = ""
    if a:useFile ==# 1
        let l:file = shellescape(expand('%:t'), 1)
    endif
    call VimuxRunCommand("(cd ".shellescape(expand('%:p:h'), 1)." && ".a:command." ".l:file.")")
endfunction

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
  call VimuxSendKeys('"'.escape(a:text, '\"$`').'"')
endfunction

function! VimuxSendKeys(keys)
  if exists("g:VimuxRunnerIndex")
    call _VimuxTmux("send-keys -t ".join(g:VimuxRunnerIndex,"\.")." ".a:keys)
  else
    echo "No vimux runner pane/window. Create one with VimuxOpenRunner"
  endif
endfunction

function! VimuxOpenRunner()
  let nearestIndex = _VimuxNearestIndex()

  if _VimuxOption("g:VimuxUseNearest", 1) == 1 && nearestIndex != []
    let g:VimuxRunnerIndex = nearestIndex
  else
    if _VimuxRunnerType() ==# "pane"
      let height = _VimuxOption("g:VimuxHeight", 20)
      let orientation = _VimuxOption("g:VimuxOrientation", "v")
      call _VimuxTmux("split-window -p ".height." -".orientation)
    elseif _VimuxRunnerType() ==# "window"
      call _VimuxTmux("new-window")
    endif

    let g:VimuxRunnerIndex = _VimuxVimPane()[0:1]
    call _VimuxTmux("last-"._VimuxRunnerType())
  endif
endfunction

function! VimuxCloseRunner()
  if exists("g:VimuxRunnerIndex")
    call _VimuxTmux("kill-pane"." -t ".join(g:VimuxRunnerIndex,"\."))
    unlet g:VimuxRunnerIndex
  endif
endfunction

function! VimuxTogglePane()
  if _VimuxRunnerType() ==# "window"
    if exists("g:VimuxRunnerIndex")
      call _VimuxTmux("join-pane -d -s ".join(g:VimuxRunnerIndex,"\.")." -p "._VimuxOption("g:VimuxHeight", 20))
    "  let g:VimuxRunnerIndex=substitute(_VimuxVimPane(),"\\(.\\)$","\\1"+1,"g")
      let g:VimuxRunnerIndex=[_VimuxVimPane()[0],_VimuxVimPane()[1]+1]
    endif
    let g:VimuxRunnerType = "pane"
  elseif _VimuxRunnerType() ==# "pane"
    if exists("g:VimuxRunnerIndex")
      let g:VimuxRunnerIndex=split(substitute(_VimuxTmux("break-pane -d -s ".join(g:VimuxRunnerIndex,"\.")." -P -F '#{window_index}'"), "\n", "", "")."\.0","\\.")
    endif
    let g:VimuxRunnerType = "window"
  endif
  call VimuxStatus()
  return 1
endfunction

function! VimuxZoomRunner()
  if exists("g:VimuxRunnerIndex")
    if _VimuxRunnerType() ==# "pane"
      let g:VimuxRunnerIndex=split(substitute(_VimuxTmux("break-pane -s ".join(g:VimuxRunnerIndex,"\.")." -P -F '#{window_index}'"), "\n", "", "")."\.0","\\.")
      let g:VimuxRunnerType = "window"
    elseif _VimuxRunnerType() ==# "window"
      call _VimuxTmux("select-window -t ".join(g:VimuxRunnerIndex,"\."))
    endif
  endif
endfunction

function! VimuxInspectRunner()
  if exists("g:VimuxRunnerIndex")
    call _VimuxTmux("select-"._VimuxRunnerType()." -t ".join(g:VimuxRunnerIndex,"\."))
    call _VimuxTmux("copy-mode")
  endif
endfunction

function! VimuxScrollUpInspect()
  call VimuxInspectRunner()
  call _VimuxTmux("last-"._VimuxRunnerType())
  call VimuxSendKeys("C-u")
endfunction

function! VimuxScrollDownInspect()
  call VimuxInspectRunner()
  call _VimuxTmux("last-"._VimuxRunnerType())
  call VimuxSendKeys("C-d")
endfunction

function! VimuxInterruptRunner()
  call VimuxSendKeys("^c")
endfunction

function! VimuxClearRunnerHistory()
  if exists("g:VimuxRunnerIndex")
    call _VimuxTmux("clear-history -t ".join(g:VimuxRunnerIndex,"\."))
  endif
endfunction

function! VimuxPromptCommand(...)
  let command = a:0 == 1 ? a:1 : ""
  let l:command = input(_VimuxOption("g:VimuxPromptString", "Command? "), command)
  call VimuxRunCommand(l:command)
endfunction

function! VimuxStatus()
  exe "echo \"Runner Type: \"._VimuxRunnerType().\"	|	\" . (exists(\"g:VimuxRunnerIndex\")?\"Runner Index: \".join(g:VimuxRunnerIndex,\"\\.\"):\"No Runner\")"
endfunction

function! _VimuxTmux(arguments)
  let l:command = _VimuxOption("g:VimuxTmuxCommand", "tmux")
  return system(l:command." ".a:arguments)
endfunction

function! _VimuxTmuxSession()
  return _VimuxTmuxProperty("#S")
endfunction

function! _VimuxVimPane()
"  return _VimuxTmuxProperty("#I.#P")
"  return ["window" : _VimuxTmuxProperty("#I"), "pane" : _VimuxTmuxProperty("#P")]
  return split(_VimuxTmuxProperty("#I.#P.#{pane_active}"),"\\.")
endfunction

function! _VimuxRunnerPaneIndex()
  return g:VimuxRunnerIndex[1]
endfunction

function! _VimuxRunnerWindowIndex()
  return g:VimuxRunnerIndex[0]
endfunction

function! _VimuxNearestIndex()
  let vimpane = _VimuxVimPane()

  if _VimuxRunnerType() ==# "pane"
    let panes = _VimuxGetWindowPanes()
    for pane in panes
      if pane[2] == 0 && pane[0] == vimpane[0] && _VimuxPaneIsValid(pane[0:1])
	return pane[0:1]
      endif
    endfor
    return []
  elseif _VimuxRunnerType() ==# "window"
    let panes = _VimuxGetSessionPanes()
    for pane in panes
      if pane[2] == 1 && pane[0] != vimpane[0] && _VimuxWindowPaneCnt(pane[0], panes) == 1 && _VimuxPaneIsValid(pane[0:1])
	return pane[0:1]
      endif
    endfor
    return []
  endif
endfunction

function! _VimuxRunnerType()
  return _VimuxOption("g:VimuxRunnerType", "pane")
endfunction

function! _VimuxOption(option, default)
  if exists(a:option)
    return eval(a:option)
  else
    return a:default
  endif
endfunction

function! _VimuxTmuxProperty(property)
    return substitute(_VimuxTmux("display -p '".a:property."'"), '\n$', '', '')
endfunction

function! _VimuxHasRunner(index)
  return match(_VimuxTmux("list-panes -s"), join(a:index,"\.").":")
endfunction

function! _VimuxPaneProcs(index)
    let panetty=substitute(substitute(_VimuxTmux("display -t ".join(a:index,"\.")." -p \"#{pane_tty}\""),"\n","",""),"/dev/","","")
    return split(system("pgrep -l -t".panetty),"\n")
endfunction

function! _VimuxPaneIsValid(index)
  let procs = _VimuxPaneProcs(a:index)
  if len(procs) != 1
    return 0
  else
    for shell in _VimuxOption("g:VimuxShells",["bash","zsh"])
      if match(procs[0], shell) != -1
	return 1
      endif
    endfor
    return 0
  endif
endfunction

function! _VimuxPaneExists(index, panes)
  let index = join(a:index,"\.")
  for pane in a:panes
    if join(pane[0:1],"\.") ==# index
      return 1
    endif
  endfor
  return 0
endfunction

function! _VimuxGetSessionPanes()
  let panes = split(_VimuxTmux("list-panes -s -F \"#I.#P.#{pane_active}\""),"\n")
  let i = 0
  while i < len(panes)
    let panes[i] = split(panes[i], "\\.")
    let i += 1
  endwhile
  return panes
endfunction

function! _VimuxGetWindowPanes()
  let panes = split(_VimuxTmux("list-panes -F \"#I.#P.#{pane_active}\""),"\n")
  let i = 0
  while i < len(panes)
    let panes[i] = split(panes[i], "\\.")
    let i += 1
  endwhile
  return panes
endfunction

function! _VimuxWindowPaneCnt(window, panes)
  let pane_cnt = 0
  for pane in a:panes
    if pane[0] == a:window
      let pane_cnt += 1
    endif
  endfor
  return pane_cnt
endfunction
