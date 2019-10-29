if exists('b:did_ftplugin')
    finish
endif
let b:did_ftplugin = 1

setl cms=#\ %s

nno <buffer><nowait><silent> K :<c-u>call tmux#man()<cr>

nno <buffer><nowait><silent> g"  :<c-u>set opfunc=tmux#filterop<cr>g@
nno <buffer><nowait><silent> g"" :<c-u>set opfunc=tmux#filterop<bar>norm! g@_<cr>
xno <buffer><nowait><silent> g"  :<c-u>call tmux#filterop(visualmode())<cr>

compiler tmux

" Teardown {{{1

let b:undo_ftplugin = get(b:, 'undo_ftplugin', 'exe')
    \ ..'| call tmux#undo_ftplugin()'

