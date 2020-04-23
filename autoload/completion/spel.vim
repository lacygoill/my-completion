fu completion#spel#suggest() abort "{{{1
    let word_to_complete = matchstr(getline('.'), '\k\+\%'..col('.')..'c')
    let badword = spellbadword(word_to_complete)
    let matches = !empty(badword[1])
                 \ ?     spellsuggest(badword[0])
                 \ :     []

    let from_where = col('.') - strlen(word_to_complete)

    if !empty(matches)
        call complete(from_where, matches)
    endif
    return ''
endfu

fu completion#spel#fix() abort "{{{1
    " don't break undo sequence:
    "
    "    - it seems messed up (performs an undo then a redo which gets us in a weird state)
    "    - not necessary here, Vim already breaks the undo sequence

    " Alternative:
    "
    "     let winview = winsaveview()
    "     norm! [S1z=
    "     norm! `^
    "     call winrestview(winview)

    let [spell_save, winid, bufnr] = [&l:spell, win_getid(), bufnr('%')]
    setl spell
    try
        let before_cursor = matchstr(getline('.'), '.*\%'..col('.')..'c')
        "                                            ┌ don't eliminate a keyword nor a single quote
        "                                            │ when you split the line
        "                                            ├────────────┐
        let words = reverse(split(before_cursor, '\%(\%(\k\|''\)\@!.\)\+'))

        let found_a_badword = 0
        for word in words
            let badword = get(spellbadword(word), 0, '')
            if empty(badword)
                continue
            endif
            let suggestion = get(spellsuggest(badword), 0, '')
            if empty(suggestion)
                continue
            else
                let found_a_badword = 1
                break
            endif
        endfor

        if found_a_badword
            if exists('#User#add_to_undolist_i')
                do <nomodeline> User add_to_undolist_i
            endif
            let new_line = substitute(getline('.'), '\V\<'..badword..'\>', suggestion, 'g')
            call timer_start(0, {-> setline('.', new_line)})
        endif
    catch
        return lg#catch()
    finally
        if winbufnr(winid) == bufnr
            let [tabnr, winnr] = win_id2tabwin(winid)
            call settabwinvar(tabnr, winnr, '&spell', spell_save)
        endif
    endtry
    " Break undo sequence before `setline()` edits the line, so that we can undo
    " if the fix is wrong.
    return "\<c-g>u"
endfu

