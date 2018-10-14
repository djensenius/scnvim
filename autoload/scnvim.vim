" File: scnvim/supercollider.vim
" Author: David Granström
" Description: scnvim interface
" Last Modified: October 08, 2018

function! scnvim#send_line(...) abort
  let lines = getline(a:1, a:2)
  let str = join(lines, "\n")
  call scnvim#sclang#send(str)
endfunction

function! scnvim#send_selection() abort
  let selection = s:get_visual_selection()
  call scnvim#sclang#send(selection)
endfunction

function! scnvim#send_block() abort
  try
    let [start, end] = s:get_sclang_block()
    call scnvim#send_line(start, end)
  catch
    echohl WarningMsg | echo v:exception | echohl None
  endtry
endfunction

" helpers {{{

function! s:get_visual_selection()
  let [l:lnum1, l:col1] = getpos("'<")[1:2]
  let [l:lnum2, l:col2] = getpos("'>")[1:2]
  if &selection ==# 'exclusive'
    let l:col2 -= 1
  endif
  let l:lines = getline(l:lnum1, l:lnum2)
  let l:lines[-1] = l:lines[-1][:l:col2 - 1]
  let l:lines[0] = l:lines[0][l:col1 - 1:]
  return join(l:lines, "\n")
endfunction

function! s:skip_pattern()
  return 'synIDattr(synID(line("."), col("."), 0), "name") ' .
          \ '=~? "scComment\\|scString\\|scSymbol"'
endfunction

function! s:find_match(start, end, flags)
    return searchpairpos(a:start, '', a:end, a:flags, s:skip_pattern())
endfunction

function! s:get_sclang_block()
	  let c_lnum = line('.')
	  let c_col = col('.')

    " see where we are now
	  let c = getline(c_lnum)[c_col - 1]
    let plist = ['(', ')']
    let pindex = index(plist, c)

    let p = '^('
    let p2 = '^)'

    let start_pos = [0, 0]
    let end_pos = [0, 0]

    let forward_flags = 'nW'
    let backward_flags = 'nbW'

    " if we are in a string, comment etc.
    " parse the block as if we are in the middle
    let should_skip = eval(s:skip_pattern())

    if pindex == 0 && !should_skip
      " on an opening brace
      let start_pos = [c_lnum, c_col]
      let end_pos = s:find_match(p, p2, forward_flags)
    elseif pindex == 1 && !should_skip
      " on an closing brace
      let start_pos = [c_lnum, c_col]
      let end_pos = s:find_match(p, p2, backward_flags)
    else
      " middle of a block
      let start_pos = s:find_match(p, p2, backward_flags)
      let end_pos = s:find_match(p, p2, forward_flags)
    endif

    if start_pos[0] == 0 || end_pos[0] == 0
      throw "scnvim: Error parsing block"
    endif

    " sort the numbers so getline can use them
    return sort([start_pos[0], end_pos[0]], 'n')
endfunction
" }}}

" vim:foldmethod=marker
