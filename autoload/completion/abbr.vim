vim9script noclear

if exists('loaded') | finish | endif
var loaded = true

var table: string = execute('iab')
var lines: list<string> = split(table, '\n')->reverse()
const ABBREV: list<dict<string>> = lines
    ->mapnew((_, v: string): dict<string> => ({
        lhs: v->matchstr('i\s\+\zs\w\+'),
        rhs: v->matchstr('\*\s\+\zs.*'),
    }))

def completion#abbr#complete(): string
    var word_to_complete: string = getline('.')
        ->strpart(0, col('.') - 1)
        ->matchstr('\S\+$')

    # NOTE:
    # if the abbreviation is complex, and is the output of a function:
    #
    #     ExpandAdj()
    #     ExpandAdv()
    #     ExpandNoun()
    #     ExpandVerb()
    #
    # ... the rhs will look like this:
    #
    #     <C-R>=<SNR>42_ExpandAdv('ctl', 'actuellement')<CR>
    #
    # To make the description less noisy, we need to extract the expansion (`actuellement`).
    # To do this, we'll follow this algorithm:
    #
    #     does the rhs of the abbreviation contains the string `expand_` ?
    #             AbbrevRhs(v.rhs)->stridx('expand_') >= 0
    #
    #     if so, extract the expansion
    #             AbbrevRhs(v.rhs)->matchstr('.*,\s*''\zs.*\ze'')')
    #                                        │
    #                                        └ describe the text after a comma,
    #                                          between single quotes, and before a parenthesis
    #
    #     otherwise, let it be
    #             AbbrevRhs(v.rhs)

    var matching_abbrev: list<dict<string>> = copy(ABBREV)
        ->filter((_, v: dict<string>): bool =>
                    stridx(v.lhs, word_to_complete) == 0)
        ->map((_, v: dict<string>): dict<string> => ({
                    word: v.lhs,
                    menu: AbbrevRhs(v.rhs)->stridx('expand_') >= 0
                        ?    AbbrevRhs(v.rhs)->matchstr('.*,\s*''\zs.*\ze'')')
                        :    AbbrevRhs(v.rhs)
        }))

    var from_where: number = col('.') - strlen(word_to_complete)

    if !empty(matching_abbrev)
        complete(from_where, matching_abbrev)
    endif
    return ''
enddef

def AbbrevRhs(rhs: string): string
    if stridx(rhs, '&spelllang ==') == -1
        return rhs
    elseif &l:spelllang == 'fr'
        return rhs->matchstr('fr.\{-}''\zs.\{-}\ze''')
    elseif &l:spelllang == 'en'
        return rhs->matchstr(':\s\+''\zs.*\ze''')
    endif
    return ''
enddef

