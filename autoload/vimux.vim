scriptencoding utf-8

" ==================================
" Default tasks.json file
let s:DefaultTasks='
\{
\  "tasks": [
\    {
\      "type": "shell",
\      "label": "Hello World",
\      "command": "echo Hello World!"
\    }
\  ]
\}'

" ==================================
" Load task files

function! s:LoadTasksJson() abort
  let tasksFile = '.vim/tasks.json'
  if filereadable(tasksFile)
    let json = readfile(tasksFile)
    let content = join(json, "\n")
    let tasks = json_decode(content)
    " TODO parse the json for valid content ?
    return tasks.tasks
  else
    return []
  endif
endfunction

function! s:LoadPackageJson() abort
  let json = readfile('package.json')
  if filereadable('yarn.lock')
    let node = 'yarn'
  else
    let node = 'npm'
  endif
  let content = join(json, "\n")
  let tasks = json_decode(content)

  let tasksArray = []
  for key in keys(tasks.scripts)
    let l:label = node . ': ' . key
    call add(tasksArray, {'label': l:label, 'command': node . ' run ' . key})
  endfor
  return tasksArray
endfunction

" ==================================
" Popup launcher

function! s:VimuxTasksSink(tasks, id, choice) abort
  if a:choice < 0 " cancel popup
    return
  endif
  call popup_hide(a:id)
  let task = get(a:tasks, a:choice - 1)
  VimuxRunCommand(task.command)
endfunction

function! s:VimuxTasksFilter(tasks, id, key) abort
  " TODO this only works from 0 to 9
  if a:key =~# '\d'
    call s:VimuxTasksSink(a:tasks, a:id, a:key)
  else " No shortcut, pass to generic filter
    return popup_filter_menu(a:id, a:key)
  endif
endfunction

function! s:RunTaskPopup(tasks) abort
  let taskArray = mapnew(a:tasks, {key, task -> (key + 1) . '. ' . task.label})
  call popup_menu(taskArray, {
        \ 'title': ' Run Task ',
        \ 'borderchars': ['─', '│', '─', '│', '╭', '╮', '╯', '╰'],
        \ 'callback': function('s:VimuxTasksSink', [a:tasks]),
        \ 'border': [],
        \ 'cursorline': 1,
        \ 'padding': [1,2,1,2],
        \ 'filter': function('s:VimuxTasksFilter', [a:tasks]),
        \ 'mapping': 0,
        \ })
endfunction

" ==================================
" FZF Popup function
function! Pad(s,amt) abort
    return a:s . repeat(' ',a:amt - len(a:s))
endfunction

function! s:VimuxTasksSinkFZF(tasks, selection) abort
  if match(a:selection,'>>>>') == 0
    let l:select = a:selection[5:]
    let l:action = 'type'
  else
    let l:select = a:selection
    let l:action = 'run'
  endif
  for task in a:tasks
    if task.label ==# l:select
      if l:action ==# 'run'
        call VimuxRunCommand(task.command)
      else
        call VimuxOpenRunner()
        call VimuxSendText(task.command . ' ')
        call VimuxTmux('select-'.VimuxOption('VimuxRunnerType').' -t '.g:VimuxRunnerIndex)
      endif
      break
    endif
  endfor
endfunction

function! s:RunTaskFZF(tasks) abort
    call fzf#run({
      \ 'source': mapnew(a:tasks, {key, task -> task.label}) ,
      \ 'sink': function('s:VimuxTasksSinkFZF', [a:tasks]),
      \ 'options': "--prompt 'Run Task > ' --no-info '--bind=ctrl-l:execute@printf \">>>> \"@+accept' --header ':: \e[1;33mEnter\e[m Run command. \e[1;33mctrl-l\e[m Type command'",
      \ 'tmux': '-p40%,30%'})
endfunction

" ==================================
" Main Popup function

function! vimux#RunTasks() abort
  let tasks = s:LoadTasksJson()
  if len(tasks) == 0
    let tasks = [{ 'label': 'Generate tasks file', 'command': "cat > .vim/tasks.json <<< '" . s:DefaultTasks . "'" }]
  endif
  if index(VimuxOption('VimuxTaskAutodetect'), 'package.json') >= 0 && filereadable('package.json')
    let packageTasks = s:LoadPackageJson()
    call extend(tasks, packageTasks)
  endif

  if VimuxOption('VimuxTasksSelect') ==# 'popup'
    call s:RunTaskPopup(tasks)
  elseif VimuxOption('VimuxTaksSelect') ==# 'tmux-fzf' && &runtimepath =~# 'fzf.vim' && glob('~/.vim/plugged/fzf.vim/plugin/fzf.vim') !=# ''
    call s:RunTaskFZF(tasks)
  else
    call s:RunTaskPopup(tasks)
  endif
endfunction
