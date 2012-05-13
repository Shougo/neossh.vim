"=============================================================================
" FILE: file_ssh.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 13 May 2012.
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

" Global options definition."{{{
" External commands.
call unite#util#set_default(
      \ 'g:unite_kind_file_ssh_command',
      \ 'ssh -p PORT')
call unite#util#set_default(
      \ 'g:unite_kind_file_ssh_list_command',
      \ 'HOSTNAME ls -Fa1')
      " \ 'HOSTNAME ls -Loa')
call unite#util#set_default(
      \ 'g:unite_kind_file_ssh_copy_directory_command',
      \ 'scp -P PORT -q -r $srcs $dest')
call unite#util#set_default(
      \ 'g:unite_kind_file_ssh_copy_file_command',
      \ 'scp -P PORT -q $srcs $dest')
call unite#util#set_default(
      \ 'g:unite_kind_file_ssh_delete_file_command',
      \ 'ssh -p PORT rm $srcs')
call unite#util#set_default(
      \ 'g:unite_kind_file_ssh_delete_directory_command',
      \ 'ssh -p PORT rm -r $srcs')
call unite#util#set_default(
      \ 'g:unite_kind_file_ssh_delete_directory_command',
      \ 'ssh -p PORT mv $srcs $dest')
call unite#util#set_default(
      \ 'g:unite_kind_file_ssh_mkdir_command',
      \ 'ssh -p PORT mkdir $dest')
call unite#util#set_default(
      \ 'g:unite_kind_file_ssh_newfile_command',
      \ 'ssh -p PORT touch $dest')
"}}}

function! unite#kinds#file_ssh#initialize()"{{{
endfunction"}}}

function! unite#kinds#file_ssh#define()"{{{
  return s:kind
endfunction"}}}

let s:System = vital#of('unite.vim').import('System.File')

let s:kind = {
      \ 'name' : 'file/ssh',
      \ 'default_action' : 'open',
      \ 'action_table' : {},
      \ 'parents' : ['openable', 'cdable', 'uri'],
      \}

" Actions"{{{
let s:kind.action_table.open = {
      \ 'description' : 'open files',
      \ 'is_selectable' : 1,
      \ }
function! s:kind.action_table.open.func(candidates)"{{{
  if !get(g:, 'vimfiler_as_default_explorer', 0)
    call unite#print_error("vimshell is not default explorer.")
    call unite#print_error("Please set g:vimfiler_as_default_explorer is 1.")
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
function! s:kind.action_table.preview.func(candidate)"{{{
  if !get(g:, 'vimfiler_as_default_explorer', 0)
    call unite#print_error("vimshell is not default explorer.")
    call unite#print_error("Please set g:vimfiler_as_default_explorer is 1.")
    return
  endif

  let path = candidate.action__path

  let buflisted = buflisted(
        \ unite#util#escape_file_searching(path))
  if filereadable(a:candidate.action__path)
    call s:execute_command('pedit', a:candidate)
  endif

  if !buflisted
    call unite#add_previewed_buffer_list(
        \ bufnr(unite#util#escape_file_searching(path)))
  endif
endfunction"}}}

let s:kind.action_table.vimfiler__write = {
      \ 'description' : 'save file',
      \ }
function! s:kind.action_table.vimfiler__write.func(candidate)"{{{
  let context = unite#get_context()
  let lines = getline(context.vimfiler__line1, context.vimfiler__line2)

  " Use temporary file.
  let tempname = tempname()

  call writefile(map(lines,
        \ "iconv(v:val, &encoding, &fileencoding)"), tempname)

  let [port, path] =
        \ unite#sources#ssh#parse_action_path(a:candidate.action__path)

  if unite#kinds#file_ssh#external('copy_file', port, path, [tempname])
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
function! s:kind.action_table.vimfiler__shell.func(candidate)"{{{
  let vimfiler_current_dir =
        \ get(unite#get_context(), 'vimfiler__current_directory', '')
  if vimfiler_current_dir =~ '/$'
    let vimfiler_current_dir = vimfiler_current_dir[: -2]
  endif

  if !exists(':VimShellInteractive')
    return
  endif

  VimShellInteractive
        \ `=g:unite_kind_file_ssh_command.' '.vimfiler_current_dir`
endfunction"}}}

let s:kind.action_table.vimfiler__shellcmd = {
      \ 'description' : 'execute shell command',
      \ 'is_listed' : 0,
      \ }
function! s:kind.action_table.vimfiler__shellcmd.func(candidate)"{{{
  let vimfiler_current_dir =
        \ get(unite#get_context(), 'vimfiler__current_directory', '')

  let command_line = unite#get_context().vimfiler__command
  echo unite#sources#ssh#system_passwd(command_line)

  let status = unite#util#get_last_status()
  if status
    call unite#print_error(
          \ printf('Failed command_line "%s"', command_line))
    echomsg command_line
  endif
endfunction"}}}

let s:kind.action_table.vimfiler__mkdir = {
      \ 'description' : 'make this directory and parents directory',
      \ 'is_quit' : 0,
      \ 'is_invalidate_cache' : 1,
      \ 'is_listed' : 0,
      \ }
function! s:kind.action_table.vimfiler__mkdir.func(candidate)"{{{
  let vimfiler_current_dir =
        \ get(unite#get_context(), 'vimfiler__current_directory', '')

  let dirname = input('New directory name: ',
        \ vimfiler_current_dir . '/',
        \ 'unite#sources#ssh#command_complete_directory')

  if dirname == ''
    redraw
    echo 'Canceled.'
    return
  endif

  let [port, path] =
        \ unite#sources#ssh#parse_action_path(dirname)
  if unite#kinds#file_ssh#external('mkdir', port, path, [])
    call unite#print_error(printf('Failed mkdir "%s" : %s',
          \ path, unite#util#get_last_errmsg()))
  endif
endfunction"}}}

let s:kind.action_table.vimfiler__newfile = {
      \ 'description' : 'make this file',
      \ 'is_quit' : 1,
      \ 'is_invalidate_cache' : 1,
      \ 'is_listed' : 0,
      \ }
function! s:kind.action_table.vimfiler__newfile.func(candidate)"{{{
  let vimfiler_current_dir =
        \ get(unite#get_context(), 'vimfiler__current_directory', '')

  let filename = input('New files name: ',
        \            vimfiler_current_dir . '/',
        \            'unite#sources#ssh#command_complete_file')
  if filename == ''
    redraw
    echo 'Canceled.'
    return
  endif

  let [port, path] =
        \ unite#sources#ssh#parse_action_path(filename)
  if unite#kinds#file_ssh#external('newfile', port, path, [])
    call unite#print_error(printf('Failed newfile "%s" : %s',
          \ path, unite#util#get_last_errmsg()))
  endif

  let [hostname, port, path] =
        \ unite#sources#ssh#parse_path(filename)
  let file = unite#sources#ssh#create_file_dict(
        \ fnamemodify(path, ':t'),
        \ printf('%s:%d/%s', hostname, port, path), hostname)
  let file.source = 'ssh'

  call unite#mappings#do_action(g:vimfiler_edit_action, [file])
endfunction"}}}
let s:kind.action_table.vimfiler__delete = {
      \ 'description' : 'delete files',
      \ 'is_quit' : 0,
      \ 'is_invalidate_cache' : 1,
      \ 'is_selectable' : 1,
      \ 'is_listed' : 0,
      \ }
function! s:kind.action_table.vimfiler__delete.func(candidates)"{{{
  for candidate in a:candidates
    let [port, path] =
          \ unite#sources#ssh#parse_action_path(candidate.action__path)

    if unite#kinds#file_ssh#external('delete_directory',
          \ port, path, [])
      call unite#print_error(printf('Failed delete "%s" : %s',
            \ path, unite#util#get_last_errmsg()))
    endif
  endfor
endfunction"}}}

let s:kind.action_table.vimfiler__rename = {
      \ 'description' : 'rename files',
      \ 'is_quit' : 0,
      \ 'is_invalidate_cache' : 1,
      \ 'is_listed' : 0,
      \ }
function! s:kind.action_table.vimfiler__rename.func(candidate)"{{{
  let vimfiler_current_dir =
        \ get(unite#get_context(), 'vimfiler__current_directory', '')

  let context = unite#get_context()
  let filename = has_key(context, 'action__filename') ?
        \ context.action__filename :
        \ input(printf('New file name: %s -> ',
        \       a:candidate.action__path), a:candidate.action__path,
        \       'unite#sources#ssh#command_complete_file')
  redraw

  let [port, src_path] =
        \ unite#sources#ssh#parse_action_path(a:candidate.action__path)
  let [port, dest_path] =
        \ unite#sources#ssh#parse_action_path(filename)
  if unite#kinds#file_ssh#external('move',
        \ port, dest_path, [src_path])
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
function! s:kind.action_table.vimfiler__copy.func(candidates)"{{{
  let vimfiler_current_dir =
        \ get(unite#get_context(), 'vimfiler__current_directory', '')

  let context = unite#get_context()
  let dest_dir = has_key(context, 'action__directory')
        \ && context.action__directory != '' ?
        \   context.action__directory :
        \   input('Input destination directory: ', vimfiler_current_dir,
        \     'unite#sources#ssh#command_complete_directory')
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
function! s:kind.action_table.vimfiler__move.func(candidates)"{{{
  let vimfiler_current_dir =
        \ get(unite#get_context(), 'vimfiler__current_directory', '')

  let context = unite#get_context()
  let dest_dir = has_key(context, 'action__directory')
        \ && context.action__directory != '' ?
        \   context.action__directory :
        \   input('Input destination directory: ', vimfiler_current_dir,
        \     'unite#sources#ssh#command_complete_directory')
  if dest_dir !~ '/$'
    let dest_dir .= '/'
  endif
  let context.action__directory = dest_dir

  call unite#sources#ssh#move_files(dest_dir, a:candidates)
endfunction"}}}

"}}}

function! s:execute_command(command, candidate)"{{{
  call unite#util#smart_execute_command(a:command,
        \ a:candidate.action__path)
endfunction"}}}

function! unite#kinds#file_ssh#external(command, port, dest_dir, src_files)"{{{
  let dest_dir = a:dest_dir
  if dest_dir =~ '/$'
    " Delete last /.
    let dest_dir = dest_dir[: -2]
  endif

  let src_files = map(a:src_files, 'substitute(v:val, "/$", "", "")')
  let command_line = substitute(
        \ g:unite_kind_file_ssh_{a:command}_command,
        \ '\<PORT\>', a:port, 'g')

  " Substitute pattern.
  let command_line = substitute(command_line,
        \'\$srcs\>', join(map(src_files, '''"''.v:val.''"''')), 'g')
  let command_line = substitute(command_line,
        \'\$dest\>', '"'.dest_dir.'"', 'g')

  let output = unite#sources#ssh#system_passwd(command_line)
  let status = unite#util#get_last_status()
  if status
    call unite#print_error(printf('Failed command_line "%s"', command_line))
    echomsg command_line
  endif

  return status
endfunction"}}}

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: foldmethod=marker
