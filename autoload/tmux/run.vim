vim9 noclear

if exists('loaded') | finish | endif
var loaded = true

# Init {{{1

import Catch from 'lg.vim'
const PROMPT: string = '[$%]\s'

# Interface {{{1
def tmux#run#command(arg_cmd = ''): string #{{{2
    if !exists('$TMUX')
        echo 'requires tmux'
        return ''
    endif

    if arg_cmd == ''
        &opfunc = 'tmux#run#command'
        return 'g@l'
    endif
    # boolean meaning that we've pressed `||`, and we just want to repeat the last command
    var repeat: bool = arg_cmd == 'repeat'
    var cmd: string
    if !repeat
        var cmd_is_actually_type: bool = index(['char', 'line', 'block'], arg_cmd) >= 0
        if cmd_is_actually_type
            cmd = GetCmd()
        else
            cmd = arg_cmd
        endif
        if empty(cmd)
            return ''
        endif
    elseif repeat && last_cmd == ''
        if PreviousPaneRunsShell()
            if IsZoomedWindow()
                UnzoomWindow()
            endif
            sil system('tmux send -t! C-e C-u Up Enter')
        else
            echo 'no command to repeat'
        endif
        return ''
    endif
    # remove `pane_id` if we manually closed the pane associated to it,
    # otherwise the function will think there's no need to create a pane
    ClearStalePaneId()
    # TODO: What if we have run a shell command which has started Vim in the other pane.{{{
    #
    # In that case, `pane_id` will exist and our next command will be sent there.
    # But we don't want that.
    #
    # What should we do?
    # Make Vim quit? But then, what about other fullscreen programs, like cmus, weechat, newsboat...
    # Open another tmux pane? Maybe...
    # Then we need to handle another case:
    #
    #     if pane_id != '' && !PreviousPaneRunsShell()
    #         OpenPaneAndSaveId()
    #     endif
    #
    # It seems like a corner case; is it worth the trouble?
    #}}}
    if pane_id == ''
        # if the previous pane runs a shell, let's use it
        if PreviousPaneRunsShell()
            pane_id = GetPreviousPaneId()
        else
            OpenPaneAndSaveId()
        endif
    endif
    ClosePane('later')
    if repeat
        if IsZoomedWindow()
            UnzoomWindow()
        endif
        RunShellCmd(last_cmd)
    else
        if IsZoomedWindow()
            UnzoomWindow()
        endif
        RunShellCmd(cmd)
        last_cmd = cmd
    endif
    return ''
enddef
var last_cmd: string
var pane_id: string
#}}}1
# Core {{{1
def GetCmd(): string #{{{2
    var cmd: string
    if &ft == 'markdown' && IsInVimFencedCodeblock()
        cmd = GetVimFencedCodeblock()
        if !empty(cmd)
            return cmd
        endif
    endif

    var cml: string = GetCml()
    var cbi: string = GetCodeblockIndent(cml)
    cmd = GetCmdStart(cml, cbi)

    # the command could be split on multiple lines
    var curpos: list<number> = getcurpos()
    if cmd != '' || search('^\s*' .. cml .. cbi .. PROMPT, 'bW') > 0
        cmd = GetMultilineCodeblock(cml, cbi, curpos[1])
        setpos('.', curpos)
    endif

    if cmd == ''
        #                                                            ~/wiki/bug/vim.md
        #                                                       v-------------------------v
        if (&ft == 'vim' || getcwd() == $HOME .. '/wiki/vim' || expand('%:p:t') == 'vim.md')
            && getline('.') =~ '^\s*' .. cml .. cbi
            cmd = GetVimCmd(cml, cbi)
        elseif &ft == 'python'
            cmd = GetPythonCmd()
        endif
    endif

    if cmd == ''
        echo 'no command to run on this line'
    endif
    return cmd
enddef

def GetCml(): string #{{{2
    var cml: string
    if &ft == 'markdown' || &l:cms == ''
        cml = ''
    elseif &ft == 'vim'
        cml = '["#]'
    else
        cml = matchstr(&l:cms, '\S*\ze\s*%s')
        cml = '\V' .. escape(cml, '\') .. '\m'
    endif
    return cml
enddef

def GetCodeblockIndent(cml: string): string #{{{2
    return '\s\{' .. (&ft == 'markdown' || cml == '' ? 4 : 5) .. '}'
enddef

def GetCmdStart(cml: string, cbi: string): string #{{{2
    # Note that we don't exclude the whitespace which follows the `$` or `%` prompt.
    # This will make sure that when the command is run, zsh doesn't log it in its history.
    return getline('.')
        ->matchstr('^\s*' .. cml .. cbi .. PROMPT .. '\zs.*')
enddef

def GetMultilineCodeblock(cml: string, cbi: string, curlnum: number): string #{{{2
    var cmd: string = GetCmdStart(cml, cbi)
    # sanity check
    if cmd == ''
        return ''
    endif
    var end: number = GetEndLnum(cmd, cml)

    # make sure  the code block  which is found  is relevant (i.e.  the original
    # cursor position should be between the start and end of the block)
    if !(curlnum >= line('.') && curlnum <= end)
        cmd = ''
    else
        var lines: list<string> = [cmd] + getline(line('.') + 1, end)
        # A trailing space is needed to preserve a possible alignment.{{{
        #
        # Suppose you press your mapping on this:
        #
        #     $ echo a \
        #            b \
        #            c \
        #            d
        #
        # Without the trailing space, the shell would run this:
        #
        #     $  echo a \
        #     >        b \
        #     >        c \
        #     >        d
        #
        # We want the alignment of `a`, `b`, `c` and `d` to be preserved.
        #}}}
        var trailing_space: string = getline('.') =~ '\\\s*$' ? ' ' : ''
        var indent: string = getline('.')
            ->matchstr('^\s*' .. cml .. '\s*') .. trailing_space
        cmd = map(lines, (_, v) => substitute(v, indent, '', ''))
            ->join("\n")
    endif

    return cmd
enddef

def GetEndLnum(cmd: string, cml: string): number #{{{2
    var end: number = line('.')

    # support continuation lines
    if cmd =~ '\\\s*$'
        end = search('\%(\\\s*\)\@<!$\|\%$', 'nW')

    # support heredoc
    elseif cmd =~ '<<-\=\([''"]\=\)EOF\1'
        end = search('^\s*' .. cml .. '\s*EOF$', 'nW')
        if end == 0
            return 0
        endif
        # support process substitution containing a heredoc
        if getline(end + 1) =~ '^\s*' .. cml .. '\s*)'
            end += 1
        endif
    endif

    return end
enddef

def GetVimCmd(cml: string, cbi: string): string #{{{2
    # We should be able to run some Vim code without writing an explicit heredoc all the time.{{{
    #
    #     " too verbose
    #     ✘
    #     $ vim -Nu NONE -S <(cat <<'EOF'
    #         vim9
    #         def g:Func()
    #             echo 'before error'
    #             invalid
    #             echo 'after error'
    #         enddef
    #     EOF
    #     )
    #
    #     ✔
    #     vim9
    #     def g:Func()
    #         echo 'before error'
    #         invalid
    #         echo 'after error'
    #     enddef
    #}}}

    var curpos: list<number> = getcurpos()
    # To find the starting line of the block, we first look for the nearest line
    # *outside* the block.  Then, we look for the nearest line *inside* the block.
    var outside: string
    var inside: string
    if &ft == 'markdown' || cml == ''
        # Why do you check for a non-whitespace at the end of the first branch?{{{
        #
        # So that we can find a code which contains empty commented lines.
        #}}}
        # Why do you check for a tilde at the end of the second branch?{{{
        #
        # To stop at an output line.
        #
        # This is useful to write 2 blocks of code separated by output lines and
        # be able  to run the second  block without the first  one being wrongly
        # merged with the output lines.  Example:
        #
        #     vim9
        #     def FuncA()
        #         def FuncB()
        #         enddef
        #     enddef
        #     FuncB()
        #
        #     E117: Unknown function: FuncB~
        #
        #     vim9
        #     def FuncA()
        #         def FuncB()
        #         enddef
        #         FuncB()
        #     enddef
        #     FuncA()
        #     ✔
        #}}}
        outside = '^\%(\s\{4}\)\@!.*\S\|\~$'
        # Why `[:"#]`?{{{
        #
        # We  need to  ignore a  colon because  we usually  use it  as a  prompt
        # denoting an Ex command which must be executed interactively.
        #
        # We also need to ignore a commented line.
        # Otherwise, we could run some Ex command prefixed by a colon, which was
        # meant to be executed interactively.  It can happen if we have a mix of
        # interactive Ex commands and Vim comments.
        #}}}
        # Why `\zs`?{{{
        #
        # To be able to inspect the syntax  item at the start of where the found
        # code block is supposed to be.  This is necessary for the next `l:Skip`
        # expression to work as expected.
        #}}}
        inside = '^\s\{4,}\zs\%(' .. PROMPT .. '\|[:"#]\)\@!'
    else
        outside = '^\s*' .. cml .. '\%(\s\{5}\)\@!.*\S\|^\s*$\|\~$'
        inside = '^\s*' .. cml .. '\s\{5,}\%(' .. PROMPT .. '\)\@!\zs\S'
    endif
    search(outside .. '\|\%^', 'bW')
    # Why the `{skip}` lambda expression?{{{
    #
    # To ignore  false positives, like  some output, or  list item, and  to make
    # sure we land on a code block.
    #}}}
    var Skip: func = (): bool => !IsInCodeblock()
    var start: number = search(inside, 'W', 0, 500, Skip)
    search(outside .. '\|\%$', 'W')
    var end: number = search(inside, 'bW', 0, 500, Skip)
    setpos('.', curpos)
    if !start || !end
        return ''
    endif

    # check the validity of the code block (i.e. it should contain the original line)
    if !(curpos[1] >= line('.') && curpos[1] <= end)
        return ''
    endif

    var startline: string = getline(start)
    # There should not be the start of a heredoc on the first line.{{{
    #
    # If we're  here, it  means that we  didn't find a  command starting  with a
    # prompt.  If we allow the code to proceed, we allow a Vim + heredoc command
    # without prompt.  But only  in a Vim file or in the Vim  wiki; *not* in the
    # other wikis.
    #
    # This  would  be inconsistent.   We  should  be  able  to omit  the  prompt
    # everywhere  or  nowhere.   Let's  choose  nowhere.  If  we  made  it  work
    # everywhere, it  would create another  inconsistency.  We would be  able to
    # omit the  prompt for  all Vim commands  using a heredoc,  but not  for the
    # other commands (e.g. `cat(1)`).
    #}}}
    if startline =~# '<<-\=\([''"]\=\)EOF\1'
        return ''
    endif
    var whole_indent: string = matchstr(startline, '^\s*' .. cml .. cbi)
    var lines: list<string> = getline(start, end)
    var cmd: list<string> = map(lines, (_, v) =>
        substitute(v, whole_indent .. '\|^\s*' .. cml .. '$', '', ''))
    cmd = Vimify(cmd)
    return join(cmd, "\n")
enddef

def GetVimFencedCodeblock(): string #{{{2
    var start: number = search('^```vim', 'bcnW')
    if !start
        return ''
    endif
    start += 1

    var curpos: list<number> = getcurpos()
    norm! 0
    var end: number = search('```$', 'cnW')
    setpos('.', curpos)
    if !end
        return ''
    endif
    end -= 1

    var curlnum: number = line('.')
    if !(curlnum >= start && curlnum <= end)
        return ''
    endif

    var cmd: list<string> = getline(start, end)
    cmd = Vimify(cmd)
    return join(cmd, "\n")
enddef

def GetPythonCmd(): string #{{{2
    sil! update
    sil system('python3 -m py_compile ' .. expand('%:p:S'))
    return 'cd ' .. expand('%:p:h:S') .. ' && python3 ' .. expand('%:p:t:S')
enddef

def Vimify(cmd: list<string>): list<string> #{{{2
    return [" vim -Nu NONE -S <(cat <<'EOF'"] + cmd + ['EOF', ')']
enddef

def ClearStalePaneId() #{{{2
    if pane_id == ''
        return
    endif
    sil var open_panes: list<string> = systemlist("tmux lsp -F '#D'")
    var is_pane_still_open: bool = index(open_panes, pane_id) >= 0
    if !is_pane_still_open
        # the pane should be closed, but better be safe
        sil system('tmux killp -t ' .. pane_id)
        pane_id = ''
    endif
enddef

def OpenPaneAndSaveId() #{{{2
    var cmds: list<string> = [
        'splitw -c',
        shellescape('/run/user/1000/tmp'),
        '-d -p 25 -PF "#D"'
        ]
    sil pane_id = system('tmux ' .. join(cmds))->trim("\n", 2)
enddef

def ClosePane(when: string) #{{{2
    if when == 'later'
        augroup TmuxRunCmdClosePane | au!
            # Is it ok to remove *all* autocmds?{{{
            #
            # For the moment, yes.
            # I don't intend to have more than one pane open at a time.
            #
            # If you  want more granularity, you  could remove `au!`, and  add a
            # bang after all the next `:au` commands (`au` → `au!`).
            #
            # If you  want to check whether  the autocmds are duplicated,  run a
            # command, close its pane, then re-run the command.
            #}}}
            au VimLeave * ClosePane('now')
            au BufWinLeave <buffer> ClosePane('now')
        augroup END
    else
        try
            sil system('tmux killp -t ' .. pane_id)
            [pane_id, last_cmd] = ['', '']
            au! TmuxRunCmdClosePane
        catch
            Catch()
            return
        endtry
    endif
enddef

def RunShellCmd(arg_cmd: string) #{{{2
    var clear: string
    if PaneIsRunningVim()
        # `C-\ C-n` doesn't work at the more prompt, nor in a confirmation prompt (e.g. `s/pat/rep/c`).{{{
        #
        # Don't try to include the key with the other ones and use a single `$ tmux send ...`.
        # For some reason, it doesn't (always?) work.
        #}}}
        sil system('tmux send -t ' .. pane_id .. ' C-c')
        clear = 'tmux send -t ' .. pane_id .. ' C-\\ C-n :qa! Enter'
    else
        # Why `ZQ`?{{{
        #
        # In  case  `PaneIsRunningVim()`  failed  to detect  that  Vim  was
        # running in the pane.  That can happen, for example, if we've run:
        #
        #     $ git diff 2>&1 | vipe >/dev/null
        #
        # Obviously, `ZQ`  is not perfect;  there could  be more than  1 window.
        # But we can't  press `:qa! Enter`; if Vim is really  not running in the
        # pane, that  would cause `qa!`  to be  run which could  have unexpected
        # side-effects.
        #}}}
        # Why not `C-e C-u`?{{{
        #
        # The command-line could contain several lines of code (e.g. heredoc).
        # In that case, `C-e C-u` would only clear the current line, not the other ones.
        #}}}
        #   Ok, and what does `C-x C-k` do?{{{
        #
        # It clears the whole command-line, no  matter how many lines of code it
        # contains, or where the cursor is.
        #
        # It  works  only   because  we  bind  `C-x  C-k`  to   the  zle  widget
        # `kill-buffer` in our zshrc.  See `man zshzle /kill-buffer`.
        #}}}
        clear = 'tmux send -t ' .. pane_id .. ' ZQ C-x C-k'
    endif
    sil system(clear)

    var cmd: string = substitute(arg_cmd, '\\\s\+$', '\', '')
    # https://github.com/jebaum/vim-tmuxify/issues/16
        ->substitute('\t', ' ', 'g')
    # Make sure a trailing semicolon is correctly sent.{{{
    #
    # ... and not parsed as a command termination.
    #
    # https://github.com/tmux/tmux/issues/1849
    # https://github.com/jebaum/vim-tmuxify/issues/11
    #}}}
    if cmd[-1] == ';'
        cmd = cmd[: -2] .. '\;'
    endif
    var tempfile: string = tempname()
    split(cmd, '\n')->writefile(tempfile, 'b')

    var tmux_cmd: string = 'tmux loadb -b barx ' .. tempfile
        .. ' \; pasteb -d -p -b barx -t ' .. pane_id
        .. ' \; send -t ' .. pane_id .. ' C-m'

    # `C-c` is not always instantaneous.
    # Sometimes, Vim needs one second or two; that can happen when some errors are raised.
    if !PaneIsRunningVim()
        # Many lines are prefixed with a weird prompt!{{{
        #
        #     heredoc>
        #     cmdsubst>
        #     cmdsubst heredoc>
        #
        # Not much you can do.
        #
        # You could get rid of them by adding a `:sleep 200m` before `$ tmux pasteb`;
        # but for some reason, it would take more time for the command to be executed.
        # Although,  you should  only see  a difference  for huge  commands (several
        # hundreds of lines).
        #}}}
        sil system(tmux_cmd)
    else
        timer_start(2'000, () => system(tmux_cmd))
    endif
enddef
#}}}1
# Utilities {{{1
def IsInVimFencedCodeblock(): bool #{{{2
    return synstack('.', col('.'))
        ->mapnew((_, v) => synIDattr(v, 'name'))
        ->match('\cmarkdownHighlightvim') == 0
enddef

def IsInCodeblock(): bool #{{{2
    # Note that you can't just check that the pattern `codeblock` matches one of the syntax items:{{{
    #
    #     \ ->match('\ccodeblock') != -1
    #
    # It must match the last one:
    #
    #     \ ->reverse()
    #     \ ->match('\ccodeblock') == 0
    #
    # Indeed, for example, on an output line, here is the stack of syntax items:
    #
    #     ['markdownCodeBlock', 'markdownOutput']
    #
    # It  *does* contain  the pattern  `codeblock`, but  not at  the end  of the
    # stack, which is the only relevant place.
    #}}}
    return synstack('.', col('.'))
        ->mapnew((_, v) => synIDattr(v, 'name'))
        ->reverse()
        ->match('\ccodeblock') == 0
enddef

def PreviousPaneRunsShell(): bool #{{{2
    sil var number_of_panes: number = system("tmux display -p '#{window_panes}'")
        ->trim("\n", 2)
        ->str2nr()
    if number_of_panes < 2
        return false
    endif

    # TODO: What if we have run `$ echo text | vim -` in the previous pane.{{{
    #
    #     $ tmux display -p -t! '#{pane_current_command}'
    #     zsh~
    #
    # Maybe we should also make sure that `[No Name]` can't be found in the pane.
    # If it  can, Vim  is probably  running, and  we don't  want our  next shell
    # command to be written there.
    #
    # Note that – I think – you need to escape the brackets:
    #
    #     $ tmux display -p -t! '#{C:\[No Name\]}'
    #
    # Otherwise you can get weird results:
    #
    #     # open xterm
    #     $ tmux -Lx
    #     $ tmux splitw
    #     $ vim
    #     :lastp
    #     $ tmux display -p -t! '#{C:[No Name]}'
    #     10~
    #     $ tmux lastp
    #     :q
    #     $ tmux lastp
    #     $ tmux display -p -t! '#{C:[No Name]}'
    #     2~
    #
    # The last command should output 0.
    #
    # I haven't  tried to  implement this  for the moment,  because last  time I
    # tried, I got unexpected and inconsistent results.
    # Besides, it seems like a corner case; is it worth the trouble?
    #}}}
    sil sil var cmd_in_previous_pane: string =
        system("tmux display -p -t! '#{pane_current_command}'")
        ->trim("\n", 2)
    return cmd_in_previous_pane =~ '^\%(bash\|dash\|zsh\)$'
enddef

def GetPreviousPaneId(): string #{{{2
    sil return system("tmux display -p -t! '#{pane_id}'")
        ->trim("\n", 2)
enddef

def IsZoomedWindow(): bool #{{{2
    sil return system('tmux display -p "#{window_zoomed_flag}"')
        ->trim("\n", 2)
        ->str2nr() ? true : false
enddef

def UnzoomWindow() #{{{2
    sil system('tmux resizep -Z')
enddef

def PaneIsRunningVim(): bool
    # Warning: cannot detect `vipe(1)`, because in that case, `#{pane_current_command}` is `zsh`.
    var cmd: string =
        'tmux display -t ' .. pane_id .. ' -p "#{m:*vim,#{pane_current_command}}"'
    return systemlist(cmd)[0]->str2nr() ? true : false
enddef

