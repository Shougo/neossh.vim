"=============================================================================
" FILE: ssh.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 20 Aug 2012.
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

  let files = map(s:get_filelist(
        \ hostname, port, input, a:context.is_redraw),
        \ "unite#sources#ssh#create_file_dict(v:val,
        \   hostname.':'.port.'/'.input_directory.v:val.filename, hostname)")

  call filter(files, "v:val.action__path !~ "
        \ . string('\%(^\|/\)\.\.\?$'))

  if !is_vimfiler
    if g:unite_source_file_ssh_ignore_pattern != ''
      call filter(files,
            \ 'v:val.action__path !~ '
            \  . string(g:unite_source_file_ssh_ignore_pattern))
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
    return ['error', 'Failed to open file.']
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
    call unite#sources#ssh#create_vimfiler_dict(candidate)
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
          \   "printf('//%s', v:val)")
  endif
endfunction"}}}
function! s:source.complete(args, context, arglead, cmdline, cursorpos)"{{{
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
    return filter(map(unite#sources#ssh#complete_file(
          \ a:args, a:context, a:arglead, a:cmdline, a:cursorpos),
          \   "printf('//%s', v:val)"), "v:val =~ '/$'")
  endif
endfunction"}}}

function! unite#sources#ssh#system_passwd(...)"{{{
  return call((unite#util#has_vimproc() ?
        \ 'vimproc#system_passwd' : 'system'), a:000)
endfunction"}}}
function! unite#sources#ssh#create_file_dict(file, path, hostname, ...)"{{{
  let is_newfile = get(a:000, 0, 0)
  let filename = substitute(a:file.filename, '[*/@|]$', '', '')
  let path = substitute(a:path, '[*/@|]$', '', '')
  let is_directory = a:file.filename =~ '/$'

  let dict = {
        \ 'word' : filename, 'abbr' : filename,
        \ 'action__path' : 'ssh://' . path,
        \ 'vimfiler__is_directory' : is_directory,
        \ 'vimfiler__filesize' : a:file.filesize,
        \ 'vimfiler__filetime' : a:file.filetime,
        \ 'source__mode' : matchstr(a:file.filename, '[*/@|]$'),
        \}

  " Use date command.
  let dict.vimfiler__filetime = executable('date') ?
        \ substitute(unite#util#system(printf(
        \  'date -d %s +%%s', string(a:file.filetime))),
        \ '\n$', '', '') : a:file.filetime

  if a:file.mode =~# '^l'
    let dict.vimfiler__ftype = 'link'
  endif

  let dict.action__directory = dict.action__path
  if !is_directory
    let dict.action__directory =
          \ unite#util#substitute_path_separator(
          \ fnamemodify(dict.action__path, ':h'))
  endif

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
  let args = matchlist(
        \ substitute(a:path, '^ssh:', '', ''),
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
  if a:path =~ '^ssh:\|^//'
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
function! unite#sources#ssh#convert2fullpath(path)"{{{
  let path = a:path
  let vimfiler_current_dir = get(unite#get_context(),
        \  'vimfiler__current_directory', '')
  let [_, vimfiler_path] =
        \ unite#sources#ssh#parse_action_path(vimfiler_current_dir)
  if path == ''
    let path = vimfiler_path
  elseif path == '.' || path == '^\./'
    let path = vimfiler_path . path[1:]
  endif

  return path
endfunction"}}}
function! unite#sources#ssh#parse2fullpath(path)"{{{
  let path = substitute(a:path, '^file:', '', '')
  let [host, port, parsed_path] =
        \ unite#sources#ssh#parse_path(path)

  let parsed_path = (path =~ '^ssh:') ?
        \ unite#sources#ssh#convert2fullpath(parsed_path) : path

  return [host, port, parsed_path]
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

  " Glob by directory name.
  let directory = substitute(path, '[^/]*$', '', '')

  let files = filter(map(s:get_filelist(hostname, port, directory, 1),
        \ 'v:val.filename'), "v:val !~ '\\.\\.\\?/$'")

  if directory !=# path
    let narrow_path = fnamemodify(path, ':t')
    call map(filter(files,
          \ 'stridx(v:val, narrow_path) == 0'),
          \ 'directory . v:val')
  else
    call map(files, 'path . v:val')
  endif

  return map(files, "printf('%s:%s/%s', hostname, port,
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
      let host = matchstr(line, '^[^, ]*')
      if host != ''
        call add(_, host)
      endif
    endfor
  endif

  return sort(filter(_, 'stridx(v:val, a:arglead) == 0'))
endfunction"}}}

function! unite#sources#ssh#copy_files(dest, srcs)"{{{
  let [dest_host, dest_port, dest_path] =
        \ unite#sources#ssh#parse2fullpath(a:dest)

  let ret = 0

  for src in a:srcs
    let [src_host, src_port, src_path] =
          \ unite#sources#ssh#parse2fullpath(src.action__path)
    let port = (src_port != 22 && port != src_port) ?
          \ src_port : dest_port

    if src_host ==# dest_host
      " Remote to remote copy.
      while unite#sources#ssh#convert2fullpath(
            \ fnamemodify(src_path, ':h')) ==# dest_path
        " Same filename.
        echo 'File is already exists!'
        let dest_path =
              \ input(printf('New name: %s -> ', src_path),
              \ src_path,
              \ 'customlist,unite#sources#'.
              \   'ssh#command_complete_file')
        redraw!

        if dest_path == ''
          return ret
        endif
      endwhile

      let command_line = unite#kinds#file_ssh#substitute_command(
            \ 'copy_directory', port, dest_path, [src_path])
      let [status, output] = unite#sources#ssh#ssh_command(
            \ command_line, dest_host, port, '')
      if status
        call unite#print_error(printf(
              \ 'Failed file "%s" copy : %s',
              \ path, unite#util#get_last_errmsg()))
        let ret = 1
      endif
    else
      if dest_host != '' && src_host != ''
        let temp = unite#sources#file#create_file_dict(
              \ fnamemodify(tempname(), ':h') . '/' .
              \ fnamemodify(src.action__path, ':t'), 0)
        let ret = unite#sources#ssh#copy_files(
              \ temp.action__path, [src])
        if !ret
          let ret = unite#sources#ssh#move_files(a:dest, [temp])
        endif
      else
        " Remote to local copy.

        let dest_remote = (dest_host != '') ?
              \ dest_host.':'.dest_path : dest_path
        if src_host != ''
          let src_path = src_host.':'.src_path
        endif

        if unite#kinds#file_ssh#external('copy_directory',
              \ port, dest_remote, [src_path])
          call unite#print_error(printf(
                \ 'Failed file "%s" copy : %s',
                \ src_path, unite#util#get_last_errmsg()))
          let ret = 1
        endif
      endif
    endif
  endfor

  return ret
endfunction"}}}
function! unite#sources#ssh#move_files(dest, srcs)"{{{
  let [dest_host, dest_port, dest_path] =
        \ unite#sources#ssh#parse2fullpath(a:dest)

  let ret = 0

  for src in a:srcs
    let [src_host, src_port, src_path] =
          \ unite#sources#ssh#parse2fullpath(src.action__path)
    let port = (src_port != 22 && port != src_port) ?
          \ src_port : dest_port

    if src_host ==# dest_host
      " Remote to remote move.
      while unite#sources#ssh#convert2fullpath(
            \ fnamemodify(src_path, ':h')) ==# dest_path
        " Same filename.
        echo 'File is already exists!'
        let dest_path =
              \ input(printf('New name: %s -> ', src_path),
              \ src_path,
              \ 'customlist,unite#sources#'.
              \   'ssh#command_complete_file')
        redraw!

        if dest_path == ''
          return ret
        endif
      endwhile

      let command_line = unite#kinds#file_ssh#substitute_command(
            \ 'move', port, dest_path, [src_path])
      let [status, output] = unite#sources#ssh#ssh_command(
            \ command_line, dest_host, port, '')
      if status
        call unite#print_error(printf(
              \ 'Failed file "%s" move : %s',
              \ path, unite#util#get_last_errmsg()))
        let ret = 1
      endif
    else
      if dest_host != '' && src_host != ''
        let temp = unite#sources#file#create_file_dict(
              \ fnamemodify(tempname(), ':h') . '/' .
              \ fnamemodify(src.action__path, ':t'), 0)
        let ret = unite#sources#ssh#move_files(
              \ temp.action__path, [src])
        if !ret
          let ret = unite#sources#ssh#move_files(a:dest, [temp])
        endif
      else
        " Remote to local move.

        let ret = unite#sources#ssh#copy_files(a:dest, [src])
        if !ret
          let ret = unite#sources#ssh#delete_files([src])
        endif
      endif
    endif
  endfor

  return ret
endfunction"}}}
function! unite#sources#ssh#delete_files(srcs)"{{{
  for src in a:srcs
    let protocol = matchstr(
          \ src.action__path, '^\h\w\+')
    if protocol == ''
      let protocol = 'file'
    endif

    if protocol !=# 'ssh'
      call unite#sources#{protocol}#delete_files([src])
      continue
    endif

    let [hostname, port, path] =
          \ unite#sources#ssh#parse_path(src.action__path)
    let command_line = unite#kinds#file_ssh#substitute_command(
          \ 'delete_directory', port, '', [path])

    let [status, output] = unite#sources#ssh#ssh_command(
          \ command_line, hostname, port, '')
    if status
      call unite#print_error(printf('Failed delete "%s" : %s',
            \ path, unite#util#get_last_errmsg()))
    endif
  endfor
endfunction"}}}

function! s:get_filelist(hostname, port, path, is_force)"{{{
  let key = a:hostname.':'.a:path
  if !has_key(s:filelist_cache, key)
    \ || a:is_force
    let outputs = map(filter(map(unite#sources#ssh#ssh_list(
          \ g:unite_kind_file_ssh_list_command,
          \ a:hostname, a:port, a:path),
          \   "split(v:val, '\\s\\+')"),
          \ 'len(v:val) >= 8'), "{
          \ 'mode' : v:val[0],
          \ 'filesize' : v:val[3],
          \ 'filetime' : join(v:val[4:6]),
          \ 'filename' : substitute(join(v:val[7:]),
          \         '\\s\\+->.*$', '', ''),
          \ }")
    let s:filelist_cache[key] = outputs
  endif

  return copy(s:filelist_cache[key])
endfunction"}}}
function! unite#sources#ssh#ssh_command(command, host, port, path)"{{{
  let command_line = substitute(substitute(
        \ g:unite_kind_file_ssh_command . ' ' . a:command,
        \   '\<HOSTNAME\>', a:host, 'g'), '\<PORT\>', a:port, 'g')
  if a:path != ''
    let command_line .= ' ' . string(fnameescape(a:path))
  endif

  let output = unite#sources#ssh#system_passwd(
        \ command_line, a:host, a:port, a:path)
  if stridx(output, a:host) >= 0
    " Strip hostname.
    let output = output[len(a:host):]
  endif
  let status = unite#util#get_last_status()

  return [status, output]
endfunction"}}}
function! unite#sources#ssh#ssh_list(command, host, port, path)"{{{
  let lang_save = $LANG
  try
    let $LANG = 'C'

    let command_line = substitute(substitute(
          \ g:unite_kind_file_ssh_command . ' ' . a:command,
          \   '\<HOSTNAME\>', a:host, 'g'), '\<PORT\>', a:port, 'g')
    if a:path != ''
      let command_line .= ' ' . string(fnameescape(a:path))
    endif

    let output = unite#sources#ssh#system_passwd(
          \ command_line, a:host, a:port, a:path)
  finally
    let $LANG = lang_save
  endtry

  return filter(split(output, '\r\?\n'),
        \ "v:val != '' && v:val !~ '^ls: ' &&
        \  v:val !~ 'No such file or directory'")
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
