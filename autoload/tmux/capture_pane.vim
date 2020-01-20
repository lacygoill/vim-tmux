" Interface {{{1
fu tmux#capture_pane#main() abort "{{{2
    " Purpose:{{{
    "
    " This function is called by a tmux key binding.
    "
    " It makes tmux copy the contents of the pane, from the start of the history
    " down to the end of the visible pane, in a tmux buffer.
    " Then, it makes Nvim read this tmux buffer.
    "
    " If you create a new tmux window and run `$ ls ~`, the tmux buffer contains
    " a lot of empty lines at the bottom; we don't want them.
    "
    " Besides, the tmux buffer contains a lot of trailing whitespace, because we
    " need to pass `-J` to `capture-pane`; we don't want them either.
    "
    " This function  tries to remove  all trailing whitespace, and  all trailing
    " empty lines at the end of the Nvim buffer.
    "
    " ---
    "
    " Also, it tries to  ease the process of copying text  in Nvim, then pasting
    " it in the shell; see the one-shot autocmd at the end.
    "}}}

    " we don't want the modified flag in the status line (nor folding to interfere in the next editions)
    setl bt=nofile nofen

    sil! TW
    exe '$' | call search('^\S', 'bW')
    sil keepj keepp .,$g/^\s*$/d_

    " TODO: should we disable folding, just in case?
    " TODO: highlight cwd above shell command with HG `Directory`

    " Warning: be careful of a pitfall if you save the file in `/tmp` {{{
    "
    " The buffer will probably  be wrongly highlighted as a conf  file if one of
    " its first lines start with a `#`.
    " Right now, we don't have this issue, because when we invoke this function,
    " Vim is passed a pseudo file in `/proc`; and we've configured Vim to ignore
    " the filetype detection of such files:
    "
    "     let g:ft_ignore_pat = '\.\%(Z\|gz\|bz2\|zip\|tgz\|log\)$\|^/proc/'
    "                                                               ^^^^^^^
    "}}}

    let pat_cmd = '\m\C/MSG\s\+.\{-}XDCC\s\+SEND\s\+\d\+'
    " Format the buffer if it contains commands to downloads files via xdcc.{{{
    "
    " Remove noise.
    " Conceal xdcc commands.
    " Highlight filenames.
    " Install mappings to copy the xdcc command in the clipboard.
    "}}}
    " Why `!search('│')`?{{{
    "
    " The code will work  best after we have pressed our  WeeChat key binding to
    " get a bare display (`M-r` atm), where “noise” has been removed.
    " Indeed, with  noise, some xdcc commands  can't be copied in  one pass, but
    " only in two.
    " So,  if we're  not  in  a bare  window,  I don't  want  to  get the  false
    " impression that the buffer can be interacted with reliably.
    "}}}
    if search(pat_cmd) && !search('│')
        call s:format_xdcc_buffer(pat_cmd)
    elseif search('^٪')
        call s:format_shell_buffer()
    endif

    " Do *not* change the name of the augroup.{{{
    "
    " We already have a similar autocmd in our vimrc.
    " I don't want it to interfere.
    " I don't want a race condition where the winning `xsel(1x)` process is the last one.
    " So, I want this autocmd to replace the one in the vimrc.
    " It's probably unnecessary but better be safe than sorry.
    "}}}
    augroup make_clipboard_persist_after_quitting_vim
        au!
        " Do *not* use the pattern `<buffer>`!{{{
        "
        " Atm, we open the qf window.
        " If you use `<buffer>`, the autocmd would be installed for the qf buffer.
        " But if we copy some text, it will probably be in the other buffer.
        " Anyway, no matter the buffer where we copy some text, we want it in `xsel(1x)`.
        "}}}
        " Do *not* use `xclip(1)` instead of `xsel(1x)`!{{{
        "
        " It would work with Nvim, but not with Vim.
        "
        " MWE:
        "
        "     $ tmux -Lx -f/dev/null new
        "     $ tmux splitw vim -Nu NONE
        "     :call system('xclip -selection clipboard', 'hello')
        "     :q
        "     C-S-v
        "     ''~
        "     $ xclip -selection clipboard -o
        "     Error: target STRING not available~
        "
        " It seems that the `xclip(1)` process is killed when we quit Vim, if the latter
        " has been started by tmux instead of being directly started by the shell.
        "
        " I don't understand the cause of the issue.
        " If you press `C-b ;` before quitting Vim, to focus back the pane where a shell
        " is running, and execute `$ pidof xclip`, you'll get a pid.
        " And if you use this pid in `$ pstree -lsp PID`, you'll get sth like this:
        "
        "     systemd(1)---lightdm(1008)---lightdm(1088)---upstart(1097)---xclip(12973)
        "
        " There's no  Vim or Tmux  process in the parents  of `xclip(1)`, so  the latter
        " shouldn't care about what happens to the Vim process...
        "
        " See also: https://unix.stackexchange.com/q/523255/289772
        "
        " ---
        "
        " I think the reason why it works in Nvim is given at `:h vim-differences`:
        "
        " >     |system()|, |systemlist()| can run {cmd} directly (without 'shell')
        "
        " If you wanted to use `xclip(1)` from Vim, you would need to start it without a shell.
        " First, you could write the text in a file:
        "
        "     :let tempfile = tempname()
        "     :call writefile(split(@", '\n'), tempfile, 'b')
        "
        " Then you could run:
        "
        "     :call job_start('xclip -selection clipboard '..tempfile)
        "
        " Why writing the text in a file?
        " Without a file, you would need a pipe; and a pipe can only be parsed by a shell.
        " But remember that we need to avoid a shell to be spawned.
        " So, no shell → no pipe → use a file.
        "
        " However, for some  reason, the job can't be started  from an autocmd listening
        " to `VimLeave(Pre)`;  so, you would  need to make  your autocmd listen  to some
        " other event like `TextYankPost`.
        "}}}
        au VimLeave *
        \   if executable('xsel') && strlen(@+) != 0 && strlen(@+) <= 999
        \ |     sil call system('xsel -ib', @+)
        \ | endif
    augroup END

    setl fen
endfu
"}}}1
" Core {{{1
fu s:format_xdcc_buffer(pat_cmd) abort "{{{2
    " remove noise
    exe 'sil keepj keepp v@'..a:pat_cmd..'@d_'
    sil keepj keepp %s/^.\{-}\d\+)\s*//e

    " align the first 3 fields{{{
    "
    " Don't align beyond the third field; a bot name may contain a bar.
    " As a result, if  you align beyond the third field, you  may break the xdcc
    " command we're going to copy.
    "}}}
    if executable('sed') && executable('column')
        " prepend the first three occurrences of a bar with a literal C-a
        sil %!sed 's/|/\x01|/1; s/|/\x01|/3'
        " sort the text using the C-a's as delimiters
        sil %!column -s $'\x01' -t
    endif
    " `:EasyAlign` alternative:{{{
    "
    "     sil %EasyAlign | {'align': 'lll'}
    "
    " For more info about the syntax of this `:EasyAlign` command,
    " see `:h easy-align-6-7`.
    "}}}

    " highlight filenames
    let pat_file = '\d\+x\s*|\s*[0-9.KMG]*\s*|\s*\zs\S*'
    call matchadd('Underlined', pat_file)

    " conceal commands
    call matchadd('Conceal', a:pat_cmd..'\s*|\s*')
    setl cole=3 cocu=nc

    " make filenames interactive{{{
    "
    " You don't need  `"+y`.
    " `y` is enough, provided that the next one-shot autocmd is installed.
    "}}}
    nno <buffer><nowait><silent> <cr> :<c-u>call <sid>copy_cmd_to_get_file_via_xdcc()<cr>
    nmap <buffer><nowait><silent> ZZ <cr>

    " let us jump from one filename to another by pressing `n` or `N`
    let @/ = pat_file
endfu

fu s:format_shell_buffer() abort "{{{2
    " make `]l` repeatable immediately
    do <nomodeline> CursorHold
    " fold the buffer
    sil! call fold#adhoc#main()
    " open folds automatically
    sil! FoldAutoOpen 1

    " remove empty first line, and empty last prompt
    sil! /^\%1l$/d_
    sil! exe '/^\%'..line('$')..'l٪$/d_'

    " Why the priority 0?{{{
    "
    " To allow  a search to highlight  text even if it's  already highlighted by
    " this match.
    "}}}
    hi Cwd ctermfg=blue | call matchadd('Cwd', '.*\ze\%(\n٪\|\%$\)', 0)
    hi ExitCode ctermfg=red | call matchadd('ExitCode', '\[\d\+\]\ze\%(\n٪\|\%$\)', 0)
    let pat_cmd = '^٪.\+' | hi ShellCmd ctermfg=green | call matchadd('ShellCmd', pat_cmd, 0)

    if search(pat_cmd, 'n')
        sil exe 'lvim /'..pat_cmd..'/j %'
    endif

    let items = getloclist(0)
    call map(items, {_,v -> extend(v, {'text': substitute(v.text, '٪\zs\s\{2,}', '  ', '')})})
    call setloclist(0, [], ' ', {'items': items, 'title': 'last shell commands'})
    " the location list window is automatically opened by one of our autocmds;
    " conceal the location
    call qf#set_matches('after_tmux_capture_pane:format_shell_buffer', 'Conceal', 'location')
    call qf#create_matches()
    lclose
    norm! gg
endfu

fu s:copy_cmd_to_get_file_via_xdcc() abort "{{{2
    let line = getline('.')
    let msg = matchstr(line, '\m\C/MSG\s\+\zs.\{-}XDCC\s\+SEND\s\+\d\+')
    " What is this `moviegods_send_me_file`?{{{
    "
    " A WeeChat alias.
    " If it doesn't exist, you can install it by running in WeeChat:
    "
    "     /alias add moviegods_send_me_file /j #moviegods ; /msg
    "}}}
    "   Why do you use an alias?{{{
    "
    " I don't join `#moviegods` by default, because it adds too much network traffic.
    " And a `/msg ... xdcc send ...` command doesn't work if you haven't joined this channel.
    " IOW, we need to run 2 commands:
    "
    "     /j #moviegods
    "     /msg ... xdcc send ...
    "
    " But, in the end, we will only be able to write one in the clipboard.
    " To fix  this issue, we  need to build a  command-line which would  run two
    " commands.
    "
    " An alias allows you to use the `;` token which has the same meaning as in a shell.
    " With it, you can do:
    "
    "     cmd1 ; cmd2
    "}}}
    let cmd = '/moviegods_send_me_file '..msg
    let @+ = cmd
    q!
endfu

