"=============================================================================
" FILE: file_ssh.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu@gmail.com>
" License: MIT license  {{{
"     Permission is hereby granted, free of charge, to any person obtaining
"     a copy of this software and associated documentation files (the
"     "Software"), to deal in the Software without restriction, including
"     without limitation the rights to use, copy, modify, merge, publish,
"     distribute, sublicense, and/or sell copies of the Software, and to
"     permit persons to whom the Software is furnished to do so, subject to
"     the following conditions:
"
"     The above copyright notice and this permission notice shall be included
"     in all copies or substantial portions of the Software.
"
"     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
"     OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
"     MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
"     IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
"     CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
"     TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
"     SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
" }}}
"=============================================================================

let s:save_cpo = &cpo
set cpo&vim

let s:System = unite#util#get_vital().import('System.File')

call neossh#initialize()

function! unite#kinds#file_ssh#initialize() "{{{
endfunction"}}}

function! unite#kinds#file_ssh#define() "{{{
  return s:kind
endfunction"}}}

let s:System = vital#of('unite').import('System.File')

let s:kind = {
      \ 'name' : 'file/ssh',
      \ 'default_action' : 'open',
      \ 'action_table' : {},
      \ 'parents' : ['openable', 'uri'],
      \}

" Actions "{{{
let s:kind.action_table.open = {
      \ 'description' : 'open files',
      \ 'is_selectable' : 1,
      \ }
function! s:kind.action_table.open.func(candidates) "{{{
  if !get(g:, 'vimfiler_as_default_explorer', 0)
    call unite#print_error(
          \ "vimfiler is not loaded or default explorer.")
    call unite#print_error(
          \ "You must enable vimfiler and set g:vimfiler_as_default_explorer is 1.")
    return
  endif

  for candidate in a:candidates
    call s:execute_command('edit', candidate)

    call unite#remove_previewed_buffer_list(
          \ bufnr(unite#util#escape_file_searching(
          \       candidate.action__path)))
  endfor
endfunction"}}}

let s:kind.action_table.preview = {
      \ 'description' : 'preview file',
      \ 'is_quit' : 0,
      \ }
function! s:kind.action_table.preview.func(candidate) "{{{
  if !get(g:, 'vimfiler_as_default_explorer', 0)
    call unite#print_error("vimfiler is not default explorer.")
    call unite#print_error("Please set g:vimfiler_as_default_explorer is 1.")
    return
  endif

  call s:execute_command('pedit', a:candidate)
endfunction"}}}

let s:kind.action_table.cd = {
      \ 'description' : 'change vimfiler current directory',
      \ }
function! s:kind.action_table.cd.func(candidate) "{{{
  if &filetype ==# 'vimfiler'
    call vimfiler#mappings#cd(a:candidate.action__directory)
    call s:move_vimfiler_cursor(a:candidate)
  endif
endfunction"}}}

let s:kind.action_table.lcd = {
      \ 'description' : 'change vimfiler current directory',
      \ }
function! s:kind.action_table.lcd.func(candidate) "{{{
  if &filetype ==# 'vimfiler'
    call vimfiler#mappings#cd(a:candidate.action__directory)
    call s:move_vimfiler_cursor(a:candidate)
  endif
endfunction"}}}

let s:kind.action_table.narrow = {
      \ 'description' : 'narrowing candidates by directory name',
      \ 'is_quit' : 0,
      \ 'is_start' : 1,
      \ }
function! s:kind.action_table.narrow.func(candidate) "{{{
  call unite#start_temporary(
        \ [['ssh', a:candidate.action__directory]])
endfunction"}}}

let s:kind.action_table.vimfiler__write = {
      \ 'description' : 'save file',
      \ }
function! s:kind.action_table.vimfiler__write.func(candidate) "{{{
  let context = unite#get_context()
  let lines = split(unite#util#iconv(
        \ join(getline(context.vimfiler__line1, context.vimfiler__line2), "\n"),
        \ &encoding, &fileencoding), "\n")

  " Use temporary file.
  let tempname = tempname()

  call writefile(lines, tempname)

  let [port, path] =
        \ unite#sources#ssh#parse_action_path(a:candidate.action__path)

  if unite#kinds#file_ssh#external('copy_file', port, path,
        \ [unite#sources#ssh#tempname(tempname)])
    call unite#print_error(printf('Failed file "%s" copy : %s',
          \ path, unite#util#get_last_errmsg()))
    setlocal modified
  endif

  if filereadable(tempname)
    call delete(tempname)
  endif
endfunction"}}}

let s:kind.action_table.vimfiler__shell = {
      \ 'description' : 'popup shell',
      \ 'is_listed' : 0,
      \ }
function! s:kind.action_table.vimfiler__shell.func(candidate) "{{{
  let vimfiler_current_dir = get(unite#get_context(),
        \  'vimfiler__current_directory', '')
  if vimfiler_current_dir =~ '/$'
    let vimfiler_current_dir = vimfiler_current_dir[: -2]
  endif

  if !exists(':VimShellInteractive')
    return
  endif

  let [hostname, port, path] =
        \ unite#sources#ssh#parse_path(
        \     vimfiler_current_dir)
  let command_line = unite#sources#ssh#substitute_command(
        \ g:neossh#ssh_command, hostname, port)
  execute 'VimShellInteractive' command_line

  " Change directory.
  call setline(line('.'),
        \ printf('%s cd %s', getline('.'), escape(path, '\ ')))
  call vimshell#execute_current_line(1)

  let files = get(unite#get_context(), 'vimfiler__files', [])
  if !empty(files)
    call setline(line('.'), getline('.') . ' ' . join(files))
    call cursor(0, col('.')+1)
  endif
endfunction"}}}

let s:kind.action_table.vimfiler__shellcmd = {
      \ 'description' : 'execute shell command',
      \ 'is_listed' : 0,
      \ }
function! s:kind.action_table.vimfiler__shellcmd.func(candidate) "{{{
  let vimfiler_current_dir =
        \ get(unite#get_context(), 'vimfiler__current_directory', '')

  let [hostname, port, path] =
        \ unite#sources#ssh#parse_path(vimfiler_current_dir)
  let command_line = printf('cd %s && %s', string(path),
        \ unite#get_context().vimfiler__command)

  let [status, out] = unite#sources#ssh#ssh_command(
        \ command_line, hostname, port, '')
  if g:unite_source_ssh_enable_debug
    echomsg out
  endif
  let output = split(out, '\n\|\r\n')

  if !empty(output)
    call unite#start([['output', output]])
  endif
  if status
    call unite#print_error(
          \ printf('Failed command_line "%s" : %s',
          \  command_line, unite#util#get_last_errmsg()))
  endif
endfunction"}}}

let s:kind.action_table.vimfiler__mkdir = {
      \ 'description' : 'make this directory and parents directory',
      \ 'is_quit' : 0,
      \ 'is_invalidate_cache' : 1,
      \ 'is_listed' : 0,
      \ 'is_selectable' : 1,
      \ }
function! s:kind.action_table.vimfiler__mkdir.func(candidates) "{{{
  let context = unite#get_context()
  let vimfiler_current_dir =
        \ get(context, 'vimfiler__current_directory', '')
  if vimfiler_current_dir !~ '/$'
    let vimfiler_current_dir .= '/'
  endif

  let dirname = input('New directory name: ',
        \ vimfiler_current_dir,
        \ 'customlist,unite#sources#ssh#complete_directory')

  if dirname == ''
    redraw
    echo 'Canceled.'
    return
  endif

  let [hostname, port, path] =
        \ unite#sources#ssh#parse_path(dirname)
  let command_line = unite#kinds#file_ssh#substitute_command(
        \ 'mkdir', port, path, [])
  let [status, output] = unite#sources#ssh#ssh_command(
        \ command_line, hostname, port, '')
  if status
    call unite#print_error(printf('Failed mkdir "%s" : %s',
          \ path, unite#util#get_last_errmsg()))
    return
  endif

  " Move marked files.
  if !get(context, 'vimfiler__is_dummy', 1)
    call unite#sources#ssh#move_files(dirname, a:candidates)
  endif
endfunction"}}}

let s:kind.action_table.vimfiler__newfile = {
      \ 'description' : 'make this file',
      \ 'is_quit' : 1,
      \ 'is_invalidate_cache' : 1,
      \ 'is_listed' : 0,
      \ }
function! s:kind.action_table.vimfiler__newfile.func(candidate) "{{{
  let vimfiler_current_dir =
        \ get(unite#get_context(), 'vimfiler__current_directory', '')
  if vimfiler_current_dir !~ '/$'
    let vimfiler_current_dir .= '/'
  endif

  let filename = input('New files name: ',
        \            vimfiler_current_dir,
        \            'customlist,unite#sources#ssh#complete_file')
  if filename == ''
    redraw
    echo 'Canceled.'
    return
  endif

  let [hostname, port, path] =
        \ unite#sources#ssh#parse_path(filename)
  let command_line = unite#kinds#file_ssh#substitute_command(
        \ 'newfile', port, path, [])
  let [status, output] = unite#sources#ssh#ssh_command(
        \ command_line, hostname, port, '')
  if status
    call unite#print_error(printf('Failed newfile "%s" : %s',
          \ path, unite#util#get_last_errmsg()))
    return
  endif

  let [hostname, port, path] =
        \ unite#sources#ssh#parse_path(filename)
  let file = unite#sources#ssh#create_file_dict(
        \ fnamemodify(path, ':t'),
        \ printf('%s:%d/%s', hostname, port, path), hostname)
  let file.source = 'ssh'

  call unite#mappings#do_action(
        \ vimfiler#get_context().edit_action, [file])
endfunction"}}}

let s:kind.action_table.vimfiler__delete = {
      \ 'description' : 'delete files',
      \ 'is_quit' : 0,
      \ 'is_invalidate_cache' : 1,
      \ 'is_selectable' : 1,
      \ 'is_listed' : 0,
      \ }
function! s:kind.action_table.vimfiler__delete.func(candidates) "{{{
  if !unite#util#input_yesno('Really force delete files?')
    echo 'Canceled.'
    return
  endif

  call unite#sources#ssh#delete_files(a:candidates)
endfunction"}}}

let s:kind.action_table.vimfiler__rename = {
      \ 'description' : 'rename files',
      \ 'is_quit' : 0,
      \ 'is_invalidate_cache' : 1,
      \ 'is_listed' : 0,
      \ }
function! s:kind.action_table.vimfiler__rename.func(candidate) "{{{
  let vimfiler_current_dir =
        \ get(unite#get_context(), 'vimfiler__current_directory', '')

  let context = unite#get_context()
  let filename = has_key(context, 'action__filename') ?
        \ context.action__filename :
        \ input(printf('New file name: %s -> ',
        \       a:candidate.action__path), a:candidate.action__path,
        \       'customlist,unite#sources#ssh#complete_file')
  redraw

  if filename == ''
    return
  endif

  let [hostname, port, src_path] =
        \ unite#sources#ssh#parse_path(a:candidate.action__path)
  let [hostname, port, dest_path] =
        \ unite#sources#ssh#parse_path(filename)
  let command_line = unite#kinds#file_ssh#substitute_command(
        \ 'move', port, dest_path, [src_path])

  let [status, output] = unite#sources#ssh#ssh_command(
        \ command_line, hostname, port, '')
  if status
    call unite#print_error(printf('Failed move "%s" : %s',
          \ path, unite#util#get_last_errmsg()))
  endif
endfunction"}}}

let s:kind.action_table.vimfiler__copy = {
      \ 'description' : 'copy files',
      \ 'is_quit' : 0,
      \ 'is_invalidate_cache' : 1,
      \ 'is_selectable' : 1,
      \ 'is_listed' : 0,
      \ }
function! s:kind.action_table.vimfiler__copy.func(candidates) "{{{
  let vimfiler_current_dir =
        \ get(unite#get_context(), 'vimfiler__current_directory', '')

  let context = unite#get_context()
  let dest_dir = has_key(context, 'action__directory')
        \ && context.action__directory != '' ?
        \   context.action__directory :
        \   input('Input destination directory: ', vimfiler_current_dir,
        \     'customlist,unite#sources#ssh#complete_directory')
  redraw

  if dest_dir == ''
    echo 'Canceled.'
    return
  endif
  if dest_dir !~ '/$'
    let dest_dir .= '/'
  endif
  let context.action__directory = dest_dir

  call unite#sources#ssh#copy_files(dest_dir, a:candidates)
endfunction"}}}

let s:kind.action_table.vimfiler__move = {
      \ 'description' : 'move files',
      \ 'is_quit' : 0,
      \ 'is_invalidate_cache' : 1,
      \ 'is_selectable' : 1,
      \ 'is_listed' : 0,
      \ }
function! s:kind.action_table.vimfiler__move.func(candidates) "{{{
  if !unite#util#input_yesno('Really move files?')
    echo 'Canceled.'
    return
  endif

  let vimfiler_current_dir =
        \ get(unite#get_context(), 'vimfiler__current_directory', '')

  let context = unite#get_context()
  let dest_dir = has_key(context, 'action__directory')
        \ && context.action__directory != '' ?
        \   context.action__directory :
        \   input('Input destination directory: ', vimfiler_current_dir,
        \     'customlist,unite#sources#ssh#complete_directory')
  redraw

  if dest_dir == ''
    echo 'Canceled.'
    return
  endif
  if dest_dir !~ '/$'
    let dest_dir .= '/'
  endif
  let context.action__directory = dest_dir

  call unite#sources#ssh#move_files(dest_dir, a:candidates)
endfunction"}}}

let s:kind.action_table.vimfiler__execute = {
      \ 'description' : 'open files with associated program in local',
      \ 'is_selectable' : 1,
      \ 'is_listed' : 0,
      \ }
function! s:kind.action_table.vimfiler__execute.func(candidates) "{{{
  " Print error if they are directory.
  if !empty(filter(copy(a:candidates),
        \ 'v:val.vimfiler__is_directory'))
    call unite#print_error('You cannot execute directory.')
    return
  endif

  if !unite#util#input_yesno('Really want to execute files in local?')
    echo 'Canceled.'
    return
  endif

  for candidate in a:candidates
    let dest_path = tempname() . (fnamemodify(candidate.action__path, ':e') != '' ?
          \ '.' . fnamemodify(candidate.action__path, ':e') : '')

    let [hostname, port, src_path] =
          \ unite#sources#ssh#parse_path(candidate.action__path)
    let src_path = hostname.':'.src_path
    if unite#kinds#file_ssh#external('copy_directory',
          \ port, dest_path, [src_path])
      call unite#print_error(printf('Failed copy "%s" to "%s" : %s',
            \ src_path, dest_path, unite#util#get_last_errmsg()))
    endif

    call s:System.open(dest_path)
  endfor
endfunction"}}}

"}}}

function! s:execute_command(command, candidate) "{{{
  call unite#util#smart_execute_command(a:command,
        \ a:candidate.action__path)
endfunction"}}}
function! s:move_vimfiler_cursor(candidate) "{{{
  if &filetype !=# 'vimfiler'
    return
  endif

  if has_key(a:candidate, 'action__path')
        \ && a:candidate.action__directory !=# a:candidate.action__path
    " Move cursor.
    call vimfiler#mappings#search_cursor(a:candidate.action__path)
  endif
endfunction"}}}

function! unite#kinds#file_ssh#external(command, port, dest_dir, src_files) "{{{
  let command_line = unite#kinds#file_ssh#substitute_command(
        \ a:command, a:port, a:dest_dir, a:src_files)

  let output = unite#sources#ssh#system_passwd(command_line)
  if g:unite_source_ssh_enable_debug
    echomsg 'command_line = ' . command_line
    echomsg 'output = ' . output
  endif
  let status = unite#util#get_last_status()
  if status && g:unite_source_ssh_enable_debug
    call unite#print_error(printf('Failed command_line "%s"', command_line))
    echomsg command_line
  endif

  return status
endfunction"}}}
function! unite#kinds#file_ssh#substitute_command(command, port, dest_dir, src_files) "{{{
  let dest_dir = a:dest_dir
  if dest_dir =~ '/$'
    " Delete last /.
    let dest_dir = dest_dir[: -2]
  endif

  let src_files = map(a:src_files, 'substitute(v:val, "/$", "", "")')
  let command_line = unite#sources#ssh#substitute_command(
        \ g:neossh#{a:command}_command, '', a:port)

  " Substitute pattern.
  let command_line = substitute(command_line,
        \'\$srcs\>', join(map(src_files, '''"''.v:val.''"''')), 'g')
  let command_line = substitute(command_line,
        \'\$dest\>', '"'.dest_dir.'"', 'g')

  return command_line
endfunction"}}}

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: foldmethod=marker
