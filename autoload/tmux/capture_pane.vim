vim9 noclear

if exists('loaded') | finish | endif
var loaded = true

const SFILE = expand('<sfile>:p')

# Interface {{{1
def tmux#capture_pane#main() #{{{2
    # Purpose:{{{
    #
    # This function is called by a tmux key binding.
    #
    # It makes tmux copy the contents of the pane, from the start of the history
    # down to the end of the visible pane, in a tmux buffer.
    # Then, it makes Vim read this tmux buffer.
    #
    # If you create a new tmux window and run `$ ls ~`, the tmux buffer contains
    # a lot of empty lines at the bottom; we don't want them.
    #
    # Besides, the tmux buffer contains a lot of trailing whitespace, because we
    # need to pass `-J` to `capture-pane`; we don't want them either.
    #
    # This function  tries to remove  all trailing whitespace, and  all trailing
    # empty lines at the end of the Vim buffer.
    #
    # ---
    #
    # Also, it tries to ease the process of copying text in Vim, then pasting it
    # in the shell; see the one-shot autocmd at the end.
    #}}}

    # we don't want folding to interfere in the next editions
    setl nofen

    sil! TW
    cursor('$', 1)
    search('^\S', 'bW')
    sil keepj keepp :.,$g/^\s*$/d _

    var pat_cmd = '\m\C/MSG\s\+.\{-}XDCC\s\+SEND\s\+\d\+'
    # Format the buffer if it contains commands to downloads files via xdcc.{{{
    #
    # Remove noise.
    # Conceal xdcc commands.
    # Highlight filenames.
    # Install mappings to copy the xdcc command in the clipboard.
    #}}}
    # Why `!search('│')`?{{{
    #
    # The code will work  best after we have pressed our  WeeChat key binding to
    # get a bare display (`M-r` atm), where “noise” has been removed.
    # Indeed, with  noise, some xdcc commands  can't be copied in  one pass, but
    # only in two.
    # So,  if we're  not  in  a bare  window,  I don't  want  to  get the  false
    # impression that the buffer can be interacted with reliably.
    #}}}
    if search(pat_cmd) > 0 && search('│') == 0
        FormatXdccBuffer(pat_cmd)
    elseif search('^٪') > 0
        FormatShellBuffer()
    endif

    # Do *not* change the name of the augroup.{{{
    #
    # We already have a similar autocmd in our vimrc.
    # I don't want it to interfere.
    # I don't want a race condition where the winning `xsel(1x)` process is the last one.
    # So, I want this autocmd to replace the one in the vimrc.
    # It's probably unnecessary but better be safe than sorry.
    #}}}
    augroup MakeClipboardPersistAfterQuittingVim | au!
        # Do *not* use the pattern `<buffer>`!{{{
        #
        # Atm, we open the qf window.
        # If you use `<buffer>`, the autocmd would be installed for the qf buffer.
        # But if we copy some text, it will probably be in the other buffer.
        # Anyway, no matter the buffer where we copy some text, we want it in `xsel(1x)`.
        #}}}
        # Do *not* use `xclip(1)` instead of `xsel(1x)`!{{{
        #
        # It would not work.
        #
        # MWE:
        #
        #     $ tmux -Lx -f/dev/null new
        #     $ tmux splitw vim -Nu NONE
        #     :call system('xclip -selection clipboard', 'hello')
        #     :q
        #     C-S-v
        #     ''~
        #     $ xclip -selection clipboard -o
        #     Error: target STRING not available~
        #
        # It seems that the `xclip(1)` process is killed when we quit Vim, if the latter
        # has been started by tmux instead of being directly started by the shell.
        #
        # I don't understand the cause of the issue.
        # If you press `C-b ;` before quitting Vim, to focus back the pane where a shell
        # is running, and execute `$ pidof xclip`, you'll get a pid.
        # And if you use this pid in `$ pstree -lsp PID`, you'll get sth like this:
        #
        #     systemd(1)---lightdm(1008)---lightdm(1088)---upstart(1097)---xclip(12973)
        #
        # There's no  Vim or tmux  process in the parents  of `xclip(1)`, so  the latter
        # shouldn't care about what happens to the Vim process...
        #
        # See also: https://unix.stackexchange.com/q/523255/289772
        #
        # ---
        #
        # If you wanted to  use `xclip(1)` from Vim, you would  need to start it
        # without a shell.  First, you could write the text in a file:
        #
        #     var tempfile = tempname()
        #     split(@", '\n')->writefile(tempfile, 'b')
        #
        # Then you could run:
        #
        #     job_start('xclip -selection clipboard ' .. tempfile)
        #
        # Why writing the text in a file?
        # Without a file, you would need a pipe; and a pipe can only be parsed by a shell.
        # But remember that we need to avoid a shell to be spawned.
        # So, no shell → no pipe → use a file.
        #
        # However, for some  reason, the job can't be started  from an autocmd listening
        # to `VimLeave(Pre)`;  so, you would  need to make  your autocmd listen  to some
        # other event like `TextYankPost`.
        #}}}
        au VimLeave * if executable('xsel') && strlen(@+) != 0 && strlen(@+) <= 999
            |     sil system('xsel -ib', @+)
            | endif
    augroup END

    setl fen

    if !exists('b:repeatable_motions')
        return
    endif
    # The buffer might be wrongly highlighted as a conf file.{{{
    #
    # That happens  if one of the  first lines start  with `#`, and we  save the
    # buffer in a file in `/tmp`.
    #
    # We don't  have this issue  with a  pseudo-file in `/proc/`,  because we've
    # configured Vim to ignore the filetype detection of such files:
    #
    #     g:ft_ignore_pat = '\.\%(Z\|gz\|bz2\|zip\|tgz\|log\)$\|^/proc/'
    #                                                           ^-----^
    #}}}
    setl ft=
enddef
#}}}1
# Core {{{1
def FormatXdccBuffer(pat_cmd: string) #{{{2
    # remove noise
    exe 'sil keepj keepp v@' .. pat_cmd .. '@d _'
    sil keepj keepp :%s/^.\{-}\d\+)\s*//e

    # align the first 3 fields{{{
    #
    # Don't align beyond the third field; a bot name may contain a bar.
    # As a result, if  you align beyond the third field, you  may break the xdcc
    # command we're going to copy.
    #}}}
    if executable('sed') && executable('column')
        # prepend the first three occurrences of a bar with a literal C-a
        sil :%!sed 's/|/\x01|/1; s/|/\x01|/3'
        # sort the text using the C-a's as delimiters
        sil :%!column -s $'\x01' -t
    endif
    # `:EasyAlign` alternative:{{{
    #
    #     sil %EasyAlign | {'align': 'lll'}
    #
    # For more info about the syntax of this `:EasyAlign` command,
    # see `:h easy-align-6-7`.
    #}}}

    # highlight filenames
    var pat_file = '\d\+x\s*|\s*[0-9.KMG]*\s*|\s*\zs\S*'
    matchadd('Underlined', pat_file, 0)

    # conceal commands
    matchadd('Conceal', pat_cmd .. '\s*|\s*', 0)
    setl cole=3 cocu=nc

    # make filenames interactive{{{
    #
    # You don't need  `"+y`.
    # `y` is enough, provided that the next one-shot autocmd is installed.
    #}}}
    nno <buffer><nowait> <cr> <cmd>call <sid>CopyCmdToGetFileViaXdcc()<cr>
    nmap <buffer><nowait> ZZ <cr>

    # let us jump from one filename to another by pressing `n` or `N`
    setreg('/', [pat_file], 'c')
enddef

def FormatShellBuffer() #{{{2
    noremap <buffer><expr><nowait> [c brackets#move#regex('shell_prompt', 0)
    noremap <buffer><expr><nowait> ]c brackets#move#regex('shell_prompt', 1)
    sil! repmap#make#repeatable({
        mode: '',
        buffer: true,
        from: SFILE .. ':' .. expand('<sflnum>'),
        motions: [{bwd: '[c', fwd: ']c'}]
        })
    # We might need to run `set ft=`, which can break our mappings.
    b:undo_ftplugin = ''

    # remove empty first line, and empty last prompt
    sil! keepj :/^\%1l$/d _
    sil! exe 'keepj :/^\%' .. line('$') .. 'l٪$/d _'

    # Why the priority 0?{{{
    #
    # To allow  a search to highlight  text even if it's  already highlighted by
    # this match.
    #}}}
    hi Cwd ctermfg=blue
    matchadd('Cwd', '.*\ze\n٪', 0)

    # Why don't you use `matchadd()` for the last line of the buffer?{{{
    #
    # If we delete the last line of the  buffer, we don't want the new last line
    # to  be highlighted  as  if it  was printing  the  shell's current  working
    # directory.  IOW, we need the highlighting  to be attached to the *initial*
    # last line of the buffer; not whatever last line is at any given time.
    #}}}
    prop_type_add('LastLine', {highlight: 'Cwd', bufnr: bufnr('%')})
    prop_add(line('$'), 1, {type: 'LastLine', length: col([line('$'), '$']), bufnr: bufnr('%')})

    hi ExitCode ctermfg=red
    matchadd('ExitCode', '\[\d\+\]\ze\%(\n٪\|\%$\)', 0)

    hi ShellCmd ctermfg=green
    matchadd('ShellCmd', '^٪.\+', 0)
enddef

def CopyCmdToGetFileViaXdcc() #{{{2
    var line = getline('.')
    var msg = matchstr(line, '\m\C/MSG\s\+\zs.\{-}XDCC\s\+SEND\s\+\d\+')
    # What is this `moviegods_send_me_file`?{{{
    #
    # A WeeChat alias.
    # If it doesn't exist, you can install it by running in WeeChat:
    #
    #     /alias add moviegods_send_me_file /j #moviegods ; /msg
    #}}}
    #   Why do you use an alias?{{{
    #
    # I don't join `#moviegods` by default, because it adds too much network traffic.
    # And a `/msg ... xdcc send ...` command doesn't work if you haven't joined this channel.
    # IOW, we need to run 2 commands:
    #
    #     /j #moviegods
    #     /msg ... xdcc send ...
    #
    # But, in the end, we will only be able to write one in the clipboard.
    # To fix  this issue, we  need to build a  command-line which would  run two
    # commands.
    #
    # An alias lets you use the `;` token which has the same meaning as in a shell.
    # With it, you can do:
    #
    #     cmd1 ; cmd2
    #}}}
    var cmd = '/moviegods_send_me_file ' .. msg
    setreg('+', [cmd], 'c')
    q!
enddef
#}}}1
