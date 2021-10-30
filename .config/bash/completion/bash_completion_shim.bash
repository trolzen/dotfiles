#!/bin/bash

# Get the word to complete and optional previous words.
# This is nicer than ${COMP_WORDS[$COMP_CWORD]}, since it handles cases
# where the user is completing in the middle of a word.
# (For example, if the line is "ls foobar",
# and the cursor is here -------->   ^
# Also one is able to cross over possible wordbreak characters.
# Usage: _get_comp_words_by_ref [OPTIONS] [VARNAMES]
# Available VARNAMES:
#     cur         Return cur via $cur
#     prev        Return prev via $prev
#     words       Return words via $words
#     cword       Return cword via $cword
#
# Available OPTIONS:
#     -n EXCLUDE  Characters out of $COMP_WORDBREAKS which should NOT be
#                 considered word breaks. This is useful for things like scp
#                 where we want to return host:path and not only path, so we
#                 would pass the colon (:) as -n option in this case.
#     -c VARNAME  Return cur via $VARNAME
#     -p VARNAME  Return prev via $VARNAME
#     -w VARNAME  Return words via $VARNAME
#     -i VARNAME  Return cword via $VARNAME
#
# Example usage:
#
#    $ _get_comp_words_by_ref -n : cur prev
#
_get_comp_words_by_ref()
{
    local exclude flag i OPTIND=1
    local cur cword words=()
    local upargs=() upvars=() vcur vcword vprev vwords

    while getopts "c:i:n:p:w:" flag "$@"; do
        case $flag in
            c) vcur=$OPTARG ;;
            i) vcword=$OPTARG ;;
            n) exclude=$OPTARG ;;
            p) vprev=$OPTARG ;;
            w) vwords=$OPTARG ;;
        esac
    done
    while [[ $# -ge $OPTIND ]]; do
        case ${!OPTIND} in
            cur)   vcur=cur ;;
            prev)  vprev=prev ;;
            cword) vcword=cword ;;
            words) vwords=words ;;
            *) echo "bash: $FUNCNAME(): \`${!OPTIND}': unknown argument" \
                1>&2; return 1
        esac
        let "OPTIND += 1"
    done

    __get_cword_at_cursor_by_ref "$exclude" words cword cur

    [[ $vcur   ]] && { upvars+=("$vcur"  ); upargs+=(-v $vcur   "$cur"  ); }
    [[ $vcword ]] && { upvars+=("$vcword"); upargs+=(-v $vcword "$cword"); }
    [[ $vprev && $cword -ge 1 ]] && { upvars+=("$vprev" ); upargs+=(-v $vprev
        "${words[cword - 1]}"); }
    [[ $vwords ]] && { upvars+=("$vwords"); upargs+=(-a${#words[@]} $vwords
        "${words[@]}"); }

    (( ${#upvars[@]} )) && local "${upvars[@]}" && _upvars "${upargs[@]}"
}

# Assign variables one scope above the caller
# Usage: local varname [varname ...] &&
#        _upvars [-v varname value] | [-aN varname [value ...]] ...
# Available OPTIONS:
#     -aN  Assign next N values to varname as array
#     -v   Assign single value to varname
# Return: 1 if error occurs
# See: https://fvue.nl/wiki/Bash:_Passing_variables_by_reference
_upvars()
{
    if ! (($#)); then
        echo "bash_completion: $FUNCNAME: usage: $FUNCNAME" \
            "[-v varname value] | [-aN varname [value ...]] ..." >&2
        return 2
    fi
    while (($#)); do
        case $1 in
            -a*)
                # Error checking
                [[ ${1#-a} ]] || {
                    echo "bash_completion: $FUNCNAME:" \
                        "\`$1': missing number specifier" >&2
                    return 1
                }
                printf %d "${1#-a}" &>/dev/null || {
                    echo bash_completion: \
                        "$FUNCNAME: \`$1': invalid number specifier" >&2
                    return 1
                }
                # Assign array of -aN elements
                [[ "$2" ]] && unset -v "$2" && eval $2=\(\"\$"{@:3:${1#-a}}"\"\) &&
                    shift $((${1#-a} + 2)) || {
                    echo bash_completion: \
                        "$FUNCNAME: \`$1${2+ }$2': missing argument(s)" \
                        >&2
                    return 1
                }
                ;;
            -v)
                # Assign single value
                [[ "$2" ]] && unset -v "$2" && eval $2=\"\$3\" &&
                    shift 3 || {
                    echo "bash_completion: $FUNCNAME: $1:" \
                        "missing argument(s)" >&2
                    return 1
                }
                ;;
            *)
                echo "bash_completion: $FUNCNAME: $1: invalid option" >&2
                return 1
                ;;
        esac
    done
}

# @param $1 exclude  Characters out of $COMP_WORDBREAKS which should NOT be
#     considered word breaks. This is useful for things like scp where
#     we want to return host:path and not only path, so we would pass the
#     colon (:) as $1 in this case.
# @param $2 words  Name of variable to return words to
# @param $3 cword  Name of variable to return cword to
# @param $4 cur  Name of variable to return current word to complete to
# @see __reassemble_comp_words_by_ref()
__get_cword_at_cursor_by_ref()
{
    local cword words=()
    __reassemble_comp_words_by_ref "$1" words cword

    local i cur index=$COMP_POINT lead=${COMP_LINE:0:$COMP_POINT}
    # Cursor not at position 0 and not leaded by just space(s)?
    if [[ $index -gt 0 && ( $lead && ${lead//[[:space:]]} ) ]]; then
        cur=$COMP_LINE
        for (( i = 0; i <= cword; ++i )); do
            while [[
                # Current word fits in $cur?
                ${#cur} -ge ${#words[i]} &&
                # $cur doesn't match cword?
                "${cur:0:${#words[i]}}" != "${words[i]}"
            ]]; do
                # Strip first character
                cur="${cur:1}"
                # Decrease cursor position, staying >= 0
                [[ $index -gt 0 ]] && ((index--))
            done

            # Does found word match cword?
            if [[ $i -lt $cword ]]; then
                # No, cword lies further;
                local old_size=${#cur}
                cur="${cur#"${words[i]}"}"
                local new_size=${#cur}
                index=$(( index - old_size + new_size ))
            fi
        done
        # Clear $cur if just space(s)
        [[ $cur && ! ${cur//[[:space:]]} ]] && cur=
        # Zero $index if negative
        [[ $index -lt 0 ]] && index=0
    fi

    local "$2" "$3" "$4" && _upvars -a${#words[@]} $2 "${words[@]}" \
        -v $3 "$cword" -v $4 "${cur:0:$index}"
}

# Reassemble command line words, excluding specified characters from the
# list of word completion separators (COMP_WORDBREAKS).
# @param $1 chars  Characters out of $COMP_WORDBREAKS which should
#     NOT be considered word breaks. This is useful for things like scp where
#     we want to return host:path and not only path, so we would pass the
#     colon (:) as $1 here.
# @param $2 words  Name of variable to return words to
# @param $3 cword  Name of variable to return cword to
#
__reassemble_comp_words_by_ref()
{
    local exclude i j line ref
    # Exclude word separator characters?
    if [[ $1 ]]; then
        # Yes, exclude word separator characters;
        # Exclude only those characters, which were really included
        exclude="${1//[^$COMP_WORDBREAKS]}"
    fi

    # Default to cword unchanged
    printf -v "$3" %s "$COMP_CWORD"
    # Are characters excluded which were former included?
    if [[ $exclude ]]; then
        # Yes, list of word completion separators has shrunk;
        line=$COMP_LINE
        # Re-assemble words to complete
        for (( i=0, j=0; i < ${#COMP_WORDS[@]}; i++, j++)); do
            # Is current word not word 0 (the command itself) and is word not
            # empty and is word made up of just word separator characters to
            # be excluded and is current word not preceded by whitespace in
            # original line?
            while [[ $i -gt 0 && ${COMP_WORDS[$i]} == +([$exclude]) ]]; do
                # Is word separator not preceded by whitespace in original line
                # and are we not going to append to word 0 (the command
                # itself), then append to current word.
                [[ $line != [$' \t']* ]] && (( j >= 2 )) && ((j--))
                # Append word separator to current or new word
                ref="$2[$j]"
                printf -v "$ref" %s "${!ref}${COMP_WORDS[i]}"
                # Indicate new cword
                [[ $i == $COMP_CWORD ]] && printf -v "$3" %s "$j"
                # Remove optional whitespace + word separator from line copy
                line=${line#*"${COMP_WORDS[$i]}"}
                # Start new word if word separator in original line is
                # followed by whitespace.
                [[ $line == [$' \t']* ]] && ((j++))
                # Indicate next word if available, else end *both* while and
                # for loop
                (( $i < ${#COMP_WORDS[@]} - 1)) && ((i++)) || break 2
            done
            # Append word to current word
            ref="$2[$j]"
            printf -v "$ref" %s "${!ref}${COMP_WORDS[i]}"
            # Remove optional whitespace + word from line copy
            line=${line#*"${COMP_WORDS[i]}"}
            # Indicate new cword
            [[ $i == $COMP_CWORD ]] && printf -v "$3" %s "$j"
        done
        [[ $i == $COMP_CWORD ]] && printf -v "$3" %s "$j"
    else
        # No, list of word completions separators hasn't changed;
        for i in ${!COMP_WORDS[@]}; do
            printf -v "$2[i]" %s "${COMP_WORDS[i]}"
        done
    fi
} # __reassemble_comp_words_by_ref()

# If the word-to-complete contains a colon (:), left-trim COMPREPLY items with
# word-to-complete.
# With a colon in COMP_WORDBREAKS, words containing
# colons are always completed as entire words if the word to complete contains
# a colon.  This function fixes this, by removing the colon-containing-prefix
# from COMPREPLY items.
# The preferred solution is to remove the colon (:) from COMP_WORDBREAKS in
# your .bashrc:
#
#    # Remove colon (:) from list of word completion separators
#    COMP_WORDBREAKS=${COMP_WORDBREAKS//:}
#
# See also: Bash FAQ - E13) Why does filename completion misbehave if a colon
# appears in the filename? - http://tiswww.case.edu/php/chet/bash/FAQ
# @param $1 current word to complete (cur)
# @modifies global array $COMPREPLY
#
__ltrim_colon_completions()
{
    if [[ "$1" == *:* && "$COMP_WORDBREAKS" == *:* ]]; then
        # Remove colon-word prefix from COMPREPLY items
        local colon_word=${1%"${1##*:}"}
        local i=${#COMPREPLY[*]}
        while [[ $((--i)) -ge 0 ]]; do
            COMPREPLY[$i]=${COMPREPLY[$i]#"$colon_word"}
        done
    fi
} # __ltrim_colon_completions()
