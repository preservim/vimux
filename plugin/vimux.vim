if exists('g:loaded_vimux') || &compatible
  finish
endif
let g:loaded_vimux = 1

" Set up all global options with defaults right away, in one place
let g:VimuxDebug         = get(g:, 'VimuxDebug',         v:false)
let g:VimuxHeight        = get(g:, 'VimuxHeight',        '20%')
let g:VimuxOpenExtraArgs = get(g:, 'VimuxOpenExtraArgs', '')
let g:VimuxOrientation   = get(g:, 'VimuxOrientation',   'v')
let g:VimuxPromptString  = get(g:, 'VimuxPromptString',  'Command? ')
let g:VimuxResetSequence = get(g:, 'VimuxResetSequence', 'C-u')
let g:VimuxRunnerName    = get(g:, 'VimuxRunnerName',    '')
let g:VimuxRunnerType    = get(g:, 'VimuxRunnerType',    'pane')
let g:VimuxRunnerQuery   = get(g:, 'VimuxRunnerQuery',   {})
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

augroup VimuxAutocmds
  au!
  autocmd VimLeave * call s:autoclose()
augroup END

function! VimuxRunCommandInDir(command, useFile) abort
  let l:file = ''
  if a:useFile ==# 1
    let l:file = shellescape(expand('%:t'), 1)
  endif
  call VimuxRunCommand('(cd '.shellescape(expand('%:p:h'), 1).' && '.a:command.' '.l:file.')')
endfunction

function! VimuxRunLastCommand() abort
  if exists('g:VimuxLastCommand')
    call VimuxRunCommand(g:VimuxLastCommand)
  else
    echo 'No last vimux command.'
  endif
endfunction

function! VimuxRunCommand(command, ...) abort
  call VimuxOpenRunner()
  let l:autoreturn = 1
  if exists('a:1')
    let l:autoreturn = a:1
  endif
  let l:resetSequence = VimuxOption('VimuxResetSequence')
  let g:VimuxLastCommand = a:command

  call s:exitCopyMode()
  call s:sendKeys(l:resetSequence)
  call s:sendText(a:command)
  if l:autoreturn ==# 1
    call s:sendKeys('Enter')
  endif
endfunction

function! VimuxSendText(text) abort
  if s:hasRunner()
    call s:sendText(a:text)
  else
    call s:echoNoRunner()
  endif
endfunction

function! VimuxSendKeys(keys) abort
  if s:hasRunner()
    call s:sendKeys(a:keys)
  else
    call s:echoNoRunner()
  endif
endfunction

function! VimuxOpenRunner() abort
  if s:hasRunner()
    return
  endif
  let existingId = s:existingRunnerId()
  if existingId !=# ''
    let g:VimuxRunnerIndex = existingId
  else
    let extraArguments = VimuxOption('VimuxOpenExtraArgs')
    if VimuxOption('VimuxRunnerType') ==# 'pane'
      call VimuxTmux('split-window '.s:vimuxPaneOptions().' '.extraArguments)
    elseif VimuxOption('VimuxRunnerType') ==# 'window'
      call VimuxTmux('new-window '.extraArguments)
    endif
    let g:VimuxRunnerIndex = s:tmuxIndex()
    call s:setRunnerName()
    call VimuxTmux('last-'.VimuxOption('VimuxRunnerType'))
  endif
endfunction

function! VimuxCloseRunner() abort
  if s:hasRunner()
    call VimuxTmux('kill-'.VimuxOption('VimuxRunnerType').' -t '.g:VimuxRunnerIndex)
  endif
  unlet! g:VimuxRunnerIndex
endfunction

function! VimuxTogglePane() abort
  if s:hasRunner()
    if VimuxOption('VimuxRunnerType') ==# 'window'
      call VimuxTmux('join-pane -s '.g:VimuxRunnerIndex.' '.s:vimuxPaneOptions())
      let g:VimuxRunnerType = 'pane'
      let g:VimuxRunnerIndex = s:tmuxIndex()
      call VimuxTmux('last-'.VimuxOption('VimuxRunnerType'))
    elseif VimuxOption('VimuxRunnerType') ==# 'pane'
      let g:VimuxRunnerIndex=substitute(
            \ VimuxTmux('break-pane -d -s '.g:VimuxRunnerIndex." -P -F '#{window_id}'"),
            \ '\n',
            \ '',
            \ ''
            \)
      let g:VimuxRunnerType = 'window'
    endif
  else
    call s:echoNoRunner()
  endif
endfunction

function! VimuxZoomRunner() abort
  if s:hasRunner()
    if VimuxOption('VimuxRunnerType') ==# 'pane'
      call VimuxTmux('resize-pane -Z -t '.g:VimuxRunnerIndex)
    elseif VimuxOption('VimuxRunnerType') ==# 'window'
      call VimuxTmux('select-window -t '.g:VimuxRunnerIndex)
    endif
  else
    call s:echoNoRunner()
  endif
endfunction

function! VimuxInspectRunner() abort
  if s:hasRunner()
    call VimuxTmux('select-'.VimuxOption('VimuxRunnerType').' -t '.g:VimuxRunnerIndex)
    call VimuxTmux('copy-mode')
    return v:true
  endif
  call s:echoNoRunner()
  return v:false
endfunction

function! VimuxScrollUpInspect() abort
  if VimuxInspectRunner()
    call VimuxTmux('last-'.VimuxOption('VimuxRunnerType'))
    call s:sendKeys('C-u')
  endif
endfunction

function! VimuxScrollDownInspect() abort
  if VimuxInspectRunner()
    call VimuxTmux('last-'.VimuxOption('VimuxRunnerType'))
    call s:sendKeys('C-d')
  endif
endfunction

function! VimuxInterruptRunner() abort
  if s:hasRunner()
    call s:sendKeys('^c')
  else
    call s:echoNoRunner()
  endif
endfunction

function! VimuxClearTerminalScreen() abort
  if s:hasRunner()
    call s:exitCopyMode()
    call s:sendKeys('C-l')
  else
    call s:echoNoRunner()
  endif
endfunction

function! VimuxClearRunnerHistory() abort
  if s:hasRunner()
    call VimuxTmux('clear-history -t '.g:VimuxRunnerIndex)
  else
    call s:echoNoRunner()
  endif
endfunction

function! VimuxPromptCommand(...) abort
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

function! VimuxTmux(arguments) abort
  let l:tmuxCommand = VimuxOption('VimuxTmuxCommand').' '.a:arguments
  if VimuxOption('VimuxDebug')
    echom l:tmuxCommand
  endif
  if has_key(environ(), 'TMUX')
    let l:output = system(l:tmuxCommand)
    if v:shell_error
      throw 'Tmux command failed with message:' . l:output
    endif
    return l:output
  else
    throw 'Aborting, because not inside tmux session.'
  endif
endfunction

function! s:exitCopyMode() abort
  try
    call VimuxTmux('copy-mode -q -t '.g:VimuxRunnerIndex)
  catch
    let l:versionString = s:tmuxProperty('#{version}')
    if str2float(l:versionString) < 3.2
      call s:sendKeys('q')
    endif
  endtry
endfunction

function! s:tmuxSession() abort
  return s:tmuxProperty('#S')
endfunction

function! s:tmuxIndex() abort
  if VimuxOption('VimuxRunnerType') ==# 'pane'
    return s:tmuxPaneId()
  else
    return s:tmuxWindowId()
  end
endfunction

function! s:tmuxPaneId() abort
  return s:tmuxProperty('#{pane_id}')
endfunction

function! s:tmuxWindowId() abort
  return s:tmuxProperty('#{window_id}')
endfunction

function! s:vimuxPaneOptions() abort
  let height = VimuxOption('VimuxHeight')
  let orientation = VimuxOption('VimuxOrientation')
  return '-l '.height.' -'.orientation
endfunction

""
" @return a string of the form '%4', the ID of the pane or window to use,
"   or '' if no nearest pane or window is found.
function! s:existingRunnerId() abort
  let runnerType = VimuxOption('VimuxRunnerType')
  let query = get(VimuxOption('VimuxRunnerQuery'), runnerType, '')
  if empty(query)
    if empty(VimuxOption('VimuxUseNearest'))
      return ''
    else
      return s:nearestRunnerId()
    endif
  endif
  " Try finding the runner using the provided query
  let currentId = s:tmuxIndex()
  let message = VimuxTmux('select-'.runnerType.' -t '.query.'')
  if message ==# ''
    " A match was found. Make sure it isn't the current vim pane/window
    " though!
    let runnerId = s:tmuxIndex()
    if runnerId !=# currentId
      " Success!
      call VimuxTmux('last-'.runnerType)
      return runnerId
    endif
  endif
  return ''
endfunction

function! s:nearestRunnerId() abort
  " Try finding the runner in the current window/session, optionally using a
  " name/title filter
  let runnerType = VimuxOption('VimuxRunnerType')
  let filter = s:getTargetFilter()
  let views = split(
        \ VimuxTmux(
        \     'list-'.runnerType.'s'
        \     ." -F '#{".runnerType.'_active}:#{'.runnerType."_id}'"
        \     .filter),
        \ '\n')
  " '1:' is the current active pane (the one with vim).
  " Find the first non-active pane.
  for view in views
    if match(view, '1:') ==# -1
      return split(view, ':')[1]
    endif
  endfor
  return ''
endfunction

function! s:getTargetFilter() abort
  let targetName = VimuxOption('VimuxRunnerName')
  if targetName ==# ''
    return ''
  endif
  let runnerType = VimuxOption('VimuxRunnerType')
  if runnerType ==# 'window'
    return " -f '#{==:#{window_name},".targetName."}'"
  elseif runnerType ==# 'pane'
    return " -f '#{==:#{pane_title},".targetName."}'"
  endif
endfunction

function! s:setRunnerName() abort
  let targetName = VimuxOption('VimuxRunnerName')
  if targetName ==# ''
    return
  endif
  let runnerType = VimuxOption('VimuxRunnerType')
  if runnerType ==# 'window'
    call VimuxTmux('rename-window '.targetName)
  elseif runnerType ==# 'pane'
    call VimuxTmux('select-pane -T '.targetName)
  endif
endfunction

function! s:tmuxProperty(property) abort
  return substitute(VimuxTmux("display -p '".a:property."'"), '\n$', '', '')
endfunction

function! s:hasRunner() abort
  if get(g:, 'VimuxRunnerIndex', '') ==? ''
    return v:false
  endif
  let l:runnerType = VimuxOption('VimuxRunnerType')
  let l:command = 'list-'.runnerType."s -F '#{".runnerType."_id}'"
  let l:found = match(VimuxTmux(l:command), g:VimuxRunnerIndex)
  return l:found != -1
endfunction

function! s:autoclose() abort
  if VimuxOption('VimuxCloseOnExit')
    call VimuxCloseRunner()
  endif
endfunction

function! s:sendKeys(keys) abort
  call VimuxTmux('send-keys -t '.g:VimuxRunnerIndex.' '.a:keys)
endfunction

function! s:sendText(text) abort
  call s:sendKeys(shellescape(substitute(a:text, '\n$', ' ', '')))
endfunction

function! s:echoNoRunner() abort
  echo 'No vimux runner pane/window. Create one with VimuxOpenRunner'
endfunction
