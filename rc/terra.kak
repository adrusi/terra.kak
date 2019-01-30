# http://terra.org
# ‾‾‾‾‾‾‾‾‾‾‾‾‾‾

# Detection
# ‾‾‾‾‾‾‾‾‾

hook global BufCreate .*[.](t) %{
    set-option buffer filetype terra
}

# Highlighters
# ‾‾‾‾‾‾‾‾‾‾‾‾

add-highlighter shared/terra regions
add-highlighter shared/terra/code default-region group
add-highlighter shared/terra/raw_string  region -match-capture '\[(=*)\['   '\](=*)\]'       fill string
add-highlighter shared/terra/raw_comment region -match-capture '--\[(=*)\[' '\](=*)\]'       fill comment
add-highlighter shared/terra/double_string region '"'   (?<!\\)(?:\\\\)*" fill string
add-highlighter shared/terra/single_string region "'"   (?<!\\)(?:\\\\)*' fill string
add-highlighter shared/terra/comment       region '--'  $                 fill comment

add-highlighter shared/terra/code/ regex \b(and|break|do|else|elseif|end|false|for|function|goto|if|in|local|nil|not|or|repeat|return|then|true|until|while|terra|quote|var)\b 0:keyword

# Commands
# ‾‾‾‾‾‾‾‾

define-command terra-alternative-file -docstring 'Jump to the alternate file (implementation ↔ test)' %{ evaluate-commands %sh{
    case $kak_buffile in
        *spec/*_spec.t)
            altfile=$(eval printf %s\\n $(printf %s\\n $kak_buffile | sed s+spec/+'*'/+';'s/_spec//))
            [ ! -f $altfile ] && echo "echo -markup '{Error}implementation file not found'" && exit
        ;;
        *.t)
            path=$kak_buffile
            dirs=$(while [ $path ]; do printf %s\\n $path; path=${path%/*}; done | tail -n +2)
            for dir in $dirs; do
                altdir=$dir/spec
                if [ -d $altdir ]; then
                    altfile=$altdir/$(realpath $kak_buffile --relative-to $dir | sed s+[^/]'*'/++';'s/\\.t$/_spec.t/)
                    break
                fi
            done
            [ ! -d $altdir ] && echo "echo -markup '{Error}spec/ not found'" && exit
        ;;
        *)
            echo "echo -markup '{Error}alternative file not found'" && exit
        ;;
    esac
    printf %s\\n "edit $altfile"
}}

define-command -hidden terra-indent-on-char %{
    evaluate-commands -no-hooks -draft -itersel %{
        # align middle and end structures to start and indent when necessary, elseif is already covered by else
        try %{ execute-keys -draft <a-x><a-k>^\h*(else)$<ret><a-\;><a-?>^\h*(if)<ret>s\A|\z<ret>)<a-&> }
        try %{ execute-keys -draft <a-x><a-k>^\h*(end)$<ret><a-\;><a-?>^\h*(for|function|if|while|terra|quote)(?!\w)<ret>s\A|\z<ret>)<a-&> }
    }
}

define-command -hidden terra-indent-on-new-line %{
    evaluate-commands -no-hooks -draft -itersel %{
        # preserve previous line indent
        try %{ execute-keys -draft <space>K<a-&> }
        # remove trailing white spaces from previous line
        try %{ execute-keys -draft k<a-x>s\h+$<ret>d }
        # indent after start structure
        try %{ execute-keys -draft k<a-x><a-k>^\h*(else|elseif|for|function|if|while|terra|quote)(?!\w)\b<ret>j<a-gt> }
    }
}

define-command -hidden terra-insert-on-new-line %[
    evaluate-commands -no-hooks -draft -itersel %[
        # copy -- comment prefix and following white spaces
        try %{ execute-keys -draft k<a-x>s^\h*\K--\h*<ret>yghjP }
        # wisely add end structure
        evaluate-commands -save-regs x %[
            try %{ execute-keys -draft k<a-x>s^\h+<ret>"xy } catch %{ reg x '' } # Save previous line indent in register x
            try %[ execute-keys -draft k<a-x> <a-k>^<c-r>x(for|function|if|while|terra|quote)(?!\w)<ret> J}iJ<a-x> <a-K>^<c-r>x(else|end|elseif)(?!\w)$<ret> # Validate previous line and that it is not closed yet
                   execute-keys -draft o<c-r>xend<esc> ] # auto insert end
        ]
    ]
]

# Initialization
# ‾‾‾‾‾‾‾‾‾‾‾‾‾‾

hook -group terra-highlight global WinSetOption filetype=terra %{
    add-highlighter window/terra ref terra
    hook -once -always window WinSetOption filetype=.* %{ remove-highlighter window/terra }
}

hook global WinSetOption filetype=terra %{
    hook window InsertChar .* -group terra-indent terra-indent-on-char
    hook window InsertChar \n -group terra-indent terra-indent-on-new-line
    hook window InsertChar \n -group terra-insert terra-insert-on-new-line

    alias window alt terra-alternative-file

    hook -once -always window WinSetOption filetype=.* %{
        remove-hooks window terra-.+
        unalias window alt terra-alternative-file
    }
}
