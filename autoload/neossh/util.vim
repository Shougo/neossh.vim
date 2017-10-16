"=============================================================================
" FILE: neossh.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu at gmail.com>
" License: MIT license
"=============================================================================

function! neossh#util#print_error(string) abort
  echohl Error | echomsg '[neossh] ' . a:string | echohl None
endfunction

function! neossh#util#set_default(var, val, ...) abort
  if !exists(a:var) || type({a:var}) != type(a:val)
    let alternate_var = get(a:000, 0, '')

    let {a:var} = exists(alternate_var) ?
          \ {alternate_var} : a:val
  endif
endfunction
