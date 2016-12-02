let s:table  = execute('iab')
let s:lines  = reverse(split(s:table, "\n"))
let s:abbrev = map(s:lines, '{
                             \ "lhs" : matchstr(v:val, ''\vi\s+\zs\w+''),
                             \ "rhs" : matchstr(v:val, ''\v\*\s+\zs.*''),
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

fu! mucomplete#abbrev#complete() abort
    let word_to_complete = matchstr(strpart(getline('.'), 0, col('.') - 1), '\S\+$')

    let matching_abbrev  = map(filter(copy(s:abbrev),
                                    \ 'stridx(v:val.lhs, word_to_complete) == 0'),
                             \ '{ "word" : v:val.lhs,
                             \    "menu" : s:abbrev_rhs(v:val.rhs),
                             \ }')

    let from_where       = col('.') - len(word_to_complete)

    if !empty(matching_abbrev)
        call complete(from_where, matching_abbrev)
    endif
    return ''
endfu
