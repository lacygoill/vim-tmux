if exists('g:autoloaded_tmux#run')
    finish
endif
let g:autoloaded_tmux#run = 1

" Init {{{1

const s:SIGIL = '[$%]'

" Interface {{{1
fu tmux#run#command(...) abort "{{{2
    if !exists('$TMUX') | echo 'requires tmux' | return | endif
    if !a:0
        let &opfunc = 'tmux#run#command'
        return 'g@l'
    endif
    " flag meaning that we've pressed `||`, and we just want to repeat the last command
    let repeat = a:1 is# 'repeat'
    if !repeat
        let cmd = s:get_cmd()
        if empty(cmd) | return | endif
    elseif repeat && !exists('s:last_cmd')
        if s:previous_pane_runs_shell()
            if s:is_zoomed_window() | call s:unzoom_window() | endif
            sil call system('tmux send -t! C-e C-u Up Enter')
        else
            echo 'no command to repeat'
        endif
        return
    endif
    " remove `s:pane_id` if we manually closed the pane associated to it,
    " otherwise the function will think there's no need to create a pane
    call s:clear_stale_pane_id()
    " TODO: What if we have run a shell command which has started Vim in the other pane.{{{
    "
    " In that case,  `s:pane_id` will exist and our next command will be sent there.
    " But we don't want that.
    "
    " What should we do?
    " Make Vim quit? But then, what about other fullscreen programs, like cmus, weechat, newsboat...
    " Open another tmux pane? Maybe...
    " Then we need to handle another case:
    "
    "     if exists('s:pane_id') && !s:previous_pane_runs_shell()
    "         call s:open_pane_and_save_id()
    "     endif
    "
    " It seems like a corner case; is it worth the trouble?
    "}}}
    if !exists('s:pane_id')
        " if the previous pane runs a shell, let's use it
        if s:previous_pane_runs_shell()
            let s:pane_id = s:get_previous_pane_id()
        else
            call s:open_pane_and_save_id()
        endif
    endif
    call s:close_pane('later')
    if repeat
        if s:is_zoomed_window() | call s:unzoom_window() | endif
        call s:run_shell_cmd(s:last_cmd)
    else
        if s:is_zoomed_window() | call s:unzoom_window() | endif
        call s:run_shell_cmd(cmd)
        let s:last_cmd = cmd
    endif
endfu
"}}}1
" Core {{{1
fu s:get_cmd() abort "{{{2
    if &ft is# 'markdown' && s:is_in_vim_fenced_codeblock()
        let cmd = s:get_vim_fenced_codeblock()
        if !empty(cmd) | return cmd | endif
    endif

    let cml = s:get_cml()
    let cbi = s:get_codeblock_indent(cml)
    let cmd = s:get_cmd_start(cml, cbi)

    " the command could be split on multiple lines
    let curpos = getcurpos()
    if cmd != '' || search('^\s*' .. cml .. cbi .. s:SIGIL, 'bW')
        let cmd = s:get_multiline_codeblock(cml, cbi, curpos[1])
        call setpos('.', curpos)
    endif

    if cmd == ''
        if (&ft is# 'vim' || getcwd() is# $HOME..'/wiki/vim') && getline('.') =~# '^\s*' .. cml .. cbi
            let cmd = s:get_vim_cmd(cml, cbi)
        elseif &ft is# 'python'
            let cmd = s:get_python_cmd()
        endif
    endif

    if cmd == '' | call s:error() | endif
    return cmd
endfu

fu s:get_cml() abort "{{{2
    if &ft is# 'markdown' || &l:cms == ''
        let cml = ''
    elseif &ft is# 'vim'
        let cml = '["#]'
    else
        let cml = matchstr(&l:cms, '\S*\ze\s*%s')
        let cml = '\V'..escape(cml, '\')..'\m'
    endif
    return cml
endfu

fu s:get_codeblock_indent(cml) abort "{{{2
    return '\s\{'..(&ft is# 'markdown' || a:cml is# '' ? 4 : 5)..'}'
endfu

fu s:get_cmd_start(cml, cbi) abort "{{{2
    " Note that we don't exclude the whitespace which follows the sigil.
    " This will make sure that when the command is run, zsh doesn't log it in its history.
    return getline('.')->matchstr('^\s*' .. a:cml .. a:cbi .. s:SIGIL .. '\zs\s.*')
endfu

fu s:get_multiline_codeblock(cml, cbi, curlnum) abort "{{{2
    let cmd = s:get_cmd_start(a:cml, a:cbi)
    let end = s:get_end_lnum(cmd, a:cml)

    " make sure  the code block  which is found  is relevant (i.e.  the original
    " cursor position should be between the start and end of the block)
    if !(a:curlnum >= line('.') && a:curlnum <= end)
        let cmd = ''
    else
        let lines = [cmd] + getline(line('.') + 1, end)
        " A trailing space is needed to preserve a possible alignment.{{{
        "
        " Suppose you press your mapping on this:
        "
        "     $ echo a \
        "            b \
        "            c \
        "            d
        "
        " Without the trailing space, the shell would run this:
        "
        "     $  echo a \
        "     >        b \
        "     >        c \
        "     >        d
        "
        " We want the alignment of `a`, `b`, `c` and `d` to be preserved.
        "}}}
        let trailing_space = getline('.') =~# '\\\s*$' ? ' ' : ''
        let indent = getline('.')->matchstr('^\s*'..a:cml..'\s*') .. trailing_space
        let cmd = map(lines, {_,v -> substitute(v, indent, '', '')})->join("\n")
    endif

    return cmd
endfu

fu s:get_end_lnum(cmd, cml) abort "{{{2
    let end = line('.')

    " support continuation lines
    if a:cmd =~# '\\\s*$'
        let end = search('\%(\\\s*\)\@<!$\|\%$', 'nW')

    " support heredoc
    elseif a:cmd =~# '<<-\=\([''"]\=\)EOF\1'
        let end = search('^\s*'..a:cml..'\s*EOF$', 'nW')
        if !end | return '' | endif
        " support process substitution containing a heredoc
        if getline(end + 1) =~# '^\s*'..a:cml..'\s*)'
            let end += 1
        endif
    endif

    return end
endfu

fu s:get_vim_cmd(cml, cbi) abort "{{{2
    " We should be able to run some Vim code without writing an explicit heredoc all the time.{{{
    "
    "     " too verbose
    "     ✘
    "     $ vim -Nu NONE -S <(cat <<'EOF'
    "         vim9script
    "         def g:Func()
    "             echo 'before error'
    "             invalid
    "             echo 'after error'
    "         enddef
    "     EOF
    "     )
    "
    "     ✔
    "     vim9script
    "     def g:Func()
    "         echo 'before error'
    "         invalid
    "         echo 'after error'
    "     enddef
    "}}}

    let curpos = getcurpos()
    " To find the starting line of the block, we first look for the nearest line
    " *outside* the block.  Then, we look for the nearest line *inside* the block.
    if &ft is# 'markdown' || a:cml is# ''
        " Why do you check for a non-whitespace at the end of the first branch?{{{
        "
        " So that we can find a code which contains empty commented lines.
        "}}}
        " Why do you check for a tilde at the end of the second branch?{{{
        "
        " To stop at an output line.
        "
        " This is useful to write 2 blocks of code separated by output lines and
        " be able  to run the second  block without the first  one being wrongly
        " merged with the output lines.  Example:
        "
        "     vim9script
        "     def FuncA()
        "         def FuncB()
        "         enddef
        "     enddef
        "     FuncB()
        "
        "     E117: Unknown function: FuncB~
        "
        "     vim9script
        "     def FuncA()
        "         def FuncB()
        "         enddef
        "         FuncB()
        "     enddef
        "     FuncA()
        "     ✔
        "}}}
        let outside = '^\%(\s\{4}\)\@!.*\S\|\~$'
        " Why `[:"#]`?{{{
        "
        " We  need to  ignore a  colon  because we  usually  use it  as a  sigil
        " denoting an Ex command which must be executed interactively.
        "
        " We also need to ignore a commented line.
        " Otherwise, we could run some Ex command prefixed by a colon, which was
        " meant to be executed interactively.  It can happen if we have a mix of
        " interactive Ex commands and Vim comments.
        "}}}
        " Why `\zs`?{{{
        "
        " To be able to inspect the syntax  item at the start of where the found
        " code block is supposed to be.  This is necessary for the next `l:Skip`
        " expression to work as expected.
        "}}}
        let inside = '^\s\{4,}\zs\%(' .. s:SIGIL .. '\|[:"#]\)\@!'
    else
        let outside = '^\s*' .. a:cml .. '\%(\s\{5}\)\@!.*\S\|^\s*$\|\~$'
        let inside = '^\s*' .. a:cml .. '\s\{5,}\%(' .. s:SIGIL .. '\)\@!\zs\S'
    endif
    call search(outside .. '\|\%^', 'bW')
    " Why the `{skip}` lambda expression?{{{
    "
    " To ignore  false positives, like  some output, or  list item, and  to make
    " sure we land on a code block.
    "}}}
    let l:Skip = {-> !s:is_in_codeblock()}
    let start = search(inside, 'W', 0, 500, l:Skip)
    call search(outside .. '\|\%$', 'W')
    let end = search(inside, 'bW', 0, 500, l:Skip)
    call setpos('.', curpos)
    if !start || !end | return '' | endif

    " check the validity of the code block (i.e. it should contain the original line)
    if !(curpos[1] >= line('.') && curpos[1] <= end)
        return ''
    endif

    let startline = getline(start)
    " There should not be the start of a heredoc on the first line.{{{
    "
    " If we're here, it means that we didn't find a command starting with a sigil.
    " If we allow the code to proceed,  we allow a Vim + heredoc command without
    " sigil.  But only in a Vim file or in the Vim wiki; *not* in the other wikis.
    "
    " This  would  be  inconsistent.   We  should be  able  to  omit  the  sigil
    " everywhere  or  nowhere.   Let's  choose  nowhere.  If  we  made  it  work
    " everywhere, it  would create another  inconsistency.  We would be  able to
    " omit the sigil for all Vim commands using a heredoc, but not for the other
    " commands (e.g. `cat(1)`).
    "}}}
    if startline =~# '<<-\=\([''"]\=\)EOF\1'
        return ''
    endif
    let whole_indent = matchstr(startline, '^\s*' .. a:cml .. a:cbi)
    let lines = getline(start, end)
    let cmd = map(lines, {_,v -> substitute(v, whole_indent .. '\|^\s*' .. a:cml .. '$', '', '')})
    let cmd = s:vimify(cmd)
    return join(cmd, "\n")
endfu

fu s:get_vim_fenced_codeblock() abort "{{{2
    let start = search('^```vim', 'bnW')
    if !start | return '' | endif
    let start += 1

    let curpos = getcurpos()
    norm! 0
    let end = search('```$', 'cnW')
    call setpos('.', curpos)
    if !end | return '' | endif
    let end -= 1

    let curlnum = line('.')
    if !(curlnum >= start && curlnum <= end)
        return ''
    endif

    let cmd = getline(start, end)
    let cmd = s:vimify(cmd)
    return join(cmd, "\n")
endfu

fu s:get_python_cmd() abort "{{{2
    sil! update
    sil call system('python3 -m py_compile '..expand('%:p:S'))
    return 'cd '..expand('%:p:h')->shellescape()..' && python3 '..expand('%:p:t:S')
endfu

fu s:vimify(cmd) abort "{{{2
    return [" vim -Nu NONE -S <(cat <<'EOF'"] + a:cmd + ['EOF', ')']
endfu

fu s:clear_stale_pane_id() abort "{{{2
    if !exists('s:pane_id') | return | endif
    sil let open_panes = systemlist("tmux lsp -F '#D'")
    let is_pane_still_open = index(open_panes, s:pane_id) >= 0
    if !is_pane_still_open
        " the pane should be closed, but better be safe
        sil call system('tmux killp -t '..s:pane_id)
        unlet! s:pane_id
    endif
endfu

fu s:open_pane_and_save_id() abort "{{{2
    let cmds = [
        \ 'splitw -c',
        \ shellescape('/run/user/1000/tmp'),
        \ '-d -p 25 -PF "#D"'
        \ ]
    sil let s:pane_id = system('tmux '..join(cmds))[:-2]
endfu

fu s:close_pane(when) abort "{{{2
    if a:when is# 'later'
        augroup tmux_run_cmd_close_pane | au!
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
            au VimLeave * call s:close_pane('now')
            au BufWinLeave <buffer> call s:close_pane('now')
        augroup END
    else
        try
            sil call system('tmux killp -t '..s:pane_id)
            unlet! s:pane_id s:last_cmd
            au! tmux_run_cmd_close_pane
        catch
            return lg#catch()
        endtry
    endif
endfu

fu s:run_shell_cmd(cmd) abort "{{{2
    let pane_is_running_vim = systemlist('tmux display -t ' .. s:pane_id .. ' -p "#{m:*vim,#{pane_current_command}}"')[0]
    if pane_is_running_vim
        " `C-\ C-n` doesn't work at the more prompt.{{{
        "
        " We need `G` or `q` to quit it.
        " We don't use `q`, because I'm not sure `C-\\ C-n` would work afterward
        " if we're in visual mode for example.
        "
        " ---
        "
        " Don't try to include the key with the other ones and use a single `$ tmux send ...`.
        " For some reason, it doesn't work.
        "}}}
        sil call system('tmux send -t '..s:pane_id..' G')
        let clear = 'tmux send -t '..s:pane_id..' C-\\ C-n :qa! Enter'
    else
        let clear = 'tmux send -t '..s:pane_id..' C-e C-u'
    endif
    sil call system(clear)

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
    if cmd[-1:] is# ';' | let cmd = cmd[:-2]..'\;' | endif
    let tempfile = tempname()
    call split(cmd, '\n')->writefile(tempfile, 'b')

    " Many lines are prefixed with a weird prompt!{{{
    "
    "     heredoc>
    "     cmdsubst>
    "     cmdsubst heredoc>
    "
    " Not much you can do.
    "
    " You could get rid of them by adding a `:sleep 200m` before `$ tmux pasteb`;
    " but for some reason, it would take more time for the command to be executed.
    " Although,  you should  only see  a difference  for huge  commands (several
    " hundreds of lines).
    "}}}
    sil call system('tmux loadb -b barx '..tempfile
      \ .. ' \; pasteb -d -p -b barx -t '..s:pane_id
      \ .. ' \; send -t '..s:pane_id..' C-m'
      \ )
endfu
"}}}1
" Utilities {{{1
fu s:is_in_vim_fenced_codeblock() abort "{{{2
    return synstack(line('.'), col('.'))
        \ ->map('synIDattr(v:val, "name")')
        \ ->match('\cmarkdownHighlightvim') == 0
endfu

fu s:is_in_codeblock() abort "{{{2
    " Note that you can't just check that the pattern `codeblock` matches one of the syntax items:{{{
    "
    "     \ ->match('\ccodeblock') != -1
    "
    " It must match the last one:
    "
    "     \ ->reverse()
    "     \ ->match('\ccodeblock') == 0
    "
    " Indeed, for example, on an output line, here is the stack of syntax items:
    "
    "     ['markdownCodeBlock', 'markdownOutput']
    "
    " It  *does* contain  the pattern  `codeblock`, but  not at  the end  of the
    " stack, which is the only relevant place.
    "}}}
    return synstack(line('.'), col('.'))
        \ ->map('synIDattr(v:val, "name")')
        \ ->reverse()
        \ ->match('\ccodeblock') == 0
endfu

fu s:error() abort "{{{2
    echo 'no command to run on this line'
endfu

fu s:previous_pane_runs_shell() abort "{{{2
    sil let number_of_panes = system("tmux display -p '#{window_panes}'")[:-2]
    if number_of_panes < 2 | return 0 | endif

    " TODO: What if we have run `$ echo text | vim -` in the previous pane.{{{
    "
    "     $ tmux display -p -t! '#{pane_current_command}'
    "     zsh~
    "
    " Maybe we should also make sure that `[No Name]` can't be found in the pane.
    " If it  can, Vim  is probably  running, and  we don't  want our  next shell
    " command to be written there.
    "
    " Note that – I think – you need to escape the brackets:
    "
    "     $ tmux display -p -t! '#{C:\[No Name\]}'
    "
    " Otherwise you can get weird results:
    "
    "     # open xterm
    "     $ tmux -Lx
    "     $ tmux splitw
    "     $ vim
    "     :lastp
    "     $ tmux display -p -t! '#{C:[No Name]}'
    "     10~
    "     $ tmux lastp
    "     :q
    "     $ tmux lastp
    "     $ tmux display -p -t! '#{C:[No Name]}'
    "     2~
    "
    " The last command should output 0.
    "
    " I haven't  tried to  implement this  for the moment,  because last  time I
    " tried, I got unexpected and inconsistent results.
    " Besides, it seems like a corner case; is it worth the trouble?
    "}}}
    sil let cmd_in_previous_pane = system("tmux display -p -t! '#{pane_current_command}'")[:-2]
    return cmd_in_previous_pane =~# '^\%(bash\|dash\|zsh\)$'
endfu

fu s:get_previous_pane_id() abort "{{{2
    sil return system("tmux display -p -t! '#{pane_id}'")[:-2]
endfu

fu s:is_zoomed_window() abort "{{{2
    sil return system('tmux display -p "#{window_zoomed_flag}"')[:-2]
endfu

fu s:unzoom_window() abort "{{{2
    sil call system('tmux resizep -Z')
endfu

