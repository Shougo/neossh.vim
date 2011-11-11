"=============================================================================
" FILE: file_ssh.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 11 Nov 2011.
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
if !exists('g:unite_kind_file_ssh_delete_file_command')
  if unite#util#is_win() && !executable('rm')
    " Can't support.
    let g:unite_kind_file_ssh_delete_file_command = ''
  else
    let g:unite_kind_file_ssh_delete_file_command = 'rm $srcs'
  endif
endif
if !exists('g:unite_kind_file_ssh_delete_file_command')
  if unite#util#is_win() && !executable('rm')
    " Can't support.
    let g:unite_kind_file_ssh_delete_file_command = ''
  else
    let g:unite_kind_file_ssh_delete_file_command = 'rm $srcs'
  endif
endif
if !exists('g:unite_kind_file_ssh_delete_directory_command')
  if unite#util#is_win() && !executable('rm')
    " Can't support.
    let g:unite_kind_file_ssh_delete_directory_command = ''
  else
    let g:unite_kind_file_ssh_delete_directory_command = 'rm -r $srcs'
  endif
endif
if !exists('g:unite_kind_file_ssh_copy_file_command')
  if unite#util#is_win() && !executable('cp')
    " Can't support.
    let g:unite_kind_file_ssh_copy_file_command = ''
  else
    let g:unite_kind_file_ssh_copy_file_command = 'cp -p $srcs $dest'
  endif
endif
if !exists('g:unite_kind_file_ssh_copy_directory_command')
  if unite#util#is_win() && !executable('cp')
    " Can't support.
    let g:unite_kind_file_ssh_copy_directory_command = ''
  else
    let g:unite_kind_file_ssh_copy_directory_command = 'cp -p -r $srcs $dest'
  endif
endif
if !exists('g:unite_kind_file_ssh_move_command')
  if unite#util#is_win() && !executable('mv')
    let g:unite_kind_file_ssh_move_command = 'move /Y $srcs $dest'
  else
    let g:unite_kind_file_ssh_move_command = 'mv $srcs $dest'
  endif
endif
"}}}

function! unite#kinds#file_ssh#define()"{{{
  return s:kind
endfunction"}}}

let s:System = vital#of('unite').import('System.File')

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
  let buflisted = buflisted(
        \ unite#util#escape_file_searching(
        \ a:candidate.action__path))
  if filereadable(a:candidate.action__path)
    call s:execute_command('pedit', a:candidate)
  endif

  if !buflisted
    call unite#add_previewed_buffer_list(
        \ bufnr(unite#util#escape_file_searching(
        \       a:candidate.action__path)))
  endif
endfunction"}}}

let s:kind.action_table.vimfiler__write = {
      \ 'description' : 'save file',
      \ }
function! s:kind.action_table.vimfiler__write.func(candidate)"{{{
  let context = unite#get_context()
  let lines = getline(context.vimfiler__line1, context.vimfiler__line2)

  if context.vimfiler__eventname ==# 'FileAppendCmd'
    " Append.
    let lines = readfile(a:candidate.action__path) + lines
  endif
  call writefile(lines, a:candidate.action__path)
endfunction"}}}
"}}}

function! s:execute_command(command, candidate)"{{{
  let dir = unite#util#path2directory(a:candidate.action__path)
  " Auto make directory.
  if !isdirectory(dir) && unite#util#input_yesno(
        \   printf('"%s" does not exist. Create?', dir))
    call mkdir(iconv(dir, &encoding, &termencoding), 'p')
  endif

  silent call unite#util#smart_execute_command(a:command, a:candidate.action__path)
endfunction"}}}
function! s:external(command, dest_dir, src_files)"{{{
  let dest_dir = a:dest_dir
  if dest_dir =~ '/$'
    " Delete last /.
    let dest_dir = dest_dir[: -2]
  endif

  let src_files = map(a:src_files, 'substitute(v:val, "/$", "", "")')
  let command_line = g:unite_kind_file_ssh_{a:command}_command

  " Substitute pattern.
  let command_line = substitute(command_line,
        \'\$srcs\>', join(map(src_files, '''"''.v:val.''"''')), 'g')
  let command_line = substitute(command_line,
        \'\$dest\>', '"'.dest_dir.'"', 'g')

  " echomsg command_line
  let output = unite#util#system(command_line)

  return unite#util#get_last_status()
endfunction"}}}

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: foldmethod=marker
