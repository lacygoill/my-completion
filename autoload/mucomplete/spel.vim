fu! mucomplete#spel#complete() abort

    let word_to_complete = matchstr(getline('.'), '\S\+\%'.col('.').'c')
    let badword          = spellbadword(word_to_complete)
    let suggestions      = !empty(badword[1])
                           \ ? spellsuggest(badword[0])
                           \ : []

    let from_where  = col('.') - len(word_to_complete)

    if !empty(suggestions)
        call complete(from_where, suggestions)
    endif
    return ''
endfu
