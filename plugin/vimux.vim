if exists('g:loaded_vimux') || &compatible
  finish
endif
let g:loaded_vimux = 1

function! VimuxOption(option, default)
  if exists(a:option)
    return eval(a:option)
  else
    return a:default
  endif
endfunction

function! s:tmuxCmd()
  return VimuxOption('g:VimuxTmuxCommand', 'tmux')
endfunction

if !executable(s:tmuxCmd())
  echohl ErrorMsg | echomsg 'Failed to find executable '.s:tmuxCmd() | echohl None
  finish
endif

command -bar -nargs=* VimuxRunCommand :call VimuxRunCommand(<args>)
command -bar VimuxRunLastCommand :call VimuxRunLastCommand()
command -bar VimuxOpenRunner :call VimuxOpenRunner()
command -bar VimuxCloseRunner :call VimuxCloseRunner()
command -bar VimuxZoomRunner :call VimuxZoomRunner()
command -bar VimuxInspectRunner :call VimuxInspectRunner()
command -bar VimuxScrollUpInspect :call VimuxScrollUpInspect()
command -bar VimuxScrollDownInspect :call VimuxScrollDownInspect()
command -bar VimuxInterruptRunner :call VimuxInterruptRunner()
command -bar -nargs=? VimuxPromptCommand :call VimuxPromptCommand(<args>)
command -bar VimuxClearTerminalScreen :call VimuxClearTerminalScreen()
command -bar VimuxClearRunnerHistory :call VimuxClearRunnerHistory()
command -bar VimuxTogglePane :call VimuxTogglePane()

function! VimuxRunCommandInDir(command, useFile)
  let l:file = ''
  if a:useFile ==# 1
    let l:file = shellescape(expand('%:t'), 1)
  endif
  call VimuxRunCommand('(cd '.shellescape(expand('%:p:h'), 1).' && '.a:command.' '.l:file.')')
endfunction

function! VimuxRunLastCommand()
  if exists('g:VimuxLastCommand')
    call VimuxRunCommand(g:VimuxLastCommand)
  else
    echo 'No last vimux command.'
  endif
endfunction

function! VimuxRunCommand(command, ...)
  if !exists('g:VimuxRunnerIndex') || s:hasRunner(g:VimuxRunnerIndex) ==# -1
    call VimuxOpenRunner()
  endif
  let l:autoreturn = 1
  if exists('a:1')
    let l:autoreturn = a:1
  endif
  let resetSequence = VimuxOption('g:VimuxResetSequence', 'q C-u')
  let g:VimuxLastCommand = a:command
  call VimuxSendKeys(resetSequence)
  call VimuxSendText(a:command)
  if l:autoreturn ==# 1
    call VimuxSendKeys('Enter')
  endif
endfunction

function! VimuxSendText(text)
  call VimuxSendKeys(shellescape(substitute(a:text, '\n$', ' ', '')))
endfunction

function! VimuxSendKeys(keys)
  if exists('g:VimuxRunnerIndex')
    call VimuxTmux('send-keys -t '.g:VimuxRunnerIndex.' '.a:keys)
  else
    echo 'No vimux runner pane/window. Create one with VimuxOpenRunner'
  endif
endfunction

function! VimuxOpenRunner()
  let nearestIndex = s:nearestIndex()
  if VimuxOption('g:VimuxUseNearest', 1) ==# 1 && nearestIndex != -1
    let g:VimuxRunnerIndex = nearestIndex
  else
    let extraArguments = VimuxOption('g:VimuxOpenExtraArgs', '')
    if s:runnerType() ==# 'pane'
      let height = VimuxOption('g:VimuxHeight', 20)
      let orientation = VimuxOption('g:VimuxOrientation', 'v')
      call VimuxTmux('split-window -p '.height.' -'.orientation.' '.extraArguments)
    elseif s:runnerType() ==# 'window'
      call VimuxTmux('new-window '.extraArguments)
    endif
    let g:VimuxRunnerIndex = s:tmuxIndex()
    call s:setRunnerName()
    call VimuxTmux('last-'.s:runnerType())
  endif
endfunction

function! VimuxCloseRunner()
  if exists('g:VimuxRunnerIndex')
    call VimuxTmux('kill-'.s:runnerType().' -t '.g:VimuxRunnerIndex)
    unlet g:VimuxRunnerIndex
  endif
endfunction

function! VimuxTogglePane()
  if exists('g:VimuxRunnerIndex')
    if s:runnerType() ==# 'window'
      call VimuxTmux('join-pane -d -s '.g:VimuxRunnerIndex.' -p '.VimuxOption('g:VimuxHeight', 20))
      let g:VimuxRunnerType = 'pane'
    elseif s:runnerType() ==# 'pane'
      let g:VimuxRunnerIndex=substitute(VimuxTmux('break-pane -d -t '.g:VimuxRunnerIndex." -P -F '#{window_id}'"), '\n', '', '')
      let g:VimuxRunnerType = 'window'
    endif
  endif
endfunction

function! VimuxZoomRunner()
  if exists('g:VimuxRunnerIndex')
    if s:runnerType() ==# 'pane'
      call VimuxTmux('resize-pane -Z -t '.g:VimuxRunnerIndex)
    elseif s:runnerType() ==# 'window'
      call VimuxTmux('select-window -t '.g:VimuxRunnerIndex)
    endif
  endif
endfunction

function! VimuxInspectRunner()
  call VimuxTmux('select-'.s:runnerType().' -t '.g:VimuxRunnerIndex)
  call VimuxTmux('copy-mode')
endfunction

function! VimuxScrollUpInspect()
  call VimuxInspectRunner()
  call VimuxTmux('last-'.s:runnerType())
  call VimuxSendKeys('C-u')
endfunction

function! VimuxScrollDownInspect()
  call VimuxInspectRunner()
  call VimuxTmux('last-'.s:runnerType())
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
    call VimuxTmux('clear-history -t '.g:VimuxRunnerIndex)
  endif
endfunction

function! VimuxPromptCommand(...)
  let command = a:0 ==# 1 ? a:1 : ''
  let l:command = input(VimuxOption('g:VimuxPromptString', 'Command? '), command, 'shellcmd')
  call VimuxRunCommand(l:command)
endfunction

function! VimuxTmux(arguments)
  if VimuxOption('g:VimuxDebug', 0) != 0
    echom s:tmuxCmd().' '.a:arguments
  endif
  return system(s:tmuxCmd().' '.a:arguments)
endfunction

function! s:tmuxSession()
  return s:tmuxProperty('#S')
endfunction

function! s:tmuxIndex()
  if s:runnerType() ==# 'pane'
    return s:tmuxPaneId()
  else
    return s:tmuxWindowId()
  end
endfunction

function! s:tmuxPaneId()
  return s:tmuxProperty('#{pane_id}')
endfunction

function! s:tmuxWindowId()
  return s:tmuxProperty('#{window_id}')
endfunction

function! s:nearestIndex()
  let t = s:runnerType()
  let filter = s:getTargetFilter()
  let views = split(VimuxTmux('list-'.t."s -F '#{".t.'_active}:#{'.t."_id}'".filter), '\n')
  for view in views
    if match(view, '1:') ==# -1
      return split(view, ':')[1]
    endif
  endfor
  return -1
endfunction

function! s:getTargetFilter()
  let targetName = VimuxOption('g:VimuxRunnerName', '')
  if targetName ==# ''
    return ''
  endif
  let t = s:runnerType()
  if t ==# 'window'
    return " -f '#{==:#{window_name},".targetName."}'"
  elseif t ==# 'pane'
    return " -f '#{==:#{pane_title},".targetName."}'"
  endif
endfunction

function! s:setRunnerName()
  let targetName = VimuxOption('g:VimuxRunnerName', '')
  if targetName ==# ''
    return
  endif
  let t = s:runnerType()
  if t ==# 'window'
    call VimuxTmux('rename-window '.targetName)
  elseif t ==# 'pane'
    call VimuxTmux('select-pane -T '.targetName)
  endif
endfunction

function! s:runnerType()
  return VimuxOption('g:VimuxRunnerType', 'pane')
endfunction

function! s:tmuxProperty(property)
  return substitute(VimuxTmux("display -p '".a:property."'"), '\n$', '', '')
endfunction

function! s:hasRunner(index)
  let t = s:runnerType()
  return match(VimuxTmux('list-'.t."s -F '#{".t."_id}'"), a:index)
endfunction
