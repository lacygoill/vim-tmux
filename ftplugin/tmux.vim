if exists('b:did_ftplugin')
    finish
endif
let b:did_ftplugin = 1

setl cms=#\ %s

nno <buffer><nowait><silent> K :<c-u>call tmux#man()<cr>

nno <buffer><nowait><silent> g!  :<c-u>set opfunc=tmux#filterop<cr>g@
nno <buffer><nowait><silent> g!! :<c-u>set opfunc=tmux#filterop<cr>g@_
xno <buffer><nowait><silent> g!  :<c-u>call tmux#filterop(visualmode())<cr>

compiler tmux

" teardown {{{1

let b:undo_ftplugin = get(b:, 'undo_ftplugin', 'exe')
    \ . "
    \ | setl cms<
    \ | set efm< mp<
    \ | exe 'nunmap <buffer> K'
    \ | exe 'nunmap <buffer> g!'
    \ | exe 'nunmap <buffer> g!!'
    \ | exe 'xunmap <buffer> g!'
    \ "

