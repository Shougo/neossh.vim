"=============================================================================
" FILE: neossh.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
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

" Global options definition. "{{{
" External commands.
call neossh#util#set_default(
      \ 'g:neossh#ssh_command',
      \ 'ssh -p PORT HOSTNAME',
      \ 'g:unite_kind_file_ssh_command')
call neossh#util#set_default(
      \ 'g:neossh#list_command',
      \ 'ls -lFa',
      \ 'g:unite_kind_file_ssh_list_command')
call neossh#util#set_default(
      \ 'g:neossh#copy_directory_command',
      \ 'scp -P PORT -q -r $srcs $dest',
      \ 'g:unite_kind_file_ssh_copy_directory_command')
call neossh#util#set_default(
      \ 'g:neossh#copy_file_command',
      \ 'scp -P PORT -q $srcs $dest',
      \ 'g:unite_kind_file_ssh_copy_file_command')
call neossh#util#set_default(
      \ 'g:neossh#delete_file_command',
      \ 'rm $srcs',
      \ 'g:unite_kind_file_ssh_delete_file_command')
call neossh#util#set_default(
      \ 'g:neossh#delete_directory_command',
      \ 'rm -r $srcs',
      \ 'g:unite_kind_file_ssh_delete_directory_command')
call neossh#util#set_default(
      \ 'g:neossh#move_command',
      \ 'mv $srcs $dest',
      \ 'g:unite_kind_file_ssh_move_command')
call neossh#util#set_default(
      \ 'g:neossh#mkdir_command',
      \ 'mkdir $dest',
      \ 'g:unite_kind_file_ssh_mkdir_command')
call neossh#util#set_default(
      \ 'g:neossh#newfile_command',
      \ 'touch $dest',
      \ 'g:unite_kind_file_ssh_newfile_command')
"}}}

function! neossh#initialize() "{{{
  " Dummy
endfunction"}}}

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: foldmethod=marker
