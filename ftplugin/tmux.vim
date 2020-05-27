if exists('b:did_ftplugin')
    finish
endif
let b:did_ftplugin = 1

setl cms=#\ %s

nno <buffer><expr><nowait> g"  tmux#filterop()
nno <buffer><expr><nowait> g"" tmux#filterop()..'_'
xno <buffer><expr><nowait> g"  tmux#filterop()

compiler tmux

" Teardown {{{1

let b:undo_ftplugin = get(b:, 'undo_ftplugin', 'exe')
    \ ..'| call tmux#undo_ftplugin()'

