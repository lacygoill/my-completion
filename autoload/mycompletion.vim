" FIXME: {{{1
"
" In `s:act_on_textchanged()`, shouldn't:
"
"     getline('.')[col('.')-2] =~# '\v\f'
"
" … be replaced with:
"
"     matchstr(getline('.'), '.\%'.col('.').'c') =~# '\v\f'
"
" to handle the case where the character before the cursor is multibyte?
" A multibyte character can be in 'isf'.

" FIXME: {{{1
"
" I keep this section, but it's not a good idea because it could cause
" autocompletion to hit Tab indefinitely.
" See `mycompletion#enable_auto()` for more info.
"
" Lifepillar gave the value 1 to `s:completedone`.
" I think `!empty(v:completed_item)` would be better, because it would allow
" to have an autocompletion even when the previous one failed.
" For most methods, such a thing is useless, but not for all ('digr' is
" a counter-example).
"
" For more info, see the comment where we set `s:completedone` inside
" `mycompletion#enable_auto()`.
"
" Incidentally, this new definition also fixes a bug which occurs when `s:i`
" ends with the value `s:N`, and `s:completedone`'s value is 1.
" Setting `s:completedone` to `!empty(v:completed_item)` means that when all
" the methods fail during an autocompletion and nothing is inserted,
" `s:completedone`'s value is still 0, even though `CompleteDone` was
" triggered several times. And the next time we insert a character and
" `s:act_on_textchanged()` is called, it won't execute the
" first block of code which tries to get `s:methods[s:i]` (`s:i = s:N`).
"
" We don't really need this new definition to fix this bug, because we have
" a more reliable way to do it, at the end of `s:next_method()`.
"
"     if s:i == s:N
"         let s:i = 0
"     endif
"
" But still, one could argue that it's another reason in favor of the new definition.

" FIXME: {{{1
"
" Inside `s:act_on_textchanged()`, why does lifepillar write:
"
"     match(strpart(…), g:…) > -1
"
" instead of simply:
"
"     strpart(…) =~ g:…
"
" And why does he regularly write:
"
"     strpart(getline('.'), 0, col('.')-1)
"
" … instead of simply:
"
"     getline('.')[:col('.')-2]

" To look for all the global variables used by this plugin, search the
" pattern:
"         \v^%(\s*".*)@!.*\zsg:[^ ,]

" Variables {{{1

if exists('g:auto_loaded_mycompletion')
    finish
endif
let g:auto_loaded_mycompletion = 1

" Default completion chain

let g:mc_chain = get(g:, 'mc_chain', [
                                     \ 'file',
                                     \ 'keyp',
                                     \ 'abbr',
                                     \ 'c-p' ,
                                     \ 'digr',
                                     \ 'line',
                                     \ 'dict',
                                     \ 'ulti',
                                     \ ])

" Internal state
let s:methods = get(b:, 'mc_chain', g:mc_chain)
let s:N       = len(s:methods)
let s:word    = ''

" flag: in which direction will we move in the chain
let s:dir = 1

" flag: did we ask to move in the chain ?
let s:cycling = 0

" Indexes of the methods which have been tried since the last time we've been
" cycling.
let s:i_history = []

" number (positive or negative):   idx of the current method to try
let s:i = 0
" The valid values of `s:i` will vary between 0 and s:N-1.
" It is initialized by `complete()`, which gives it the value:
"
"         -1      if we move forward in the chain
"         s:N     "          backward "
"
" It's updated by `s:next_method()`.

" flag:   state of the popup menu
let s:pumvisible = 0
" Its value is tested in `verify_completion()`, which is being called at the end
" of `s:next_method()`.

" Purpose of `s:auto`: {{{
"
" `s:auto` is a flag which, when it's set, means that autocompletion is enabled.
" Its used by `s:act_on_pumvisible()` to know whether it must insert the first
" entry in the menu. Indeed, when autocompletion is enabled, we don't want to
" automatically insert anything. Bad idea.
" It would constantly insert undesired text, and the user would have to undo
" it. The popup menu with suggestions is enough.
"
"}}}
" Why do we use `get()` ? {{{
"
" Consider this:
" autocompletion is enabled, and we source manually the plugin, it will
" wrongly, set `s:auto` to 0. The consequence will be that now autocompletions
" will automatically insert text.
"
"}}}

let s:auto    = get(s:, 'auto', 0)

" We could also use "\<c-x>\<c-z>\<bs> {{{
" In this case update the warning.
"
" Currently we have a mapping using C-x C-z, installed by the unicode plugin.
" We would have to unmap it in this script:
"
"     iunmap <C-x><C-z>
"
" We can't unmap it in the vimrc, because it would be too soon. The mappings
" for a plugin are defined after the vimrc is sourced.
""}}}

let s:exit_ctrl_x    = "\<c-g>\<c-g>"

if !empty(mapcheck('<c-g><c-g>', 'i'))
    echohl WarningMsg
    let msg = "Warning: you have a mapping whose {lhs} is or begins with C-g C-g\n\n".
            \ "MC (My Completion) hits those keys before hitting the keys of some methods.\n".
            \ "It does this to make sure you are out of C-x submode before trying them.\n\n".
            \ "Your current mapping could lead to some unexpected behavior.\n".
            \ "Please remove/change it.".
            \ execute('verb imap <c-g><c-g>')."\n\n"
    echo msg
    echohl None
endif

" Why do we need to prepend `s:exit_ctrl_x` in front of "\<c-x>\<c-l>"? {{{
"
" Suppose we have the following buffer:
"
"     hello world
"
" On another line, we write:
"
"     hello C-x C-l
"
" The line completion suggests us `hello world`, but we refuse and go on typing:
"
"     hello people
"
" If we hit C-x C-l again, the line completion will insert a newline.
" Why?
" It's probably one of Vim's quirks / bugs.
" It shouldn't insert anything, because now the line is unique.
"
" According to lifepillar, this can cause a problem when autocompletion
" is enabled.
" I can see how. The user set up line completion in his completion chain.
" Line completion is invoked automatically but he refuses the suggestion,
" and goes on typing. Later, line completion is invoked a second time.
" This time, there will be no suggestion, because the current line is likely
" unique (the user typed something that was nowhere else), but line completion
" will still insert a newline.
"
" Here's what lifepillar commented on the patch that introduced it:
"
"     Fix 'line' completion method inserting a new line.

"     Line completion seems to work differently from other completion methods:
"     typing a character that does not belong to an entry does not exit
"     completion. Before this commit, with autocompletion on such behaviour
"     resulted in µcomplete inserting a new line while the user was typing,
"     because µcomplete would insert <c-x><c-l> while in ctrl-x submode.

"     To fix that, we use the same trick as with 'c-p': make sure that we are
"     out of ctrl-x submode before typing <c-x><c-l>.
"
" To find the commit:
"
"     $ gsearch 's:cnp."\<c-x>\<c-l>"'
"
" There's a case, though, where adding a newline can make sense for line
" completion. When we're at the END of a line existing in multiple places, and
" we hit `C-x C-l`. Invoking line completion twice inserts a newline to suggest
" us the next line:
"
"     We have 2 identical lines:    L1 and L1'
"     After L1, there's L2.
"     The cursor is at the end of L1'.
"     The first `C-x C-l` invocation only suggests L1.
"     The second one inserts a newline and suggests L2.
"
"}}}
" Why do we use: "\<plug>(DigraphComplete) {{{
"                "\<plug>(UnicodeComplete)"
"
" … instead of:
"
"     "\<c-x>\<c-g>"
"     "\<c-x>\<c-z>"
"
" … ? Because, if one day we want to use `c-x c-z` as keys to exit c-x submode,
" it wouldn't work anymore.
"
" `c-x c-g` is not concerned, because it doesn't seem to work as exit keys.
" In this key sequence, for some reason, c-x makes us leave c-x submode and
" therefore c-g is interpreted as a prefix in insert mode.
"
" Nevertheless, I prefer to use the plug mapping for consistency reasons:
" we use it for the 'unic' method, so we do the same for the 'digr' method.
"
"}}}

let s:compl_mappings = {
                       \ 'abbr' : "\<c-r>\<c-r>=mycompletion#abbr#complete()\<cr>",
                       \ 'c-n'  : s:exit_ctrl_x."\<c-n>",
                       \ 'c-p'  : s:exit_ctrl_x."\<c-p>",
                       \ 'cmd'  : "\<c-x>\<c-v>",
                       \ 'defs' : "\<c-x>\<c-d>",
                       \ 'dict' : "\<c-x>\<c-k>",
                       \ 'digr' : "\<plug>(DigraphComplete)",
                       \ 'file' : "\<c-r>\<c-r>=mycompletion#file#complete()\<cr>",
                       \ 'incl' : "\<c-x>\<c-i>",
                       \ 'keyn' : "\<c-x>\<c-n>",
                       \ 'keyp' : "\<c-x>\<c-p>",
                       \ 'line' : s:exit_ctrl_x."\<c-x>\<c-l>",
                       \ 'omni' : "\<c-x>\<c-o>",
                       \ 'spel' : "\<c-r>\<c-r>=mycompletion#spel#complete()\<cr>",
                       \ 'tags' : "\<c-x>\<c-]>",
                       \ 'thes' : "\<c-x>\<c-t>",
                       \ 'ulti' : "\<c-r>\<c-r>=mycompletion#ultisnips#complete()\<cr>",
                       \ 'unic' : "\<plug>(UnicodeComplete)",
                       \ 'user' : "\<c-x>\<c-u>",
                       \ }

unlet s:exit_ctrl_x

let s:select_entry = { 'c-p' : "\<c-p>\<down>", 'keyp': "\<c-p>\<down>" }

" Default pattern to decide when automatic completion should be triggered.
let g:mc_auto_pattern = '\k\k$'

" Conditions to be verified for a given method to be applied.{{{
"
" Explanation of the regex for the file completion method:
"
"     \v[/~]\f*$
"
" Before the cursor, there must a slash or a tilda, then zero or more characters
" in 'isfname'.
" By default the tilda is in 'isf', so why not simply:
"
"     \v/?\f*
"
" Because then, it would match anything. The condition would be useless.
" At the very least, we want a slash or a tilda before the cursor.
" The filename characters afterwards are optional, because we could try to
" complete `some_dir/` or just `~`.
"
"}}}

let s:yes_you_can   = { _ -> 1 }
let g:mc_conditions = {
                      \ 'c-p'  : { t -> s:setup_isk_option() && g:mc_manual },
                      \ 'dict' : { t -> s:setup_dict_option() && g:mc_manual },
                      \ 'digr' : { t -> g:mc_manual && get(g:, 'loaded_unicodePlugin', 0) },
                      \ 'file' : { t -> t =~# '\v[/~]\f*$' },
                      \ 'keyp' : { t -> s:setup_isk_option() },
                      \ 'omni' : { t -> !empty(&l:omnifunc) && &ft !=# 'markdown' },
                      \ 'spel' : { t -> &l:spell    && !empty(&l:spelllang) },
                      \ 'tags' : { t -> g:mc_manual && !empty(tagfiles()) },
                      \ 'ulti' : { t -> get(g:, 'did_plugin_ultisnips', 0) },
                      \ 'unic' : { t -> g:mc_manual && get(g:, 'loaded_unicodePlugin', 0) },
                      \ 'user' : { t -> !empty(&l:completefunc) },
                      \ }

" act_on_pumvisible {{{1

" Purpose: {{{
"
" Automatically insert the first (or last) entry in the menu, but only when
" autocompletion is disabled.
"
" Indeed, when autocompletion is enabled, we don't want anything to be
" automatically inserted. Because, sometimes it could be what we wanted, but
" most of the time it wouldn't be, and we would have to undo the insertion.
" Annoying. We only want automatic insertion when we hit Tab ourselves.
"
"}}}

fu! s:act_on_pumvisible() abort
    let s:pumvisible = 0

    " If autocompletion is enabled don't do anything (respect the value of 'cot'). {{{
    "
    " Note that if 'cot' doesn't contain 'noinsert' nor 'noselect', Vim will
    " still automatically insert an entry from the menu.
    " That's why we'll have to make sure that 'cot' contains 'noselect' when
    " autocompletion is enabled.
    "
    " If the method is 'spel', don't do anything either.
    "
    " Why?
    " Fixing a spelling error is a bit different than simply completing text.
    " It's much more error prone.
    " We don't want to force the insertion of the first spelling suggestion.
    " We want `Tab` to respect the value of 'cot'.
    " In particular, the values 'noselect' and 'noinsert'.
    "
    " Otherwise, autocompletion is off, and the current method is not 'spel'.
    " In this case, we want to insert the first or last entry of the menu,
    " regardless of the values contained in 'cot'.
    "
    " Depending on the values in 'cot', there are 3 cases to consider:
    "
    "     1. 'cot' contains 'noselect'
    "
    "        Vim won't do anything (regardless whether 'noinsert' is there).
    "        So, to insert an entry of the menu, we'll have to return:
    "
    "            - `C-p Down` for the methods 'c-p' or 'keyp' (LAST entry)
    "            - `C-n Up`   for all the others              (FIRST entry)
    "
    "        It works but `Down` and `Up` breaks the undo sequence, meaning that
    "        if we want to repeat the completion with the dot command, a part of
    "        the completion will be lost.
    "
    "        We could also do:
    "
    "            C-n                    works but doesn't respect the user's
    "                                   decision of not selecting an entry
    "
    "            C-n C-p                doesn't work at all
    "                                   C-n would temporarily insert an entry,
    "                                   then C-p would immediately remove it
    "
    "        This means we shouldn't put 'noselect' in 'cot', at least for the
    "        moment.
    "
    "     2. 'cot' doesn't contain 'noselect' nor 'noinsert'
    "
    "        Vim will automatically insert and select an entry. So, nothing to do.
    "
    "     3. 'cot' doesn't contain 'noselect' but it DOES contain 'noinsert'
    "
    "        Vim will automatically select an entry, but it won't insert it.
    "        To force the insertion, we'll have to return `C-p C-n`.
    "
    "        It will work no matter the method.
    "        If the method is 'c-p' or 'keyp', `C-p` will make us select the
    "        second but last entry, then `C-n` will select and insert the last
    "        entry.
    "        For all the other methods, `C-p` will make us leave the menu,
    "        then `C-n` will select and insert the first entry.
    "
    "        Basically, `C-p` and `C-n` cancel each other out no matter the method.
    "        But `C-n` asks for an insertion. The result is that we insert the
    "        currently selected entry.
    "
"}}}

    return s:auto || get(s:methods, s:i, '') ==# 'spel'
    \?         ''
    \:     stridx(&l:completeopt, 'noselect') == -1
    \?     stridx(&l:completeopt, 'noinsert') == - 1
    \?         ''
    \:         "\<c-p>\<c-n>"
    \:         get(s:select_entry, s:methods[s:i], "\<c-n>\<up>")
endfu

" act_on_textchanged {{{1

" Purpose: {{{
"
" Try an autocompletion every time the text changes in insert mode.
"
" This function is only called when autocompletion is enabled.
" Technically, it tries an autocompletion by typing `<plug>(MC_Auto)`
" which calls `mycompletion#complete(1)`. Similar to hitting Tab.
"
" "}}}

fu! s:act_on_textchanged() abort
    if pumvisible()
        return ''
    endif

    " s:completedone {{{
    "
    " s:completedone is a flag, which is only on when 3 conditions are met:
    "
    "     - autocompletion is enabled
    "     - a completion has ended (successfully or not); `CompleteDone` event
    "     - we inserted a whitespace or we're at the beginning of a line
    "
    " It's almost always off, because as soon as it's enabled,
    " the `TextChangedI` event is triggered, and `s:act_on_textchanged()` is
    " called. The latter checks the value of the flag and resets it when it's on.
    "
    " What's its purpose?
    "
    " It prevents an autocompletion when one was already performed.
    " Triggering an autocompletion just after another one would probably be an
    " annoyance (except for file completion).
    " If I just autocompleted something, I'm probably done. I don't need Vim to
    " try another autocompletion, which may suggest me candidates that I already saw
    " in the popup menu last time.

"}}}

    if s:completedone

    " When an autocompletion has just been performed, we don't need a new one
    " until we insert a whitespace or we're at the beginning of a new line.
    " Indeed, if autocompleting a word just failed, it doesn't make sense to
    " go on trying to autocomplete it, every time we add a character.
    "
    " Besides, autocompletion will be performed only when `s:completedone` is set.
    " Based on these 2 informations, when `s:completedone` is set to 1,
    " we shouldn't reset it to 0 until we insert a whitespace:
    "
    "     matchstr(getline('.'), '.\%'.col('.').'c') =~# '\s'
    "
    " … or we are at the beginning of a new line.
    "
    "     col('.') == 1

        if matchstr(getline('.'), '.\%'.col('.').'c') =~# '\s' || col('.') == 1

    " If the text changed AND a completion was done, we reset: {{{
    "
    "     - s:completedone
    "
    "     When this flag is on, the function doesn't invoke an autocompletion.
    "     So it needs to be off for the next time the function will be called.
    "
    "     - g:mc_manual
    "
    "     When this variable /flag is on, it means the completion was initiated
    "     manually.
    "     We can use this info to temporarily disable a too costful method when
    "     autocompletion is enabled, but still be able to use it manually.
    "
    "     For example, we could disable the 'thes' method:
    "
    "         let g:mc_conditions.thes =  { t -> g:mc_manual && !empty(&l:thesaurus) }
    "
    "     Now, the `thes` method can only be tried when 'thesaurus' has
    "     a value, AND the completion was initiated manually by the user.
    "
    "     Why do we reset it here?
    "     Inside mycompletion#tab_complete(), it's set to 1.
    "     Inside mycompletion#enable_auto(), it's set to 0.
    "
    "     Now think about this. Autocompletion is enabled, and we've inserted
    "     some text which hasn't been autocompleted, because the text before
    "     the cursor didn't match `g:mc_auto_pattern`.
    "     We still want a completion, so we hit Tab.
    "     It sets `g:mc_manual` to 1. We complete our text, then go on typing.
    "
    "     Now, `g:mc_manual` will remain with the value 1, while
    "     autocompletion is still active. It means autocompletion will try all
    "     the methods in the chain, even those that we wanted to disable.
    "     To prevent that, we reset it here.
    "
    "     "}}}

            let s:completedone = 0
            let g:mc_manual = 0
        endif

        " Why do we call mycompletion#file#complete()? {{{
        "
        " Usually, when a completion has been done, we don't want
        " autocompletion to be invoked again right afterwards.
        "
        " Exception:    'file' method
        "
        " If we just autocompleted a filepath component (i.e. the current method
        " is 'file'), we want autocompletion to be invoked again, to handle the
        " next component, in case there's one.
        " We just make sure that the character before the cursor is in 'isf'.
"}}}
        " Why do we use `get()`? {{{
        "
        " Without it, sometimes, we have an error such as:
        "
        "     Error detected while processing function <SNR>67_act_on_textchanged:
        "     line   81:
        "     E684: list index out of range: 0
        "     Error detected while processing function <SNR>67_act_on_textchanged:
        "     line   81:
        "     E15: Invalid expression: s:methods[s:i] ==# 'file' && matchstr(getline('.'), '.\%'.col('.').'c') =~# '\v\f'
        "
        ""}}}

        if get(s:methods, s:i, '') ==# 'file' && matchstr(getline('.'), '.\%'.col('.').'c') =~# '\v\f'
            sil call mycompletion#file#complete()
        endif

    " Purpose of g:mc_auto_pattern: {{{
    "
    " strpart(…) matches the characters from the beginning of the line up
    " to the cursor.
    "
    " We compare them to `{g:|b:}mc_auto_pattern`, which is a pattern
    " such as: `\k\k$`.
    "
    " This pattern conditions autocompletion.
    " If its value is `\k\k$`, then autocompletion will only occur when the
    " cursor is after 2 keyword characters.
    " So, for example, there would be no autocompletion, if the cursor was after
    " ` a`, because even though `a` is in 'isk', the space is not.
    "
    " It allows the user to control the frequency of autocompletions.
    " The longer and the more precise the pattern is, the less frequent the
    " autocompletions will be.
    "
    " \a\a is longer than \a, and \a is more precise than \k
    " So in increasing order of autocompletion frequency:
    "
    "     \a\a  <  \a  <  \k
"}}}

    elseif getline('.')[:col('.')-2] =~#
                \  { exists('b:mc_auto_pattern') ? 'b:' : 'g:' }mc_auto_pattern

        sil call feedkeys("\<plug>(MC_Auto)", 'i')
    endif
endfu

" can_complete {{{1
"
" Purpose:
"
" During `s:next_method()`, test whether the current method can be applied.
" If it's not, `s:next_method()` will try the next one.

fu! s:can_complete() abort
    return get({ exists('b:mc_conditions') ? 'b:' : 'g:' }mc_conditions,
                \ s:methods[s:i], s:yes_you_can)(s:word)
endfu

" complete {{{1

" Why don't we merge this function with `next_method()`? {{{
"
" Because, among other things, the latter would reset `s:i` each time it would
" be called, so the index of the method to try would be stuck on the same value.
"
" We couldn't merge it into `tab_complete()` either, because we want to use
" the latter for when we hit Tab manually, not for autocompletion.
" Eventually, hitting Tab will call `complete()`, and autocompletion also
" calls (directly) this function. That's why we simply call it `complete()`,
" because all kind of completions (manual/auto) use it.
"
" BUT, by making the 2 kind of completions call different functions / hook
" into the algo at different points, we can implement some logic, such as:
"
"     - if the completion is automatic, don't try this method because it's too
"                                       expensive
"
"     - "                    manual,    try first to expand a snippet
" }}}

fu! mycompletion#complete(dir) abort
    let s:word = matchstr(getline('.')[:col('.')-2], '\S\+$')
    if s:word !~ '\k'
        return (a:dir > 0 ? "\<plug>(MC_Tab)" : "\<plug>(MC_C-d)")
    endif

    let s:cycling = 0
    let s:dir     = a:dir

    let s:i_history = []
    let s:i         = s:dir > 0 ? -1 : s:N

    let s:methods = get(b:, 'mc_chain', g:mc_chain)
    let s:N       = len(s:methods)

    return s:next_method()
endfu

" cycle {{{1

" Why don't we merge this function with `cycle_or_select()`? {{{
"
" Because of the mappings c-j and c-o which cycle in the chain. They don't want
" to call `cycle_or_select()`, their purpose is really to call `cycle()`.
"
"}}}

fu! mycompletion#cycle(dir) abort
    let s:cycling   = 1
    let g:mc_manual = 1
    let s:dir       = a:dir
    let s:i_history = []

    return "\<plug>(MC_C-e)".s:next_method()
endfu

" disable_auto {{{1

fu! mycompletion#disable_auto() abort
    if exists('#MC_Auto')
        autocmd! MC_Auto
        augroup! MC_Auto
    endif
    let s:auto = 0
endfu

" enable_auto {{{1

fu! mycompletion#enable_auto() abort
    let s:auto         = 1
    let s:completedone = 0
    let g:mc_manual    = 0

    augroup MC_Auto
        autocmd!

        " When are `CompleteDone` and `TextChangedI` triggered? {{{
        "
        " `CompleteDone` is triggered after each method tried, regardless whether
        " it succeeds or fails.
        "
        " `TextChangedI` is triggered when we insert some text manually, or once
        " we select and validate an entry in a completion menu.
        "
        " But what happens if the completion fails or we exit the menu?
        " It depends of the kind of completion:
        "
        "         C-x C-G ('digr')    → does NOT trigger TextChangedI
        "         C-x C-S
        "         C-x C-V
        "         C-x C-Z ('unic')
        "
        "         C-x C-D             → triggers TextChangedI
        "         C-x C-F
        "         C-x C-I
        "         C-x C-K
        "         C-x C-L
        "         C-x C-N
        "         C-x C-O
        "         C-x C-P
        "         C-x C-T
        "         C-x C-U
        "         C-x C-]
        "
        " However, in our custom completion code, when all the methods fail,
        " it's hard to tell if and/or when it occurs.
        " At the end of `s:next_method()`, the keys which are returned look
        " something like this:
        "
        "     C-x C-n … Plug(MC_next_method)
        "
        " Now, write this inside vimrc:
        "
        "     imap        <Tab>             <C-x><C-n><Plug>(MyFunc)
        "     ino  <expr> <Plug>(MyFunc)    MyFunc()
        "
        "     fu! MyFunc()
        "         return ''
        "     endfu
        "
        "     let g:tci = 0
        "     augroup TEST
        "         au!
        "         au TextChangedI * let g:tci += 1
        "     augroup END
        "
        " Write some unique text, and save / source vimrc (to reset `g:tci`).
        " Go into insert mode at the end of the unique text, and hit Tab after it to
        " try a completion.
        " Look at the value of `g:tci`. It's still 0.
        " Now, change `MyFunc()` like this:
        "
        "     fu! MyFunc()
        "         return "\<c-x>\<c-v>"
        "     endfu
        "
        " This time, hitting Tab will increment `g:tci`, meaning
        " `TextChangedI` occurred. But did it occur after `c-x c-n` or after
        " `c-x c-v`?
        " So depending on the value of the chain, `TextChangedI` may or may
        " not occur. And when it does, I don't know at which point(s) in the
        " chain it occurs.
        "
        " Another way to watch when both `TextChangedI` and `CompleteDone` occur:
        "
        "     let g:debug = { 'cd' : 0, 'tci' : 0, }
        "     augroup TEST
        "         au!
        "         au TextChangedI * let g:debug.tci += 1
        "         au CompleteDone * let g:debug.cd += 1
        "     augroup END
        "
        ""}}}

        autocmd TextChangedI  * call s:act_on_textchanged()

        " Why don't we define `s:completedone` as `!empty(v:completed_item)`? {{{
        " Because it could make autocompletion hit Tab indefinitely.
        " Here's how to reproduce this bug:
        "
        "     1. let g:mc_chain = [ 'keyn', 'cmd' ]
        "
        "     2. open a buffer and write `test`
        "
        "     3. write `te`, the autocompletion kicks in and suggests `test`
        "        accept and insert
        "
        "     4. write `va` → autocompletion keeps trying to complete `va`
        "
        " FIXME:
        "
        " It's a weird bug, because if we write `va` on a different line, it
        " doesn't occur.
        "
        " Anyway, why WAS it tempting to redefine `s:completedone` like this?
        "
        " We want to use `s:completedone` to prevent an autocompletion to be
        " performed right after a successful one.
        " In this case defining it as `1` would be enough.
        " BUT we wanted to allow an autocompletion after a failed one.
        " `1` isn't enough anymore.
        "
        " But if the last failed, does it make sense to try a new one?
        " It depends on which text a given method is trying to complete.
        " If a method tries to complete this:
        "
        "     matchstr(getline('.')[:col('.')-2], '\S\+$')
        "
        " … then it doesn't make sense to try an autocompletion after a failed one.
        " Because inserting a new character will make the text to complete even harder.
        " So, if it failed last time, it will fail with this new character.
        " However, it can make sense with some methods, like 'digr', which tries to
        " complete only the last 2 characters.
        " In this case, inserting a new character doesn't make the text harder to
        " complete, it just makes it different.
        " It can be checked when we insert the text `xtxv`.
        " If we define `s:completedone` as `1`, no autocompletion is tried against
        " `xv` to suggest us `✔`.
        " OTOH, if we define it as `!empty(v:completed_item)`, we get an
        " autocompletion.
"}}}

        autocmd CompleteDone * let s:completedone = 1
    augroup END
endfu

" menu_is_up {{{1

" Purpose: {{{
"
" just store 1 in `s:pumvisible`, at the very end of `s:next_method()`,
" when a method has been invoked, and it succeeded to find completions displayed
" in a menu.
"
" `s:pumvisible` is used as a flag to know whether the menu is open.
" This flag allows `mycompletion#verify_completion()` to choose between acting
" on the menu if there's one, or trying another method.
"
" It's reset to 0 at the beginning of `s:act_on_pumvisible()`.
"
"}}}

fu! mycompletion#menu_is_up() abort
    let s:pumvisible = 1
    return ''
endfu

" next_method {{{1

" Description {{{
"
" s:next_method() is called by:
"
"     - mycompletion#verify_completion()    after a failed completion
"     - mycompletion#complete()             1st attempt to complete (auto / manual)
"     - mycompletion#cycle()                when we cycle
"
"}}}
" Purpose: {{{
"
" The function is going to [in|de]crement the index of the next method to try.
" It does it one time.
" Then it checks whether this next method can be applied.
" If it's not, it [in|de]crement it repeatedly until:
"
"     - it finds one if we're cycling
"     - it finds one OR we reach the beginning/end of the chain if we're not cycling
"
"}}}

fu! s:next_method() abort
    if s:cycling

        " Explanation of the formula: {{{
        "
        " Suppose we have the list:
        "
        "     let list = ['foo', 'bar', 'baz', 'qux']
        "
        " And we want `var` to get a value from this list, then the next,
        " then the next, …, and when we reach the end of the list, we want the
        " variable to get the first item.
        "
        " To store a value from `list` inside `var`, we can write:
        "
        "     let var = list[idx]
        "
        " … where `idx` is just a number.
        "
        " But what's the relation between 2 consecutive indexes?
        " It can't be as simple as:
        "
        "     next_idx = cur_idx + 1
        "
        " … because even though it will work most of the time, it will fail
        " when we reach the end of the list.
        "
        " Here is a working formula:
        "
        "     next_idx = (cur_idx + 1) % 4
        "
        " … where `4` is the length of the list.
        "
        " Indeed, when the current index is below the length of the list,
        " the modulo operator (%4) won't change anything.
        " But when it will reach the end of the list (3), the modulo operator
        " will make the next index go back to the beginning:
        "
        "     (3 + 1) % 4 = 0
        "
        " It works because VimL (and most other programming languages?)
        " indexes a list beginning with 0 (and not 1).
        " If it began with 1, we would have to replace `%4` with `%5`.
        "
        " Here is a general formula:
        "
        "     next_idx = (cur_idx + 1) % N
        "
        " … where N is the length of the list we're indexing.
"
"}}}
        " Why do we add `s:N` ? {{{
        "
        " At the end of this function, before hitting the completion mappings,
        " we will make sure that `s:i` is different than `-1` and `s:N`.
        "
        " Because, if we aren't cycling, and the value of `s:i` is `-1`
        " or `s:N`, it means we've tested all the methods in the chain.
        " It's pointless to go on. We could even get stuck in a loop if no
        " methods can be applied. Besides, `s:methods[s:N]` does not even exist.
        "
        " So, this check is necessary. But it cause an issue.
        " If we've hit `C-o` to go back in the chain (`s:cycling` is set), and we
        " reach the beginning of the chain (s:i = 0), we won't be able to get
        " back any further. We won't be able to go back to the end of the
        " chain, because the function won't even try the last / -1 method.
        "
        " To allow `C-o` to go back to the end of the chain, in the definition
        " of `s:i`, we add `s:N`.
        " When `s:i` is different than -1, it won't make any difference,
        " because of the `% s:N` operation.
        " But when the value of `s:i` is -1, adding `s:N` will convert the
        " negative index into a positive one, which matches the same method in
        " the chain. The last one.
        "
        " "}}}

        let s:i = (s:i + s:dir + s:N) % s:N

        " Why is there no risk to be stuck in a loop? {{{
        "
        " We could be afraid to be stuck in a loop, and to prevent that, add the
        " condition that `s:i` is different than `-1` and `s:N`.
        "
        " But it's unnecessary. We can't be stuck in a loop.
        " Indeed, if we're cycling, it means that the popup menu is currently
        " visible and that a method was successful.
        " So, when we're cycling, we can be sure that there's AT LEAST one method
        " which can be applied, i.e. a method for which `s:can_complete()` returns
        " true/1.
        "
        " Besides, `s:i` can be equal to `-1` or `s:N`.
        " It can't be equal to `s:N` because it was defined as the result of
        " a `% s:N` operation. The result of such operation can't be `s:N`.
        " When you divide something by `n`, the rest is necessarily inferior
        " to `n`.
        " And it can't be equal to `-1`, because in the definition, we add `s:N`
        " so the result is necessarily positive (zero included).
"}}}

        while !s:can_complete()
            let s:i = (s:i + s:dir + s:N) % s:N
        endwhile

    else

        " We will get out of the loop as soon as: {{{
        "
        "     the next idx is beyond the chain
        " OR
        "     the method of the current idx can be applied

        " Condition to stay in the loop:
        "
        "     (s:i+1) % (s:N+1) != 0    the next idx is not beyond the chain
        "                                 IOW there IS a NEXT method
        "
        "     && !s:can_complete()        AND the method of the CURRENT one can't be applied
        "
        ""}}}

        let s:i += s:dir

        " Why the first 2 conditions? {{{
        "
        " In the previous case (`if s:cycling`), the only condition to stay in
        " the loop was:
        "
        "     !s:can_complete()
        "
        " This time, we have to add:
        "
        "     s:i != -1 && s:i != s:N
        "
        " Indeed, we aren't cycling. We've just hit Tab/S-Tab.
        " So, we don't know whether there's a method which can be applied.
        " If there's none, we could be stuck in a loop.
        " This additional condition makes sure that we stop once we reach the
        " beginning/end of the chain. It wouldn't make sense to go on anyway,
        " because at that point, we would have tried all the methods.
"}}}

        while s:i != -1 && s:i != s:N && !s:can_complete()
            let s:i += s:dir
        endwhile
    endif

    " After the while loop: {{{
    "
    "     if (s:i+1) % (s:N+1) != 0
    "
    " … is equivalent to:
    "
    "     if s:can_complete()
    "
    " Why don't we use that, then?
    " Probably to save some time, the function call would be slower.
    "
    " What's the meaning of:
    "
    "     && index(s:i_history, s:i) == -1
    "
    " … ? We want to make sure that the method to be tried hasn't already been
    " tried since the last time the user was cycling.
    " Otherwise, we could be stuck in an endless loop of failing methods.
    " For example:
    "
    "       2 → 4 → 2 → 4 → …
    "
    ""}}}
    " FIXME: {{{
    "
    " Lifepillar writes:
    "
    "     (s:i+1) % (s:N+1) != 0
    "
    " I prefer:
    "
    "     s:i != -1 && s:i != s:N
    "
    " It it really equivalent?
    "
    " Besides, currently, lifepillar's expression states that `s:i` is different
    " than `-1` and `s:N`, but could it be extended to any couple of values
    " `a` and `b`?
    "
    " IOW:
    "
    "     x != - 1  &&  x != b    ⇔    (x + 1) % (b + 1) != 0
    "     x != a    &&  x != b    ⇔    ???
    "
    "     "}}}
    " Why the 2 first conditions? {{{
    "
    " If we're cycling, `s:i` can't be `-1` nor `s:N`.
    " However, if we are NOT cycling (Tab, S-Tab), then if all the
    " methods failed, we could reach the beginning/end of the chain and then
    " `s:i` could be `-1` or `s:N`.
    "
    " In this case, we don't want to try a method.
    " Indeed, we could be stuck in a loop, and it doesn't make any sense to
    " try any further. At that point, we would have tested all the existing
    " methods. Besides, there's no `s:methods[s:N]` (but there is
    " a `s:methods[-1]`).
    "
    " Therefore, before hitting the completion mappings, we make sure that
    " `s:i` is different than `-1` and `s:N`.
"}}}

    if s:i != -1 && s:i != s:N && index(s:i_history, s:i) == -1

        " If we're cycling, we store the index of the method to be tried, in a
        " list. We use it to compare its items with the index of the next method
        " to be tried.

        if s:cycling
            let s:i_history += [s:i]
        endif

        " 1 - Type the keys to invoke the chosen method. {{{
        "
        " 2 - Store the state of the menu in `s:pumvisible` through
        "     `mycompletion#menu_is_up()`.
        "
        " 3 - call `mycompletion#verify_completion()` through `<plug>(MC_next_method)`
        "
        ""}}}
        " Why use C-r twice?{{{
        "
        " Usually it's used to insert the contents of a register literally.
        " To prevent the interpretation of special characters like backspace:
        "
        "     register contents         insertion
        "     xy^Hz                →    xz
        "
        " Here we insert the expression register, which will store an empty
        " string. There's nothing to interpret. So, we don't need it two C-r .
        " But it's a precaution (more future-proof). No matter what we insert
        " with this plugin, there should never by any interpretation.
"}}}
        return s:compl_mappings[s:methods[s:i]] .
                    \ "\<c-r>\<c-r>=pumvisible()?mycompletion#menu_is_up():''\<cr>\<plug>(MC_next_method)"
    endif

    " Why do we reset `s:i` here? {{{
    "
    " Consider some unique text, let's say 'jtx', and suppose autocompletion is
    " enabled.
    " When I will insert `x`, an error will occur inside `s:act_on_textchanged()`.
    " Specifically when it will try to get:
    "
    "     s:methods[s:i]
    "
    " The error occurs because at that moment, `s:i` = `s:N`, and there's no
    " method whose index is `s:N`. `s:N` is the length of the chain, so the
    " biggest index is `s:N - 1`.
    "
    " But what leads to this situation?
    "
    " When I insert the 1st character `j`, `TextChangedI` is triggered and
    " `s:act_on_textchanged()` is called. The function does nothing if:
    "
    "     g:mc_auto_pattern = \k\k$
    "
    " Then I insert `t`. `TextChangedI` is triggered a second time, the function
    " is called again, and this time it does something, because `jt` match the
    " pattern `\k\k$`.
    " It hits `Tab` for us, to try to autocomplete `jt`.
    " If the text is unique then all the methods in the chain will fail, and `s:i`
    " will end up with the value `s:N`.
    " Even though the methods failed, `CompleteDone` was triggered after each of
    " them, and `s:completedone` was set to `1` each time.
    " `TextChangedI` was NOT triggered, because of our `Plug(MC_next_method)`
    " mapping at the end of `s:next_method()`, so `s:act_on_textchanged()` is not
    " called again.
    " Finally, when we insert `x`, `TextChangedI` is triggered a last (3rd) time,
    " `s:act_on_textchanged()` is called and it executes its first block of code
    " which requires to get the item `s:methods[s:i]`.
    "
    " A solution is to use get() like lifepillar did, but it only treats the
    " consequences of some underlying issue.
    "
    " I want to also treat the issue itself. Because who knows, maybe it could
    " cause other unknown issues in the future.
    "
    " To tackle the root issue, we reset `s:i` to 0, here, when no completion
    " mapping was hit and when `s:i = s:N`.
"}}}

    if s:i ==# s:N
        let s:i = 0
    endif

    return ''
endfu

" setup_dict_option {{{1

fu! s:setup_dict_option() abort
    "                                               ┌─ there should be at least 2 characters in front of the cursor
    "                                               │  otherwise, `C-x C-k` could try to complete a text like:
    "                                               │      #!
    "                                               │
    "                                               │  … which would take a long time, because it's not a word
    "                                               │  so, all the words of the dictionary could follow/match
    "                                               │
    if index([ 'en', 'fr' ], &l:spelllang) != -1 && strchars(matchstr(getline('.'), '\k\+\%'.col('.').'c'), 1) >= 2
        let &l:dictionary = &l:spelllang ==# 'en' ? '/usr/share/dict/words' : '/usr/share/dict/french'
        return 1
    else
        return 0
    endif
endfu

" setup_isk_option {{{1

fu! s:setup_isk_option() abort
    " most default ftplugins don't include `-` in 'isk', but it's convenient
    " to include it temporarily when we complete a word
    "
    " so we add it, then remove it later with a timer
    " however some default ftplugins DO include `-` in 'isk', we shouldn't
    " remove it for them
    " How to find which default ftplugins include `-` in 'isk'?
    "
    "     :PA (in $VIMRUNTIME/ftplugin/)
    "     vimgrep /\vsetl%[ocal]\s+isk%[eyword]\+?\=.*-%(\@|\w)@!/ ##

    " we do the same thing for `:` (convenient to complete local variable names)
    if index(['clojure', 'lisp', 'scheme'], &ft) == -1
        setl isk+=- isk+=:
        let timer = timer_start(0, {-> execute('setl isk-=- isk-=:', '')})
    endif
    return 1
endfu

" snippet_or_complete {{{1

fu! mycompletion#snippet_or_complete(dir) abort
    if pumvisible()
        return a:dir > 0 ? "\<c-n>" : "\<c-p>"
    endif

    call UltiSnips#ExpandSnippet()

    if !g:ulti_expand_res
        if a:dir > 0
            call UltiSnips#JumpForwards()
            if !g:ulti_jump_forwards_res
                call feedkeys("\<plug>(MC_tab_complete)", 'i')
            endif
        else
            call UltiSnips#JumpBackwards()
            if !g:ulti_jump_backwards_res
                call feedkeys("\<plug>(MC_stab_complete)", 'i')
            endif
        endif
    endif

    let s:completedone = 0
    let g:mc_manual    = 0

    return ''
endfu

augroup autocompletion_during_snippet_expansion
    au!
    au User UltiSnipsEnterFirstSnippet call s:setup_auto()
    au User UltiSnipsExitLastSnippet   call s:teardown_auto()
augroup END

fu! s:setup_auto() abort
    let s:is_in_auto_mode = s:auto
    McAutoEnable
endfu

fu! s:teardown_auto() abort
    if !s:is_in_auto_mode
        McAutoDisable
    endif
endfu

" tab_complete {{{1

" Why don't we merge this function with `complete()`? {{{
"
" If we did that, every time `complete()` would be called, `g:mc_manual` would
" be set to 1. It would be wrong, when `complete()` would be called by the
" autocompletion (`<Plug>(MC_Auto)`).
"
" We could find a workaround, by passing a second argument to `complete()`
" inside the mappings Tab, S-Tab, and <plug>(MC_auto).
" It would serve as a flag whose meaning is whether we're performing a manual
" or automatic completion.
" But, it means that every time the autocompletion would kick in, it would
" test whether the popup menu is visible. It could make it a bit slower…
"
""}}}

fu! mycompletion#tab_complete(dir) abort
        let g:mc_manual = 1
        return mycompletion#complete(a:dir)
endfu

" toggle_auto {{{1

fu! mycompletion#toggle_auto() abort
    if exists('#MC_Auto')
        call mycompletion#disable_auto()
        echom '[MC] Auto off'
    else
        call mycompletion#enable_auto()
        echom '[MC] Auto on'
    endif
endfu

" verify_completion {{{1

" Purpose: {{{
"
" It's invoked by `<plug>(MC_next_method)`, which itself is typed at
" the very end of `s:next_method()`.
" It checks whether the last completion succeeded by looking at
" the state of the menu.
" If it's open, the function calls `s:act_on_pumvisible()`.
" If it's not, it recalls `s:next_method()` to try another method.
"
"}}}

fu! mycompletion#verify_completion() abort
    return s:pumvisible
        \?     s:act_on_pumvisible()
        \:     s:next_method()
endfu
