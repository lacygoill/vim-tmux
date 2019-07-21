" Interface {{{1
fu! tmux#run#command(repeat) abort "{{{2
    if !exists('$TMUX')
        echo 'requires Tmux' | return
    endif
    if !a:repeat
        let cmd = s:get_cmd()
        if empty(cmd) | return | endif
    elseif a:repeat && !exists('s:last_cmd')
        if s:is_other_shell_pane()
            call system('tmux send -t! Up Enter')
        else
            echo 'no command to repeat'
        endif
        return
    endif
    " remove `s:pane_id` if we manually closed the pane associated to it,
    " otherwise the function will think there's no need to create a pane
    call s:clear_stale_pane_id()
    if !exists('s:pane_id') | call s:open_pane() | endif
    call s:close_pane('later')
    if a:repeat
        call s:run_shell_cmd(s:last_cmd)
    else
        call s:run_shell_cmd(cmd)
        let s:last_cmd = cmd
    endif
endfu
"}}}1
" Core {{{1
fu! s:get_cmd() abort "{{{2
    if &ft isnot# 'markdown'
        let cml = matchstr(get(split(&l:cms, '%s'), 0, ''), '\S\+')
    else
        let cml = ''
    endif
    " Note that we don't exclude the whitespace which follows the `$` shell prompt.
    " This will make sure that when the command is run, zsh doesn't log it in its history.
    let cmd = matchstr(getline('.'), '^\s*'..cml..'\s*\$\zs\s.*')
    " support continuation lines
    if cmd =~# '\\\s*$'
        let end = search('\%(\\\s*\)\@<!$', 'nW')
        if end == 0 | let end = line('$') | endif
        let lines = [cmd] + getline(line('.')+1, end)
        let cmd = join(map(lines, {_,v -> substitute(v, '\\\s*$', '', '')}))
    endif
    if empty(cmd)
        if &ft is# 'python'
            sil! update
            sil call system('python3 -m py_compile '..expand('%:p:S'))
            let cmd = 'cd '..shellescape(expand('%:p:h'))..' && python3 '..expand('%:p:t:S')
        else
            echo 'no command to run on this line'
            return ''
        endif
    endif
    return cmd
endfu

fu! s:clear_stale_pane_id() abort "{{{2
    if !exists('s:pane_id')
        return
    endif
    sil let open_panes = systemlist("tmux lsp -F '#D'")
    let is_pane_still_open = index(open_panes, s:pane_id) >= 0
    if !is_pane_still_open
        " the pane should be closed, but better be safe
        sil call system('tmux killp -t '..s:pane_id)
        unlet! s:pane_id
    endif
endfu

fu! s:open_pane() abort "{{{2
    let cmds = [
    \ 'splitw -c',
    \ shellescape('/run/user/1000/tmp'),
    \ '-d -p 25 -PF "#D"'
    \ ]
    let s:pane_id = system('tmux '..join(cmds))[:-2]
endfu

fu! s:close_pane(when) abort "{{{2
    if a:when is# 'later'
        augroup tmux_run_cmd_close_pane
            " Is it ok to remove *all* autocmds?{{{
            "
            " For the moment, yes.
            " I don't intend to have more than one pane open at a time.
            "
            " If you  want more granularity, you  could remove `au!`, and  add a
            " bang after all the next `:au` commands (`au` → `au!`).
            "
            " If you  want to check whether  the autocmds are duplicated,  run a
            " command, close its pane, then re-run the command.
            "}}}
            au!
            au VimLeave * call s:close_pane('now')
            au BufWinLeave <buffer> call s:close_pane('now')
        augroup END
    else
        try
            sil call system('tmux killp -t '..s:pane_id)
            unlet! s:pane_id s:last_cmd
            au! tmux_run_cmd_close_pane
        catch
            return lg#catch_error()
        endtry
    endif
endfu

fu! s:run_shell_cmd(cmd) abort "{{{2
    let cmd = substitute(a:cmd, '\\\s\+$', '\', '')
    " https://github.com/jebaum/vim-tmuxify/issues/16
    let cmd = substitute(a:cmd, '\t', ' ', 'g')
    " Make sure a trailing semicolon is correctly sent.{{{
    "
    " ... and not parsed as a command termination.
    "
    " https://github.com/tmux/tmux/issues/1849
    " https://github.com/jebaum/vim-tmuxify/issues/11
    "}}}
    if cmd[-1:] is# ';'
        let cmd = cmd[:-2]..'\;'
    endif
    let tmux_cmd = 'tmux send -t '..s:pane_id..' -l '..shellescape(cmd)
    \ ..'     \; send -t '..s:pane_id..' C-m'
    sil call system(tmux_cmd)
endfu
"}}}1
" Utilities {{{1
fu! s:is_other_shell_pane() abort "{{{2
    let info = system("tmux display -p -t! '#{window_panes}\<c-a>#{pane_current_command}'")[:-2]
    let [number_of_panes, command_in_last_pane] = split(info, "\<c-a>")
    return number_of_panes > 1 && command_in_last_pane =~# '^\%(bash\|dash\|zsh\)$'
endfu

