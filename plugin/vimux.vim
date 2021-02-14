if exists('g:loaded_vimux') || &cp
  finish
endif
let g:loaded_vimux = 1

function! s:VimuxOption(option, default)
  if exists(a:option)
    return eval(a:option)
  else
    return a:default
  endif
endfunction

function! s:VimuxTmuxCmd()
  return s:VimuxOption('g:VimuxTmuxCommand', 'tmux')
endfunction

if !executable(s:VimuxTmuxCmd())
  echohl ErrorMsg | echomsg 'Failed to find executable '.s:VimuxTmuxCmd() | echohl None
  finish
endif

command -nargs=* VimuxRunCommand :call VimuxRunCommand(<args>)
command VimuxRunLastCommand :call VimuxRunLastCommand()
command VimuxOpenRunner :call VimuxOpenRunner()
command VimuxCloseRunner :call VimuxCloseRunner()
command VimuxZoomRunner :call VimuxZoomRunner()
command VimuxInspectRunner :call VimuxInspectRunner()
command VimuxScrollUpInspect :call VimuxScrollUpInspect()
command VimuxScrollDownInspect :call VimuxScrollDownInspect()
command VimuxInterruptRunner :call VimuxInterruptRunner()
command -nargs=? VimuxPromptCommand :call VimuxPromptCommand(<args>)
command VimuxClearTerminalScreen :call VimuxClearTerminalScreen()
command VimuxClearRunnerHistory :call VimuxClearRunnerHistory()
command VimuxTogglePane :call VimuxTogglePane()

function! VimuxRunCommandInDir(command, useFile)
    let l:file = ''
    if a:useFile ==# 1
        let l:file = shellescape(expand('%:t'), 1)
    endif
    call VimuxRunCommand('(cd '.shellescape(expand('%:p:h'), 1).' && '.a:command.' '.l:file.')')
endfunction

function! VimuxRunLastCommand()
  if exists('g:VimuxRunnerIndex')
    call VimuxRunCommand(g:VimuxLastCommand)
  else
    echo 'No last vimux command.'
  endif
endfunction

function! VimuxRunCommand(command, ...)
  if !exists('g:VimuxRunnerIndex') || s:VimuxHasRunner(g:VimuxRunnerIndex) == -1
    call VimuxOpenRunner()
  endif

  let l:autoreturn = 1
  if exists('a:1')
    let l:autoreturn = a:1
  endif

  let resetSequence = s:VimuxOption('g:VimuxResetSequence', 'q C-u')
  let g:VimuxLastCommand = a:command

  call VimuxSendKeys(resetSequence)
  call VimuxSendText(a:command)

  if l:autoreturn == 1
    call VimuxSendKeys('Enter')
  endif
endfunction

function! VimuxSendText(text)
  call VimuxSendKeys(shellescape(substitute(a:text, '\n$', ' ', '')))
endfunction

function! VimuxSendKeys(keys)
  if exists('g:VimuxRunnerIndex')
    call s:VimuxTmux('send-keys -t '.g:VimuxRunnerIndex.' '.a:keys)
  else
    echo 'No vimux runner pane/window. Create one with VimuxOpenRunner'
  endif
endfunction

function! VimuxOpenRunner()
  let nearestIndex = s:VimuxNearestIndex()

  if s:VimuxOption('g:VimuxUseNearest', 1) == 1 && nearestIndex != -1
    let g:VimuxRunnerIndex = nearestIndex
  else
    let extraArguments = s:VimuxOption('g:VimuxOpenExtraArgs', '')
    if s:VimuxRunnerType() == 'pane'
      let height = s:VimuxOption('g:VimuxHeight', 20)
      let orientation = s:VimuxOption('g:VimuxOrientation', 'v')
      call s:VimuxTmux('split-window -p '.height.' -'.orientation.' '.extraArguments)
    elseif s:VimuxRunnerType() == 'window'
      call s:VimuxTmux('new-window '.extraArguments)
    endif

    let g:VimuxRunnerIndex = s:VimuxTmuxIndex()
    call s:VimuxSetRunnerName()
    call s:VimuxTmux('last-'.s:VimuxRunnerType())
  endif
endfunction

function! VimuxCloseRunner()
  if exists('g:VimuxRunnerIndex')
    call s:VimuxTmux('kill-'.s:VimuxRunnerType().' -t '.g:VimuxRunnerIndex)
    unlet g:VimuxRunnerIndex
  endif
endfunction

function! VimuxTogglePane()
  if exists('g:VimuxRunnerIndex')
    if s:VimuxRunnerType() == 'window'
        call s:VimuxTmux('join-pane -d -s '.g:VimuxRunnerIndex.' -p '.s:VimuxOption('g:VimuxHeight', 20))
        let g:VimuxRunnerType = 'pane'
    elseif s:VimuxRunnerType() == 'pane'
        let g:VimuxRunnerIndex=substitute(s:VimuxTmux('break-pane -d -t '.g:VimuxRunnerIndex." -P -F '#{window_id}'"), '\n', '', '')
        let g:VimuxRunnerType = 'window'
    endif
  endif
endfunction

function! VimuxZoomRunner()
  if exists('g:VimuxRunnerIndex')
    if s:VimuxRunnerType() == 'pane'
      call s:VimuxTmux('resize-pane -Z -t '.g:VimuxRunnerIndex)
    elseif s:VimuxRunnerType() == 'window'
      call s:VimuxTmux('select-window -t '.g:VimuxRunnerIndex)
    endif
  endif
endfunction

function! VimuxInspectRunner()
  call s:VimuxTmux('select-'.s:VimuxRunnerType().' -t '.g:VimuxRunnerIndex)
  call s:VimuxTmux('copy-mode')
endfunction

function! VimuxScrollUpInspect()
  call VimuxInspectRunner()
  call s:VimuxTmux('last-'.s:VimuxRunnerType())
  call VimuxSendKeys('C-u')
endfunction

function! VimuxScrollDownInspect()
  call VimuxInspectRunner()
  call s:VimuxTmux('last-'.s:VimuxRunnerType())
  call VimuxSendKeys('C-d')
endfunction

function! VimuxInterruptRunner()
  call VimuxSendKeys('^c')
endfunction

function! VimuxClearTerminalScreen()
  if exists('g:VimuxRunnerIndex')
    call VimuxSendKeys('C-l')
  endif
endfunction

function! VimuxClearRunnerHistory()
  if exists('g:VimuxRunnerIndex')
    call s:VimuxTmux('clear-history -t '.g:VimuxRunnerIndex)
  endif
endfunction

function! VimuxPromptCommand(...)
  let command = a:0 == 1 ? a:1 : ''
  let l:command = input(s:VimuxOption('g:VimuxPromptString', 'Command? '), command, 'shellcmd')
  call VimuxRunCommand(l:command)
endfunction

function! s:VimuxTmux(arguments)
  if s:VimuxOption('g:VimuxDebug', 0) != 0
    echom s:VimuxTmuxCmd().' '.a:arguments
  endif
  return system(s:VimuxTmuxCmd().' '.a:arguments)
endfunction

function! s:VimuxTmuxSession()
  return s:VimuxTmuxProperty('#S')
endfunction

function! s:VimuxTmuxIndex()
  if s:VimuxRunnerType() == 'pane'
    return s:VimuxTmuxPaneId()
  else
    return s:VimuxTmuxWindowId()
  end
endfunction

function! s:VimuxTmuxPaneId()
  return s:VimuxTmuxProperty('#{pane_id}')
endfunction

function! s:VimuxTmuxWindowId()
  return s:VimuxTmuxProperty('#{window_id}')
endfunction

function! s:VimuxNearestIndex()
  let t = s:VimuxRunnerType()
  let filter = s:VimuxGetTargetFilter()
  let views = split(s:VimuxTmux('list-'.t."s -F '#{".t.'_active}:#{'.t."_id}'".filter), '\n')

  for view in views
    if match(view, '1:') == -1
      return split(view, ':')[1]
    endif
  endfor

  return -1
endfunction

function! s:VimuxGetTargetFilter()
  let targetName = s:VimuxOption('g:VimuxRunnerName', '')
  if targetName == ''
    return ''
  endif
  let t = s:VimuxRunnerType()
  if t == 'window'
    return " -f '#{==:#{window_name},".targetName."}'"
  elseif t == 'pane'
    return " -f '#{==:#{pane_title},".targetName."}'"
  endif
endfunction

function! s:VimuxSetRunnerName()
  let targetName = s:VimuxOption('g:VimuxRunnerName', '')
  if targetName == ''
    return 
  endif
  let t = s:VimuxRunnerType()
  if t == 'window'
    call s:VimuxTmux('rename-window '.targetName)
  elseif t == 'pane'
    call s:VimuxTmux('select-pane -T '.targetName)
  endif
endfunction


function! s:VimuxRunnerType()
  return s:VimuxOption('g:VimuxRunnerType', 'pane')
endfunction

function! s:VimuxTmuxProperty(property)
    return substitute(s:VimuxTmux("display -p '".a:property."'"), '\n$', '', '')
endfunction

function! s:VimuxHasRunner(index)
  let t = s:VimuxRunnerType()
  return match(s:VimuxTmux('list-'.t."s -F '#{".t."_id}'"), a:index)
endfunction
