if exists('g:loaded_tmux')
    finish
endif
let g:loaded_tmux = 1

" This command is called by one of our tmux key binding.{{{
"
" Its  purpose is to  paste the  last shell command(s)  and their output  in the
" previous pane if it runs Vim.
"
" We often need to copy paste a shell command and its output in our notes.
" A key binding should make the process smoother.
"}}}
com -bar -nargs=1 TxPasteLastShellCmd call tmux#paste_last_shell_cmd(<args>)

nno <unique><silent> <bar>x     :<c-u>set opfunc=tmux#run#command<cr>g@l
nno <unique><silent> <bar><bar> :<c-u>call tmux#run#command()<cr>

