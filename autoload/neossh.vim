"=============================================================================
" FILE: neossh.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu at gmail.com>
" License: MIT license
"=============================================================================

" Global options definition.
call neossh#util#set_default(
      \ 'g:neossh#ssh_config',
      \ '~/.ssh/config')

if !filereadable(expand(g:neossh#ssh_config))
  call neossh#util#print_error(g:neossh#ssh_config . ' is required.')
endif

" External commands.
call neossh#util#set_default(
      \ 'g:neossh#ssh_command',
      \ 'ssh -F '.g:neossh#ssh_config.' -p PORT HOSTNAME',
      \ 'g:unite_kind_file_ssh_command')
call neossh#util#set_default(
      \ 'g:neossh#list_command',
      \ 'ls -lFa',
      \ 'g:unite_kind_file_ssh_list_command')
call neossh#util#set_default(
      \ 'g:neossh#copy_directory_command',
      \ 'scp -F '.g:neossh#ssh_config.' -P PORT -q -r $srcs $dest',
      \ 'g:unite_kind_file_ssh_copy_directory_command')
call neossh#util#set_default(
      \ 'g:neossh#copy_file_command',
      \ 'scp -F '.g:neossh#ssh_config.' -P PORT -q $srcs $dest',
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


function! neossh#initialize() abort
  " Dummy
endfunction
