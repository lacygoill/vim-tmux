if exists('b:did_indent')
    finish
endif
let b:did_indent = 1
let b:current_indent = 'tmux'

setl indentexpr=GetTmuxIndent()
setl indentkeys=o

" Only define the function once.
if exists('*GetTmuxIndent')
    finish
endif

fu! s:highlight_group(line, col) abort
    return synIDattr(synID(a:line, a:col, 1), 'name')
endfu

fu! s:prev_line_ends_with_open_string(lnum) abort
    if a:lnum > 1
        let prev_line_len = len(getline(a:lnum - 1))
        if s:highlight_group(a:lnum - 1, prev_line_len) is# 'tmuxString'
            return 1
        endif
    endif
    return 0
endfu

fu! GetTmuxIndent() abort
    " If the string is not closed and was previously indented, then keep the
    " indentation.
    return s:prev_line_ends_with_open_string(v:lnum)
        \ ?     indent('.')
        \ :     0
endfu

" teardown {{{1

let b:undo_indent = get(b:, 'undo_indent', '')
    \ . (empty(get(b:, 'undo_indent', '')) ? '' : '|')
    \ . 'setl indk< inde<'

