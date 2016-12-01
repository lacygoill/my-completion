fu! mucomplete#spel#complete() abort

    let badword     = spellbadword(matchstr(getline('.'), '\k\+\%'.col('.').'c'))
    let suggestions = !empty(badword[1])
                      \ ? spellsuggest(badword[0])
                      \ : []

    let column      = 1 + match(strpart(getline('.'), 0, col('.') - 1), '\S\+$')

    if !empty(suggestions)
        call complete(column, suggestions)
    endif
    return ''
endfu
