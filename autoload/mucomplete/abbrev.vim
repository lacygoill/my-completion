let s:abbr_table    = execute('iab')
let s:pattern       = '\vi\s+\zs\w+'
let s:abbreviations = reverse(map(split(s:abbr_table, "\n"), 'matchstr(v:val, s:pattern)'))
let g:abbreviations = deepcopy(s:abbreviations)

fu! mucomplete#abbrev#complete() abort
    let word_to_complete = matchstr(strpart(getline('.'), 0, col('.') - 1), '\S\+$')
    let abbreviations    = filter(copy(s:abbreviations), 'stridx(v:val, word_to_complete) == 0')
    let column           = 1 + match(strpart(getline('.'), 0, col('.') - 1), '\S\+$')

    if !empty(abbreviations)
        call complete(column, abbreviations)
    endif
    return ''
endfu
