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

function! s:LoadTasksJson()
  let tasksFile = ".vim/tasks.json"
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

function! s:LoadPackageJson()
  let json = readfile("package.json")
  if filereadable("yarn.lock")
    let node = "yarn"
  else
    let node = "npm"
  endif
  let content = join(json, "\n")
  let tasks = json_decode(content)

  let tasksArray = []
  for key in keys(tasks.scripts)
    call add(tasksArray, {"label": node .. ": " .. key, "command": node .. " run " .. key})
  endfor
  return tasksArray
endfunction

" ==================================
" Popup launcher

function! s:VimuxTasksSink(tasks, id, choice)
  if a:choice < 0 " cancel popup
    return
  endif
  call popup_hide(a:id)
  let task = get(a:tasks, a:choice - 1)
  VimuxRunCommand(task.command)
endfunction

function! s:VimuxTasksFilter(tasks, id, key)
  " TODO fix this temporary patch
  if a:key == '1' || a:key == '2' || a:key == '3' || a:key == '4' || a:key == '5'
    call s:VimuxTasksSink(a:tasks, a:id, a:key)
  else " No shortcut, pass to generic filter
    return popup_filter_menu(a:id, a:key)
  endif
endfunction

function! s:RunTaskPopup(tasks)
  let taskArray = mapnew(a:tasks, {key, task -> key .. '. ' .. task.label})
  call popup_menu(taskArray, #{
        \ title: ' Run Task ',
        \ borderchars: ['─', '│', '─', '│', '╭', '╮', '╯', '╰'],
        \ callback: function('s:VimuxTasksSink', [a:tasks]),
        \ border: [],
        \ cursorline: 1,
        \ padding: [1,2,1,2],
        \ filter: function('s:VimuxTasksFilter', [a:tasks]),
        \ mapping: 0,
        \ })
endfunction

" ==================================
" FZF Popup function
function! Pad(s,amt)
    return a:s . repeat(' ',a:amt - len(a:s))
endfunction

function! s:VimuxTasksSinkFZF(tasks, selection)
  for task in a:tasks
    if task.label == a:selection
      VimuxRunCommand(task.command)
      break
    endif
  endfor
endfunction

function! s:RunTaskFZF(tasks)
    call fzf#run({
      \ 'source': mapnew(a:tasks, {key, task -> task.label}) ,
      \ 'sink': function('s:VimuxTasksSinkFZF', [a:tasks]),
      \ 'options': "--prompt 'Run Task > ' --no-info",
      \ 'tmux': '-p40%,30%'})
endfunction

" ==================================
" Main Popup function

function! vimux#RunTasks()
  let tasks = s:LoadTasksJson()
  if len(tasks) == 0
    let tasks = [{ "label": "Generate tasks file", "command": "cat > .vim/tasks.json <<< '" .. s:DefaultTasks .. "'" }]
  endif
  " TODO if no tasks exist prompt to generate a new task file
  if index(VimuxOption('VimuxTaskAutodetect'), "package.json") >= 0 && filereadable("package.json")
    let packageTasks = s:LoadPackageJson()
    call extend(tasks, packageTasks)
  endif

  if VimuxOption('VimuxTasksSelect') == 'popup'
    call s:RunTaskPopup(tasks)
  elseif VimuxOption('VimuxTasksSelect') == 'tmux-fzf' && &rtp =~ 'fzf.vim' && glob("~/.vim/plugged/fzf.vim/plugin/fzf.vim")!=#""
    call s:RunTaskFZF(tasks)
  else
    call s:RunTaskPopup(tasks)
  endif
endfunction
