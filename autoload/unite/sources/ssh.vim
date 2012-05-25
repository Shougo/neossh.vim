"=============================================================================
" FILE: ssh.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 25 May 2012.
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
"}}}

call unite#kinds#file_ssh#initialize()

function! unite#sources#ssh#define()"{{{
  return s:source
endfunction"}}}

let s:source = {
      \ 'name' : 'ssh',
      \ 'description' : 'candidates from ssh',
      \}

let s:filelist_cache = {}

function! s:source.change_candidates(args, context)"{{{
  let args = join(a:args, ':')
  let [hostname, port, path] = unite#sources#ssh#parse_path(args)
  if hostname == ''
    " No hostname.
    return []
  endif

  let is_vimfiler = get(a:context, 'is_vimfiler', 1)

  let input_list = filter(split(a:context.input,
        \                     '\\\@<! ', 1), 'v:val !~ "!"')
  let input = empty(input_list) ? '' : input_list[0]
  let input = substitute(substitute(
        \ a:context.input, '\\ ', ' ', 'g'), '^\a\+:\zs\*/', '/', '')

  if path != '' && path !~ '[:/]$'
    let path .= '/'
  endif

  let input = path . input

  " Substitute *. -> .* .
  let input = substitute(input, '\*\.', '.*', 'g')

  if input !~ '\*' && unite#is_win() && getftype(input) == 'link'
    " Resolve link.
    let input = resolve(input)
  endif

  " Glob by directory name.
  let input = substitute(input, '[^/]*$', '', '')
  let input_directory = input
  if input_directory != '' && input_directory !~ '/$'
    let input_directory .= '/'
  endif

  let files = map(s:get_filenames(hostname, port, input, a:context.is_redraw),
        \ "unite#sources#ssh#create_file_dict(v:val,
        \   hostname.':'.port.'/'.input_directory.v:val, hostname)")

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

  let candidates = files

  if a:context.input != '' && !is_vimfiler
    let newfile = substitute(a:context.input, '[*\\]', '', 'g')
    if !filereadable(newfile) && !isdirectory(newfile)
      " Add newfile candidate.
      let candidates = copy(candidates) +
            \ [unite#sources#ssh#create_file_dict(newfile,
            \  hostname.':'.port.'/'. input_directory.newfile,
            \ hostname, 1)]
    endif

    if input !~ '^\%(/\|\a\+:/\)$'
      let parent = substitute(input, '[*\\]\|\.[^/]*$', '', 'g')

      if a:context.input =~ '\.$' && isdirectory(parent . '..')
        " Add .. directory.
        let file = parent . '..'
        let candidates = [unite#sources#ssh#create_file_dict(file,
              \ hostname.':'.port.'/'. input_directory . file,
              \ hostname)]
              \ + copy(candidates)
      endif
    endif
  endif

  return candidates
endfunction"}}}
function! s:source.vimfiler_check_filetype(args, context)"{{{
  let args = join(a:args, ':')
  let [hostname, port, path] =
        \ unite#sources#ssh#parse_path(args)

  if hostname == ''
    " No hostname.
    return [ 'error', '[ssh] usage: ssh://[user@]hostname/[path]' ]
  endif

  if path =~ '/$' || path == ''
    " For directory.
    let type = 'directory'
    let info = printf('//%s:%d/%s', hostname, port, path)
    return [type, info]
  endif

  " For file.

  let type = 'file'

  " Use temporary file.
  let tempname = tempname()
  let dict = unite#sources#ssh#create_file_dict(
        \ fnamemodify(path, ':t'),
        \ printf('%s:%d/%s', hostname, port, path), hostname)
  call unite#sources#ssh#create_vimfiler_dict(dict)
  if unite#kinds#file_ssh#external('copy_file', port, tempname, [
        \ printf('%s:%s', hostname, path) ])
    call unite#print_error(printf('Failed file "%s" copy : %s',
          \ path, unite#util#get_last_errmsg()))
  endif

  if !filereadable(tempname)
    return [[], dict]
  endif

  let lazy = &lazyredraw

  set nolazyredraw

  " Read temporary file.
  let current = bufnr('%')

  silent! edit `=tempname`
  let lines = getbufline(bufnr(tempname), 1, '$')
  let fileencoding = getbufvar(bufnr(tempname), '&fileencoding')
  silent execute 'buffer' current
  silent execute 'bdelete!' bufnr(tempname)
  call delete(tempname)
  let dict.vimfiler__encoding = fileencoding

  let &lazyredraw = lazy

  let info = [lines, dict]

  return [type, info]
endfunction"}}}
function! s:source.vimfiler_gather_candidates(args, context)"{{{
  if empty(a:args)
    return []
  endif

  let context = deepcopy(a:context)
  let context.is_vimfiler = 1
  let candidates = self.change_candidates(a:args, context)

  " Set vimfiler property.
  for candidate in candidates
    call unite#sources#ssh#create_vimfiler_dict(candidate)
  endfor

  return candidates
endfunction"}}}
function! s:source.vimfiler_dummy_candidates(args, context)"{{{
  let args = join(a:args, ':')
  let [hostname, port, path] = unite#sources#ssh#parse_path(args)
  if hostname == ''
    " No hostname.
    return []
  endif

  let filename = unite#util#substitute_path_separator(
        \ fnamemodify(path, ':t'))

  " Set vimfiler property.
  let candidates = [ unite#sources#ssh#create_file_dict(
        \ filename, path, hostname) ]
  for candidate in candidates
    call unite#sources#file#create_vimfiler_dict(candidate, exts)
  endfor

  return candidates
endfunction"}}}
function! s:source.vimfiler_complete(args, context, arglead, cmdline, cursorpos)"{{{
  let arg = join(a:args, ':')
  let [hostname, port, path] =
        \ unite#sources#ssh#parse_path(arg)
  if hostname == '' || arg !~ ':'
    " No hostname.
    return map(unite#sources#ssh#complete_host(
          \ a:args, a:context, substitute(a:arglead, '^//', '', ''),
          \  a:cmdline, a:cursorpos),
          \   "'//' . v:val . ':'")
  else
    return map(unite#sources#ssh#complete_file(
          \ a:args, a:context, a:arglead, a:cmdline, a:cursorpos),
          \   "'//' . v:val . ':'")
  endif
endfunction"}}}

function! unite#sources#ssh#system_passwd(...)"{{{
  return call((unite#util#has_vimproc() ?
        \ 'vimproc#system_passwd' : 'system'), a:000)
endfunction"}}}
function! unite#sources#ssh#create_file_dict(file, path, hostname, ...)"{{{
  let is_newfile = get(a:000, 0, 0)
  let filename = substitute(a:file, '[*/@|]$', '', '')
  let path = substitute(a:path, '[*/@|]$', '', '')
  let is_directory = a:file =~ '/$'

  let dict = {
        \ 'word' : filename, 'abbr' : filename,
        \ 'action__path' : 'ssh://' . path,
        \ 'vimfiler__is_directory' : is_directory,
        \ 'source__mode' : matchstr(a:file, '[*/@|]$'),
        \}

  let dict.action__directory =
        \ unite#util#substitute_path_separator(
        \ fnamemodify(path, ':h'))

  if is_directory
    let dict.abbr .= '/'
    let dict.kind = 'directory/ssh'
  else
    if is_newfile
      " New file.
      let dict.abbr = '[new file]' . filename
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
          \ a:candidate.source__mode ==# '*'
  endif

  " Todo:
  let a:candidate.vimfiler__ftype =
        \ a:candidate.vimfiler__is_directory ? 'dir' : 'file'
endfunction"}}}
function! unite#sources#ssh#parse_path(path)"{{{
  let args = matchlist(a:path,
        \'^//\([^/#:]\+\)\%([#:]\(\d*\)\)\?/\?\(.*\)$')

  let hostname = get(args, 1, '')
  let port = get(args, 2, '')
  if port == ''
    " Use default port.
    let port = 22
  endif
  let path = get(args, 3, '')

  return [hostname, port, path]
endfunction"}}}
function! unite#sources#ssh#parse_action_path(path)"{{{
  if a:path =~ '^ssh:'
    let [hostname, port, path] =
          \ unite#sources#ssh#parse_path(
          \  substitute(a:path, '^ssh:', '', ''))
    let path = printf('%s:%s', hostname, path)
  else
    let port = 22
    let path = a:path
  endif

  return [port, path]
endfunction"}}}

function! unite#sources#ssh#complete_host(args, context, arglead, cmdline, cursorpos)"{{{
  return unite#sources#ssh#command_complete_host(
        \ a:arglead, a:cmdline, a:cursorpos)
endfunction"}}}
function! unite#sources#ssh#complete_file(args, context, arglead, cmdline, cursorpos)"{{{
  let [hostname, port, path] =
        \ unite#sources#ssh#parse_path(join(a:args, ':'))
  if hostname == ''
    " No hostname.
    return []
  endif

  return map(s:get_filenames(hostname, port, path, 0),
        \ "printf('%s:%s/%s', hostname, port,
        \      substitute(v:val, '[*@|]$', '', ''))")
endfunction"}}}
function! unite#sources#ssh#command_complete_directory(arglead, cmdline, cursorpos)"{{{
  let vimfiler_current_dir =
        \ get(unite#get_context(), 'vimfiler__current_directory', '')
  return filter(unite#sources#ssh#complete_file(
        \ split(vimfiler_current_dir, ':'), unite#get_context(),
        \ a:arglead, a:cmdline, a:cursorpos), "v:val =~ '/$'")
endfunction"}}}
function! unite#sources#ssh#command_complete_file(arglead, cmdline, cursorpos)"{{{
  let vimfiler_current_dir =
        \ get(unite#get_context(), 'vimfiler__current_directory', '')
  return unite#sources#ssh#complete_file(
        \ split(vimfiler_current_dir, ':'), unite#get_context(),
        \ a:arglead, a:cmdline, a:cursorpos)
endfunction"}}}
function! unite#sources#ssh#command_complete_host(arglead, cmdline, cursorpos)"{{{
  let _ = []

  if filereadable('/etc/hosts')
    for line in filter(
          \ readfile('/etc/hosts'), "v:val !~ '^\\s*#'")
      let host = matchstr(line, '\f\+$')
      if host != ''
        call add(_, host)
      endif
    endfor
  endif

  if filereadable(expand('~/.ssh/config'))
    for line in readfile(expand('~/.ssh/config'))
      let host = matchstr(line, '^Host\s\+\zs[^*]\+\ze')
      if host != ''
        call add(_, host)
      endif
    endfor
  endif

  if filereadable(expand('~/.ssh/known_hosts'))
    for line in filter(
          \ readfile(expand('~/.ssh/known_hosts')),
          \        "v:val !~ '^[|\\[]'")
      let host = matchstr(line, '^[^,]*')
      if host != ''
        call add(_, host)
      endif
    endfor
  endif

  return sort(filter(_, 'stridx(v:val, a:arglead) == 0'))
endfunction"}}}

function! unite#sources#ssh#copy_files(dest, srcs)"{{{
  let vimfiler_current_dir =
        \ get(unite#get_context(), 'vimfiler__current_directory', '')
  let [dest_port, dest_path] =
        \ unite#sources#ssh#parse_action_path(vimfiler_current_dir)

  for src in a:srcs
    let port = dest_port

    let [src_port, src_path] =
        \ unite#sources#ssh#parse_action_path(src.action__path)
    if src_port != 22 && port != src_port
      let port = src_port
    endif

    if fnamemodify(src_path, ':h') ==# dest_path
      " Same filename.
      echo 'File is already exists!'
      let dest_path =
            \ input(printf('New name: %s -> ', src_path), src_path,
            \  'unite#sources#ssh#command_complete_file')
    endif
    if unite#kinds#file_ssh#external('copy_directory',
          \ port, dest_path, [src_path])
      call unite#print_error(printf('Failed file "%s" copy : %s',
            \ src_path, unite#util#get_last_errmsg()))
    endif
  endfor
endfunction"}}}
function! unite#sources#ssh#move_files(dest, srcs)"{{{
  let vimfiler_current_dir =
        \ get(unite#get_context(), 'vimfiler__current_directory', '')
  let [dest_port, dest_path] =
        \ unite#sources#ssh#parse_action_path(vimfiler_current_dir)

  for src in a:srcs
    let port = dest_port

    let [src_port, src_path] =
        \ unite#sources#ssh#parse_action_path(src.action__path)
    if src_port != 22 && port != src_port
      let port = src_port
    endif

    if unite#kinds#file_ssh#external('move',
          \ port, dest_path, [src_path])
      call unite#print_error(printf('Failed file "%s" move : %s',
            \ src_path, unite#util#get_last_errmsg()))
    endif
  endfor
endfunction"}}}

function! s:get_filenames(hostname, port, path, is_force)"{{{
  let key = a:hostname.':'.a:path
  if !has_key(s:filelist_cache, key)
    \ || a:is_force
    let outputs = filter(s:ssh_command(a:hostname, a:port,
          \ g:unite_kind_file_ssh_list_command, a:path),
          \   "v:val !~ 'No such file or directory'")
    let s:filelist_cache[key] =
          \ (len(outputs) == 1 ? outputs : outputs[1:])
  endif

  return copy(s:filelist_cache[key])
endfunction"}}}
function! s:ssh_command(hostname, port, command, path)"{{{
  let command = substitute(substitute(
        \ g:unite_kind_file_ssh_command . ' ' . a:command,
        \   '\<HOSTNAME\>', a:hostname, 'g'), '\<PORT\>', a:port, 'g')
  return filter(split(unite#sources#ssh#system_passwd(
        \ printf('%s ''%s''', command, fnameescape(a:path))), '\r\?\n'),
        \ "v:val != '' && v:val !~ '^ls: '")
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
