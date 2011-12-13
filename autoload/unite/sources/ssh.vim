"=============================================================================
" FILE: ssh.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 13 Dec 2011.
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

" Variables  "{{{
call unite#util#set_default('g:unite_source_file_ssh_ignore_pattern',
      \'^\%(/\|\a\+:/\)$\|\%(^\|/\)\.\.\?$\|\~$\|\.\%(o|exe|dll|bak|sw[po]\)$')
call unite#util#set_default('g:unite_kind_file_ssh_command',
      \'ssh')
call unite#util#set_default('g:unite_kind_file_ssh_list_command',
      \'HOSTNAME ls -Loa')
call unite#util#set_default('g:unite_kind_file_ssh_copy_directory_command',
      \'scp -r $srcs $dest')
call unite#util#set_default('g:unite_kind_file_ssh_copy_file_command',
      \'scp $srcs $dest')
"}}}

function! unite#sources#ssh#define()"{{{
  return s:source
endfunction"}}}

let s:source = {
      \ 'name' : 'ssh',
      \ 'description' : 'candidates from ssh',
      \}

function! s:source.change_candidates(args, context)"{{{
  if len(a:args) < 2
    " Options is omitted.
    let options = ''
    let path = get(a:args, 0, '')
  else
    let options = get(a:args, 0, '')
    let path = get(a:args, 1, '')
  endif
  let hostname = matchstr(path, '^[^/]*')
  let path = path[len(hostname)+1:]

  if hostname == ''
    " No hostname.
    return []
  endif

  if hostname =~ '/$'
    " Chomp.
    let hostname = hostname[ :-2]
  endif

  if !has_key(a:context, 'source__cache') || a:context.is_redraw
        \ || a:context.is_invalidate
    " Initialize cache.
    let a:context.source__cache = {}
  endif

  let is_vimfiler = get(a:context, 'is_vimfiler', 0)

  let input_list = filter(split(a:context.input,
        \                     '\\\@<! ', 1), 'v:val !~ "!"')
  let input = empty(input_list) ? '' : input_list[0]
  let input = substitute(substitute(a:context.input, '\\ ', ' ', 'g'), '^\a\+:\zs\*/', '/', '')

  if path !=# '/' && path =~ '[\\/]$'
    " Chomp.
    let path = path[: -2]
  endif

  if path == '/'
    let input = path . input
  elseif input !~ '^\%(/\|\a\+:/\)' && path != '' && path != '/'
    let input = path . '/' .  input
  endif

  " Substitute *. -> .* .
  let input = substitute(input, '\*\.', '.*', 'g')

  if input !~ '\*' && unite#is_win() && getftype(input) == 'link'
    " Resolve link.
    let input = resolve(input)
  endif

  " Glob by directory name.
  let input = substitute(input, '[^/.]*$', '', '')

  if input =~ '/$'
    let input = input[: -2]
  endif

  if !has_key(a:context.source__cache, input)
    let files = map(s:get_filenames(options, hostname, input),
          \ 'unite#sources#ssh#create_file_dict(v:val, hostname.input)')

    if !is_vimfiler
      if g:unite_source_file_ignore_pattern != ''
        call filter(files,
              \ 'v:val.action__path !~ '
              \  . string(g:unite_source_file_ignore_pattern))
      endif

      let files = sort(filter(copy(files),
            \  'v:val.vimfiler__is_directory'), 1) +
            \ sort(filter(copy(files),
            \  '!v:val.vimfiler__is_directory'), 1)
    endif

    let a:context.source__cache[input.'*'] = files
  endif

  let candidates = a:context.source__cache[input.'*']

  if a:context.input != '' && !is_vimfiler
    let newfile = substitute(a:context.input, '[*\\]', '', 'g')
    if !filereadable(newfile) && !isdirectory(newfile)
      " Add newfile candidate.
      let candidates = copy(candidates) +
            \ [unite#sources#ssh#create_file_dict(newfile, input, 1)]
    endif

    if input !~ '^\%(/\|\a\+:/\)$'
      let parent = substitute(input, '[*\\]\|\.[^/]*$', '', 'g')

      if a:context.input =~ '\.$' && isdirectory(parent . '..')
        " Add .. directory.
        let candidates = [unite#sources#ssh#create_file_dict(
              \              parent . '..', hostname.input)]
              \ + copy(candidates)
      endif
    endif
  endif

  return candidates
endfunction"}}}
function! s:source.vimfiler_check_filetype(args, context)"{{{
  if len(a:args) < 2
    " Options is omitted.
    let options = ''
    let path = get(a:args, 0, '')
  else
    let options = get(a:args, 0, '')
    let path = get(a:args, 1, '')
  endif
  let hostname = matchstr(path, '^[^/]*')
  let path = path[len(hostname)+1:]

  if hostname == ''
    " No hostname.
    return [ 'error', '[ssh] No hostname : ' ]
  endif

  let files = s:get_filenames(options, hostname, path)
  if empty(files)
    return [ 'error', '[ssh] Invalid path : ' . path ]
  endif

  if files[0] =~ '^d'
    let type = 'directory'
    let info = a:args[0]
  else
    let base = fnamemodify(path, ':h')
    if base == '.'
      let base = ''
    endif

    let type = 'file'

    " Use temporary file.
    let tempname = tempname()
    let dict = unite#sources#ssh#create_file_dict(files[0], hostname.base)
    if unite#kinds#file_ssh#external('copy_file', tempname,
          \ [ hostname . ':' . base . dict.word ], options)
      call unite#print_error(printf('Failed file copy %s',
            \ unite#util#get_last_errmsg()))
    endif
    let info = [readfile(tempname), dict]
    if filereadable(tempname)
      call delete(tempname)
    endif
  endif

  return [type, info]
endfunction"}}}
function! s:source.vimfiler_gather_candidates(args, context)"{{{
  if empty(a:args)
    return []
  endif

  let args = split(a:args[0], ':')
  let context = deepcopy(a:context)
  let context.is_vimfiler = 1
  let candidates = self.change_candidates(args, context)

  " Set vimfiler property.
  for candidate in candidates
    call unite#sources#ssh#create_vimfiler_dict(candidate)
  endfor

  return candidates
endfunction"}}}
function! s:source.vimfiler_dummy_candidates(args, context)"{{{
  let options = get(a:args, 0, '')
  let hostname = get(a:args, 1, '')
  let path = get(a:args, 2, '')

  if hostname == '' || path == ''
    " No hostname.
    return []
  endif
  if hostname =~ '/$'
    " Chomp.
    let hostname = hostname[ :-2]
  endif

  let base = fnamemodify(path, ':p')
  let filename = fnameescape(path, ':t')

  " Set vimfiler property.
  let candidates = [ unite#sources#ssh#create_file_dict(path, base) ]
  for candidate in candidates
    call unite#sources#file#create_vimfiler_dict(candidate, exts)
  endfor

  return candidates
endfunction"}}}
function! s:source.vimfiler_complete(args, context, arglead, cmdline, cursorpos)"{{{
  let options = get(a:args, 0, '')
  let hostname = get(a:args, 1, '')
  let path = get(a:args, 2, '')

  if hostname == ''
    " No hostname.
    return []
  endif

  let hostname = get(a:args, 0, '')

  return split(s:get_filenames(options, hostname, a:arglead), '\n')
endfunction"}}}

function! unite#sources#ssh#system_passwd(...)"{{{
  return call((unite#util#has_vimproc() ?
        \ 'vimproc#system_passwd' : 'sytem'), a:000)
endfunction"}}}
function! unite#sources#ssh#create_file_dict(file, base_path, ...)"{{{
  let is_newfile = get(a:000, 0, 0)
  let items = split(a:file)
  let filename = get(items, 7, '')
  let is_directory = (get(items, 0, '') =~ '^d')

  let dict = {
        \ 'word' : filename, 'abbr' : filename,
        \ 'action__path' : a:base_path . '/' . filename,
        \ 'source__file_info' : items,
        \ 'source__mode' : get(items, 0, ''),
        \ 'vimfiler__is_directory' : is_directory,
        \}

  let dict.action__directory = a:base_path

  if is_directory
    if a:file !~ '/$'
      let dict.abbr .= '/'
    endif

    let dict.kind = 'directory/ssh'
  else
    if is_newfile
      " New file.
      let dict.abbr = '[new file]' . a:file
    endif

    let dict.kind = 'file/ssh'
  endif

  return dict
endfunction"}}}
function! unite#sources#ssh#create_vimfiler_dict(candidate)"{{{
  let a:candidate.vimfiler__abbr = a:candidate.abbr
  let a:candidate.vimfiler__filename = a:candidate.word

  if !a:candidate.vimfiler__is_directory
    let a:candidate.vimfiler__is_executable =
          \ a:candidate.source__mode =~ 'x'
    let a:candidate.vimfiler__filesize =
          \ get(a:candidate.source__file_info, 3, 0)
  endif

  " Todo:
  let a:candidate.vimfiler__ftype =
        \ a:candidate.vimfiler__is_directory ? 'dir' : 'file'
endfunction"}}}

function! s:get_filenames(options, hostname, path)"{{{
  let outputs = s:ssh_command(a:options, a:hostname,
        \ g:unite_kind_file_ssh_list_command, a:path)
  return len(outputs) == 1 ? outputs : outputs[1:]
endfunction"}}}
function! s:ssh_command(options, hostname, command, path)"{{{
  return split(unite#sources#ssh#system_passwd(
        \ printf('%s %s %s %s', g:unite_kind_file_ssh_command,
        \   a:options, substitute(a:command,
        \   '\<HOSTNAME\>', a:hostname, ''), a:path)), '\n')
endfunction"}}}

" Add custom action table."{{{
let s:cdable_action_file = {
      \ 'description' : 'open this directory by file source',
      \}

function! s:cdable_action_file.func(candidate)
  call unite#start([['file', a:candidate.action__directory]])
endfunction

call unite#custom_action('cdable', 'file', s:cdable_action_file)
unlet! s:cdable_action_file
"}}}

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: foldmethod=marker
