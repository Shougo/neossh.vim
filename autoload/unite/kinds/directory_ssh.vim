"=============================================================================
" FILE: directory_ssh.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu at gmail.com>
" License: MIT license
"=============================================================================

function! unite#kinds#directory_ssh#define() abort
  return s:kind
endfunction

let s:kind = {
      \ 'name' : 'directory/ssh',
      \ 'default_action' : 'narrow',
      \ 'action_table': {},
      \ 'parents': ['file/ssh'],
      \}
