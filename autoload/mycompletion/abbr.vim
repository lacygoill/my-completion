let s:table  = execute('iab')
let s:lines  = reverse(split(s:table, "\n"))
let s:abbrev = map(s:lines, '{
                             \ "lhs" : matchstr(v:val, "\\vi\\s+\\zs\\w+"),
                             \ "rhs" : matchstr(v:val, "\\v\\*\\s+\\zs.*"),
                             \ }')

fu! s:abbrev_rhs(rhs) abort
    if stridx(a:rhs, '&spl ==#') == -1
        return a:rhs

    elseif &l:spl ==# 'fr'
        return matchstr(a:rhs, "\\vfr.{-}'\\zs.{-}\\ze'")

    elseif &l:spl ==# 'en'
        return matchstr(a:rhs, ":\\s\\+'\\zs.*\\ze'")
    endif
endfu

fu! mycompletion#abbr#complete() abort
    let word_to_complete = matchstr(strpart(getline('.'), 0, col('.') - 1), '\S\+$')

    " NOTE:
    " if the abbreviation is complex, and is the output of a function:
    "     s:expand_adj()
    "     s:expand_adv()
    "     s:expand_noun()
    "     s:expand_verb()
    "
    " … the rhs will look like this:
    "     <c-r>=<snr>42_expand_adv('ctl','actuellement')<cr>
    "
    " To make the description less noisy, we need to extract the expansion (`actuellement`).
    " To do this, we'll follow this algorithm:
    "
    "     does the rhs of the abbreviation contains the string `expand_` ?
    "             match(s:abbrev_rhs(v:val.rhs), "expand_") != -1
    "
    "     if so, extract the expansion
    "             matchstr(s:abbrev_rhs(v:val.rhs), ".*,''\\zs.*\\ze'')")
    "                                               │
    "                                               └─ this pattern describes the text after a comma,
    "                                               between single quotes, and before a parenthesis
    "
    "     otherwise, let it be
    "             s:abbrev_rhs(v:val.rhs)

    let matching_abbrev  = map(filter(copy(s:abbrev),
                                    \ 'stridx(v:val.lhs, word_to_complete) == 0'),
                             \ '{ "word" : v:val.lhs,
                             \    "menu" : match(s:abbrev_rhs(v:val.rhs), "expand_") != -1
                             \               ? matchstr(s:abbrev_rhs(v:val.rhs), ".*,''\\zs.*\\ze'')")
                             \               : s:abbrev_rhs(v:val.rhs),
                             \ }')

    let from_where       = col('.') - len(word_to_complete)

    if !empty(matching_abbrev)
        call complete(from_where, matching_abbrev)
    endif
    return ''
endfu
