fu! completion#spel#complete() abort
    let word_to_complete = matchstr(getline('.'), '\k\+\%'.col('.').'c')
    let badword          = spellbadword(word_to_complete)
    let candidates       = !empty(badword[1])
    \?                         spellsuggest(badword[0])
    \:                         []

    let from_where = col('.') - len(word_to_complete)

    if !empty(candidates)
        call complete(from_where, candidates)
    endif
    return ''
endfu
