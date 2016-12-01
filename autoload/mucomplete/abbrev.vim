let s:abbr_table    = execute('iab')
let s:pattern       = '\vi\s+\zs\w+'
let s:abbreviations = reverse(map(split(s:abbr_table, "\n"), 'matchstr(v:val, s:pattern)'))

fu! mucomplete#abbrev#complete() abort
    let word_to_complete = matchstr(strpart(getline('.'), 0, col('.') - 1), '\S\+$')
    let abbreviations    = filter(s:abbreviations, 'v:val =~ "^".word_to_complete')
    let column           = 1 + match(strpart(getline('.'), 0, col('.') - 1), '\S\+$')

    if !empty(abbreviations)
        call complete(column, abbreviations)
    endif
    return ''
endfu
