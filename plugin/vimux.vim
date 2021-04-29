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
let g:VimuxExpandCommand = get(g:, 'VimuxExpandCommand', v:false)
let g:VimuxCloseOnExit   = get(g:, 'VimuxCloseOnExit',   v:false)
let g:VimuxCommandShell  = get(g:, 'VimuxCommandShell',   v:true)

function! VimuxOption(name) abort
  return get(b:, a:name, get(g:, a:name))
endfunction

if !executable(VimuxOption('VimuxTmuxCommand'))
  echohl ErrorMsg | echomsg 'Failed to find executable '.VimuxOption('VimuxTmuxCommand') | echohl None
  finish
endif

command -nargs=* VimuxRunCommand :call VimuxRunCommand(<args>)
command -bar VimuxRunLastCommand :call VimuxRunLastCommand()
command -bar VimuxOpenRunner :call VimuxOpenRunner()
command -bar VimuxCloseRunner :call VimuxCloseRunner()
command -bar VimuxZoomRunner :call VimuxZoomRunner()
command -bar VimuxInspectRunner :call VimuxInspectRunner()
command -bar VimuxScrollUpInspect :call VimuxScrollUpInspect()
command -bar VimuxScrollDownInspect :call VimuxScrollDownInspect()
command -bar VimuxInterruptRunner :call VimuxInterruptRunner()
command -nargs=? VimuxPromptCommand :call VimuxPromptCommand(<args>)
command -bar VimuxClearTerminalScreen :call VimuxClearTerminalScreen()
command -bar VimuxClearRunnerHistory :call VimuxClearRunnerHistory()
command -bar VimuxTogglePane :call VimuxTogglePane()

if VimuxOption('VimuxCloseOnExit')
    augroup VimuxAutocloseCommands
        au!
        autocmd VimLeave * call VimuxCloseRunner()
    augroup END
endif

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
  let resetSequence = VimuxOption('VimuxResetSequence')
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
  if VimuxOption('VimuxUseNearest') ==# 1 && nearestIndex != -1
    let g:VimuxRunnerIndex = nearestIndex
  else
    let extraArguments = VimuxOption('VimuxOpenExtraArgs')
    if VimuxOption('VimuxRunnerType') ==# 'pane'
      let height = VimuxOption('VimuxHeight')
      let orientation = VimuxOption('VimuxOrientation')
      call VimuxTmux('split-window -p '.height.' -'.orientation.' '.extraArguments)
    elseif VimuxOption('VimuxRunnerType') ==# 'window'
      call VimuxTmux('new-window '.extraArguments)
    endif
    let g:VimuxRunnerIndex = s:tmuxIndex()
    call s:setRunnerName()
    call VimuxTmux('last-'.VimuxOption('VimuxRunnerType'))
  endif
endfunction

function! VimuxCloseRunner()
  if exists('g:VimuxRunnerIndex')
    call VimuxTmux('kill-'.VimuxOption('VimuxRunnerType').' -t '.g:VimuxRunnerIndex)
    unlet g:VimuxRunnerIndex
  endif
endfunction

function! VimuxTogglePane()
  if exists('g:VimuxRunnerIndex')
    if VimuxOption('VimuxRunnerType') ==# 'window'
      call VimuxTmux('join-pane -s '.g:VimuxRunnerIndex.' -p '.VimuxOption('VimuxHeight'))
      let g:VimuxRunnerType = 'pane'
      let g:VimuxRunnerIndex = s:tmuxIndex()
      call VimuxTmux('last-'.VimuxOption('VimuxRunnerType'))
    elseif VimuxOption('VimuxRunnerType') ==# 'pane'
      let g:VimuxRunnerIndex=substitute(VimuxTmux('break-pane -d -s '.g:VimuxRunnerIndex." -P -F '#{window_id}'"), '\n', '', '')
      let g:VimuxRunnerType = 'window'
    endif
  endif
endfunction

function! VimuxZoomRunner()
  if exists('g:VimuxRunnerIndex')
    if VimuxOption('VimuxRunnerType') ==# 'pane'
      call VimuxTmux('resize-pane -Z -t '.g:VimuxRunnerIndex)
    elseif VimuxOption('VimuxRunnerType') ==# 'window'
      call VimuxTmux('select-window -t '.g:VimuxRunnerIndex)
    endif
  endif
endfunction

function! VimuxInspectRunner()
  call VimuxTmux('select-'.VimuxOption('VimuxRunnerType').' -t '.g:VimuxRunnerIndex)
  call VimuxTmux('copy-mode')
endfunction

function! VimuxScrollUpInspect()
  call VimuxInspectRunner()
  call VimuxTmux('last-'.VimuxOption('VimuxRunnerType'))
  call VimuxSendKeys('C-u')
endfunction

function! VimuxScrollDownInspect()
  call VimuxInspectRunner()
  call VimuxTmux('last-'.VimuxOption('VimuxRunnerType'))
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
  if VimuxOption('VimuxCommandShell')
    let l:command = input(VimuxOption('VimuxPromptString'), command, 'shellcmd')
  else
    let l:command = input(VimuxOption('VimuxPromptString'), command)
  endif
  if VimuxOption('VimuxExpandCommand')
    let l:command = join(map(split(l:command, ' '), 'expand(v:val)'), ' ')
  endif
  call VimuxRunCommand(l:command)
endfunction

function! VimuxTmux(arguments)
  if VimuxOption('VimuxDebug')
    echom VimuxOption('VimuxTmuxCommand').' '.a:arguments
  endif
  return system(VimuxOption('VimuxTmuxCommand').' '.a:arguments)
endfunction

function! s:tmuxSession()
  return s:tmuxProperty('#S')
endfunction

function! s:tmuxIndex()
  if VimuxOption('VimuxRunnerType') ==# 'pane'
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
  let t = VimuxOption('VimuxRunnerType')
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
  let targetName = VimuxOption('VimuxRunnerName')
  if targetName ==# ''
    return ''
  endif
  let t = VimuxOption('VimuxRunnerType')
  if t ==# 'window'
    return " -f '#{==:#{window_name},".targetName."}'"
  elseif t ==# 'pane'
    return " -f '#{==:#{pane_title},".targetName."}'"
  endif
endfunction

function! s:setRunnerName()
  let targetName = VimuxOption('VimuxRunnerName')
  if targetName ==# ''
    return
  endif
  let t = VimuxOption('VimuxRunnerType')
  if t ==# 'window'
    call VimuxTmux('rename-window '.targetName)
  elseif t ==# 'pane'
    call VimuxTmux('select-pane -T '.targetName)
  endif
endfunction

function! s:tmuxProperty(property)
  return substitute(VimuxTmux("display -p '".a:property."'"), '\n$', '', '')
endfunction

function! s:hasRunner(index)
  let t = VimuxOption('VimuxRunnerType')
  return match(VimuxTmux('list-'.t."s -F '#{".t."_id}'"), a:index)
endfunction
