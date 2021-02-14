if exists('g:loaded_vimux') || &compatible
  finish
endif
let g:loaded_vimux = 1

" Set up all global options with defaults right away, in one place
let g:VimuxDebug         = get(g:, 'VimuxDebug',         v:false)
let g:VimuxHeight        = get(g:, 'VimuxHeight',        20)
let g:VimuxOpenExtraArgs = get(g:, 'VimuxOpenExtraArgs', '')
let g:VimuxOrientation   = get(g:, 'VimuxOrientation',   'v')
let g:VimuxPromptString  = get(g:, 'VimuxPromptString',  'Command? ')
let g:VimuxResetSequence = get(g:, 'VimuxResetSequence', 'q C-u')
let g:VimuxRunnerName    = get(g:, 'VimuxRunnerName',    '')
let g:VimuxRunnerType    = get(g:, 'VimuxRunnerType',    'pane')
let g:VimuxTmuxCommand   = get(g:, 'VimuxTmuxCommand',   'tmux')
let g:VimuxUseNearest    = get(g:, 'VimuxUseNearest',    v:true)

if !executable(g:VimuxTmuxCommand)
  echohl ErrorMsg | echomsg 'Failed to find executable '.g:VimuxTmuxCommand | echohl None
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
  if !exists('g:VimuxRunnerIndex') || s:VimuxHasRunner(g:VimuxRunnerIndex) ==# -1
    call VimuxOpenRunner()
  endif

  let l:autoreturn = 1
  if exists('a:1')
    let l:autoreturn = a:1
  endif

  let resetSequence = g:VimuxResetSequence
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
    call s:VimuxTmux('send-keys -t '.g:VimuxRunnerIndex.' '.a:keys)
  else
    echo 'No vimux runner pane/window. Create one with VimuxOpenRunner'
  endif
endfunction

function! VimuxOpenRunner()
  let nearestIndex = s:VimuxNearestIndex()

  if g:VimuxUseNearest ==# 1 && nearestIndex != -1
    let g:VimuxRunnerIndex = nearestIndex
  else
    let extraArguments = g:VimuxOpenExtraArgs
    if g:VimuxRunnerType ==# 'pane'
      let height = g:VimuxHeight
      let orientation = g:VimuxOrientation
      call s:VimuxTmux('split-window -p '.height.' -'.orientation.' '.extraArguments)
    elseif g:VimuxRunnerType ==# 'window'
      call s:VimuxTmux('new-window '.extraArguments)
    endif

    let g:VimuxRunnerIndex = s:VimuxTmuxIndex()
    call s:VimuxSetRunnerName()
    call s:VimuxTmux('last-'.g:VimuxRunnerType)
  endif
endfunction

function! VimuxCloseRunner()
  if exists('g:VimuxRunnerIndex')
    call s:VimuxTmux('kill-'.g:VimuxRunnerType.' -t '.g:VimuxRunnerIndex)
    unlet g:VimuxRunnerIndex
  endif
endfunction

function! VimuxTogglePane()
  if exists('g:VimuxRunnerIndex')
    if g:VimuxRunnerType ==# 'window'
      call s:VimuxTmux('join-pane -d -s '.g:VimuxRunnerIndex.' -p '.g:VimuxHeight)
      let g:VimuxRunnerType = 'pane'
    elseif g:VimuxRunnerType ==# 'pane'
      let g:VimuxRunnerIndex=substitute(s:VimuxTmux('break-pane -d -t '.g:VimuxRunnerIndex." -P -F '#{window_id}'"), '\n', '', '')
      let g:VimuxRunnerType = 'window'
    endif
  endif
endfunction

function! VimuxZoomRunner()
  if exists('g:VimuxRunnerIndex')
    if g:VimuxRunnerType ==# 'pane'
      call s:VimuxTmux('resize-pane -Z -t '.g:VimuxRunnerIndex)
    elseif g:VimuxRunnerType ==# 'window'
      call s:VimuxTmux('select-window -t '.g:VimuxRunnerIndex)
    endif
  endif
endfunction

function! VimuxInspectRunner()
  call s:VimuxTmux('select-'.g:VimuxRunnerType.' -t '.g:VimuxRunnerIndex)
  call s:VimuxTmux('copy-mode')
endfunction

function! VimuxScrollUpInspect()
  call VimuxInspectRunner()
  call s:VimuxTmux('last-'.g:VimuxRunnerType)
  call VimuxSendKeys('C-u')
endfunction

function! VimuxScrollDownInspect()
  call VimuxInspectRunner()
  call s:VimuxTmux('last-'.g:VimuxRunnerType)
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
  let command = a:0 ==# 1 ? a:1 : ''
  let l:command = input(g:VimuxPromptString, command, 'shellcmd')
  call VimuxRunCommand(l:command)
endfunction

function! s:VimuxTmux(arguments)
  if g:VimuxDebug
    echom g:VimuxTmuxCommand.' '.a:arguments
  endif
  return system(g:VimuxTmuxCommand.' '.a:arguments)
endfunction

function! s:VimuxTmuxSession()
  return s:VimuxTmuxProperty('#S')
endfunction

function! s:VimuxTmuxIndex()
  if g:VimuxRunnerType ==# 'pane'
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
  let t = g:VimuxRunnerType
  let filter = s:VimuxGetTargetFilter()
  let views = split(s:VimuxTmux('list-'.t."s -F '#{".t.'_active}:#{'.t."_id}'".filter), '\n')

  for view in views
    if match(view, '1:') ==# -1
      return split(view, ':')[1]
    endif
  endfor

  return -1
endfunction

function! s:VimuxGetTargetFilter()
  let targetName = g:VimuxRunnerName
  if targetName ==# ''
    return ''
  endif
  let t = g:VimuxRunnerType
  if t ==# 'window'
    return " -f '#{==:#{window_name},".targetName."}'"
  elseif t ==# 'pane'
    return " -f '#{==:#{pane_title},".targetName."}'"
  endif
endfunction

function! s:VimuxSetRunnerName()
  let targetName = g:VimuxRunnerName
  if targetName ==# ''
    return 
  endif
  let t = g:VimuxRunnerType
  if t ==# 'window'
    call s:VimuxTmux('rename-window '.targetName)
  elseif t ==# 'pane'
    call s:VimuxTmux('select-pane -T '.targetName)
  endif
endfunction

function! s:VimuxTmuxProperty(property)
  return substitute(s:VimuxTmux("display -p '".a:property."'"), '\n$', '', '')
endfunction

function! s:VimuxHasRunner(index)
  let t = g:VimuxRunnerType
  return match(s:VimuxTmux('list-'.t."s -F '#{".t."_id}'"), a:index)
endfunction
