if exists('b:did_indent')
    finish
endif

setl indentexpr=tmux#indent()
setl indentkeys=o

" Teardown {{{1

let b:undo_indent = get(b:, 'undo_indent', 'exe')
    \ .. '| setl indk< inde<'

let b:did_indent = 1
