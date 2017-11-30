if exists('g:autoloaded_mycompletion_file')
    finish
endif
let g:autoloaded_mycompletion_file = 1

fu! mycompletion#file#complete() abort

    "    strpart(…)     returns the text from the beginning of the line up to
    "                   the cursor
    "
    "    matchstr(…)    returns the (file/directory) path before the cursor,
    "                   if there's one
    "
    " Why the pattern `\v\f%(\f|\s)*$`?
    "
    " A path begins with a character which is in 'isfname' (`\f` class),
    " hence the first `\f`.
    " We could simply use the pattern `\f+$`, but we would miss the paths
    " containing spaces.
    " So, we use a pattern where the characters after the first `\f` can be in
    " 'isf' or be a whitespace, hence the `%(\f|\s)*`.

    let cur_path = matchstr(strpart(getline('.'), 0, col('.') - 1), '\v\f%(\f|\s)*$')

    " Why a while loop? {{{
    " Consider this:
    "
    "     Some text a dir/
    "
    " We want to complete the path `a dir/`.
    " The current algo doesn't know where the path begins, it grabs as many
    " `\f` and `\s` characters.
    " So, initially, the value of `cur_path` is `Some text a dir/`.
    " When the algo will try to expand `Some text a dir/*`:
    "
    "     let entries = glob(cur_path.'*', 0, 1, 1)
    "
    " It won't find anything. `entries` will be an empty list.
    " We need the algo to retry another, shorter, path.
    " To achieve this, we do 2 things:
    "
    "     - call `complete()` and return (`return ''`) on the condition that
    "       `entries` is not empty
    "
    "     - if `entries` is empty, we:
    "
    "           1. reset `cur_path`, giving it the value:
    "
    "                   matchstr(cur_path, '\s\zs\f.*$', 1)
    "
    "              This new value removes the text from the beginning of the
    "              string up to the first sequence of whitespace (whitespace
    "              excluded).
    "              For example, if the value of `cur_path`'s was initially:
    "
    "                   Some text a dir/
    "
    "              … its next value will be:
    "
    "                   text a dir/
    "
    "           2. loop as long as `cur_path` is not empty
    "              The loop will try to expand, consecutively:
    "
    "                  Some text a dir/
    "                  text a dir/
    "                  a dir/
    "
    "              If `a dir` and `dir` are not an existing directory, their
    "              expansion will also fail, and at the end of the last
    "              iteration, `cur_path` will be empty, because:
    "
    "                  matchstr('dir', '\s\zs\f.*$', 1) == ''
    "
    " "}}}

    while !empty(cur_path)

        " What's the meaning of the 3 numbers arguments passed to `glob()`?{{{
        "
        "     0    we want 'suffixes' and 'wildignore' to apply during the
        "          expansion of `~`
        "
        "     1    "       the result as a list and not as a string
        "
        "     1    "       all the symbolic links to be included, even
        "          the ones which do not point to an existing file
        "
        "
        "
        " Why:
        "     cur_path !=# '~' ? '*' : ''
        "
        " If `cur_path` is different from `~`, for example if it's:
        "
        "     /home/user/Do
        "
        " … we add a wildcard, so that `glob()` gives us any existing entry in
        " the filesystem whose name begins like `cur_path`.
        " But if `cur_path` is `~`, we don't add a wildcard, because:
        "
        "     glob('~*', 0, 1, 1)
        "
        " … would return an empty list. Indeed, there's no entry in the
        " filesystem whose name begins with `~`. We need to expand `~` itself,
        " into `/home/user`."}}}

        let entries = glob(cur_path . (cur_path !=# '~' ? '*' : ''), 0, 1, 1)

        if !empty(entries)

            " Why:
            "
            "     col('.') - len(fnamemodify(cur_path, ':t'))
            "
            " … instead of:
            "
            "     col('.') - len(cur_path)
            "
            " …?
            " Because, we don't complete the whole path. The candidates
            " in the menu will only match the last component of a path.
            " So we need to tell `complete()` that the selected entry in
            " the menu will replace only the last component of the current
            " path.

            let from_where = col('.') - len(fnamemodify(cur_path, ':t'))

            " Why:
            "
            "     cur_path !=# '~' ? fnamemodify(v, ':t') : v
            "
            " Because, if `cur_path` is `~`, then `entries` is:
            "
            "     ['/home/user']
            "
            " and `v` will take the (single) value `'/home/user'`.
            " Usually, we want to complete only the last component of a path.
            " But here, we don't want to complete only the last component of
            " `/home/user`, which is `user`, we want the whole path `/home/user`.

            call complete(from_where, map(entries,{ k,v ->
            \                                               (cur_path !=# '~' ? fnamemodify(v, ':t') : v)
            \                                              .(isdirectory(v) ? '/' : '')
            \                                     }
            \                            ))

            return ''
        else

            " If the expansion failed, try a shorter path by removing the text
            " from the beginning of the path up to the first sequence of
            " whitespace (whitespace excluded), or up to the first equal sign.

            let cur_path = matchstr(cur_path, '[ \t=]\zs\f.*$', 1)
            "                                      │
            "                                      └─ try to also complete a path
            "                                         after an equal sign
        endif
    endwhile

    " If `cur_path` is empty, return nothing.
    return ''
endfu
