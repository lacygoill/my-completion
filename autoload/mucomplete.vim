" FIXME: "{{{
"
" If I hit C-x C-p C-k at the end of this line:
"
"     License: This file
"
" I have the following error:
"
"         Error detected while processing function
"         mucomplete#cycle[2]..<SNR>66_next_method:
"         line    1:
"         E121: Undefined variable: s:N
"         Error detected while processing function
"         mucomplete#cycle[2]..<SNR>66_next_method:
"         line    1:
"         E15: Invalid expression: (s:cycle ? (s:i + s:dir + s:N) % s:N : s:i + s:dir)
"
" Note:
" C-k is used to cycle backward in the completion chain.
" By default, it was C-h. I changed the mapping.
" The bug occurs when you type a key to move backward OR forward in the chain,
" without having hitting Tab once before;
" and you have:
"
"     let g:mc_cycle_with_trigger = 1
"
" … in your vimrc
"
" In fact, the bug occurs when the user asks to move in the chain (cycle)
" without having invoked a method in the chain at least once.
"
" Initially, I thought the solution was to initialize `s:N` in `cycle()`,
" exactly as it was defined in `complete()`.
" But then, I realized that it wasn't a good idea to let the user call
" `s:next_method()`, without having entered the chain at least once.
" If he's never entered the chain, he has no position inside it.
" So, there's no reference point on which base our relative motion in the chain.
" IOW, it doesn't make sense to try and support this weird / edge case.
"
" Maybe the best solution is to prevent `s:next_method()` to be called
" when the user never invoked a methode in the chain.
"
" How do we know whether they invoked a method?
" If they did, the `mucomplete#complete()` function was invoked at least once.
" It it was, it must have created the variable `s:N`.
" Besides, `s:N` is only created inside `mucomplete#complete()`, nowhere else.
" It means there's an equivalence between the existence of this variable and the
" user having invoked a method at least once.
"
" So, to fix this bug, inside `mucomplete#cycle()` we could test the existence
" of `s:N` before invoking `s:next_method()`.
"
"}}}
"FIXME: "{{{
"
" Write this in `/tmp/vimrc.vim`:

" let g:mucomplete#cycle_with_trigger = 1
" let g:mc_cycle_with_trigger = 1
" set cot=menuone
" set rtp+=~/.vim/plugged/vim-mucomplete
" setlocal tw=78
"
"    xx                                                  zzz
" zzzyyyyyyyyyyyyyyyyyyy


" Uncomment the 5 first lines of code.
" Launch Vim like this:
"
"     $ vim -Nu /tmp/vimrc.vim /tmp/vimrc.vim
"
" Place the cursor after `zzz` and hit Tab twice.
" The plugin gets stuck in a loop (high cpu).
"
" In fact we don't even need the first 2 lines.
" We can reproduce the bug without them, by hitting the key to move
" forward in the completion chain (C-j, …).

" The problem comes from the fact that `s:next_method()` fails to see that
" the popup menu is visible.
" Maybe because in this particular configuration, the menu can't be opened, or
" because there's some delay.
" Therefore, the variable `s:pumvisible` is not set properly (1).
"
" After hitting the completion mappings, and incorrectly set the `s:pumvisible`
" variable, `s:next_method()` hit `<plug>(MUcompleteNxt)`, which calls
" `verify_completion()`.
" The latter relies on `s:pumvisible` to decide whether it should call `act_on
" pumvisible()` or try another method and recall `s:next_method()`.
"
" The endless loop can be observed by creating global variables at various
" places in `s:next_method()`, then triggering the bug, and finally echo their
" values.
" For example, assuming we use this chain:

"         let g:mc_chain = ['file', 'omni', 'keyn', 'dict', 'spel', 'path', 'ulti']
"
" … if we add the line:
"
"         let g:idx_list   = get(g:, 'idx_list', []) + [s:i]
"
" … just after:
"
"         let s:i = (s:i + s:dir + s:N) % s:N
"
" When we echo `g:idx_list`, we get a big list of 3's ([3, 3, 3, …]).

" If we add the line:
"
"         let g:idx_list   = get(g:, 'idx_list', []) + [s:i]
"
" … just after (`s:cycle` is set to 1):
"
"         let s:i = (s:i + s:dir + s:N) % s:N
"
" When we echo `g:idx_list`, we get a circular list:
"
"         [4, 5, 6, 0, 1, 2, 4, 5, 6, 0, 1, 2, …]
"
" If we add the line:
"
"         let g:idx_list   = get(g:, 'idx_list', []) + [s:i]
"
" … just after the while loop, when we echo `g:idx_list`, we get a big list of
" 2's ([2, 2, 2, …]).
"
" Which shows that each time `s:next_method()` is called, it finds the same
" next method, n°2.
"
" To prevent this, before hitting the completion mappings, we have to ask
" `s:next_method()` to check whether the next method is different than the
" current one.
" To do so, we can store the current index in a variable at the beginning of
" the function:
"
"         let old_i = s:i
"
" Then, add to the test:
"
"         if (s:i+1) % (s:N+1) != 0
"
" … (which conditions whether the completion mappings will be hit), the
" following statement:
"
"         … && s:i != old_i
"
" There's still a problem though I haven't encountered yet though.
" Maybe in some particular circumstances, we could get stuck in a different
" kind of loop…
" Imagine, `s:next_method()` finds that the next method to try is `2`.
" It tries it, but it fails. So, `s:next_method()` is recalled.
" This time, it finds that the next method to try is `4`.
" It tries it, but it fails. So, `s:next_method()` is recalled.
" This time, it finds that the next method is, again, `2`.
"
" At this moment, we could be entering a loop from which we couldn't get out,
" even with the `old_i` variable.
"
" I've been thinking at a more robust solution to this problem.
" When `s:cycle` is set to 1, maybe we should create a variable
" (`s:i_history`), in which we would store all the indexes of the
" methods tried.
" Inside `s:next_method()`, before hitting a completion mapping, we would
" make sure that the index of the method we're going to try is not in this
" list.
" This should prevent any kind of spurious loop.
" Finally, when `s:cycle` is set to 0, we would empty the list, so that the
" methods whose indexes are in this temporary list could be tested again, the
" next time we would ask for a completion via Tab or via a new cycle (C-h, C-l).
"
"}}}
" FIXME: "{{{
"
" I think lifepillar made a conceptual mistake in the original code.
" He allowed the user to define its own version of
" `g:mucomplete#can_complete.default`
" Then, the plugin merges whatever the user defined in there with some default
" value, via `extend()`.
" It works, but if the user source their vimrc a second time, the default
" values of the plugin are lost.
"
""}}}
" FIXME:"{{{
"
" In the `ulti` method, I think lifepillar introduced a regression here:
"
"     https://github.com/lifepillar/vim-mucomplete/issues/28
"
" Because, he inverted the order of the arguments passed to `stridx()`, which
" seems to prevent the `ulti` method to function properly.
"
" "}}}
" FIXME: "{{{

" In the completion mapping for the 'spel' method:
"
"         \ 'spel': "\<c-o>:\<cr>\<c-r>=mucomplete#spel#complete()\<cr>",
"
" … why do we prefix it with `\<c-o>:\<cr>`?
"
" If we configure the chain completion, like this:
"
"         let g:mc_chain = ['keyn', 'spel']
"
" … we enter a buffer and enable the spell correction (`cos`),
" we type `helo`, and hit `Tab` to complete/correct the word into `hello`.
" The menu opens but when we type `C-n`, it doesn't select the first entry.
" It gives us the message:
"
"         Keyword Local completion Back at original
"
" The second time we hit `C-n`, we can finally choose our correction.
" But why only after the 2nd time?
" And why does it seem that the plugin tries the `keyn` method?
" `C-n` shouldn't make it do that.
"
" The current solution seems this weird prefix.
" But I don't understand it.

""}}}
" FIXME: "{{{
"
" Given the following buffer `foo`:
"
"     hello world
"     hello world
"     hello world

" And the following `vimrc`:
"
"     set cot+=noselect,menu,menuone
"     set rtp+=~/.vim/plugged/vim-mucomplete

" Start Vim like this:
"
"     $ vim -Nu vimrc foo
"
" Hit `*` on `world` to populate the search register.
" Type `cgn`, to change the last used search pattern.
" Insert `wo`, then `Tab` to complete `wo`.
" Hit escape to go back in normal mode.
" Hit `.` to repeat the change to the next occurrence of `hello`.
" `hello` is changed into `wo` instead of the last completed text.
"
" Does the plugin breaks the undo sequence when we hit Tab?
" Yes, it seems that `s:act_on_pumvisible()` sometimes hit Up or Down,
" to force the insertion of an entry, no matter the value of 'cot'.
" It probably breaks the undo sequence, and somehow the dot command/register
" only remembers what was inserted before.
"
" This is a bit weird, because when the undo sequence is broken, dot usually
" remembers what was inserted AFTER (not before).
" You can check it by inserting foo, then hitting `Up` or `Down`, then inserting
" bar. Leave insert mode then hit dot. `bar` will be inserted, not `foo`.
"
" Anyway, Up/Down breaks the undo sequence, so whatever the dot command will
" remember, it will always be incomplete.
"
" But the problem isn't always present. It depends on the value of 'cot'.
" In the original plugin, the bug occurs when 'cot' contains 'noselect', or
" when it doesn't contain 'noselect', but does contain 'noinsert'.
"
" I fixed the bug in the the 2nd case, by replacing `Up` with `C-p`.
" But I didn't fixed it in the 1st case.
" Indeed, in the 2nd case, 'cot' contains ONLY 'noinsert'.
" So, the user just wants to prevent the insertion; he's still OK with the
" selection.
" All we have to do to force the insertion is sth like:
"
"         Up  C-n    (lifepillar) works but breaks   undo sequence
"         C-p C-n    (me)         works and preserve undo sequence
"
" However, in the 1st case, the user has 'noselect', so he doesn't want an
" entry to be selected. In this case, Vim doesn't do anything. To force, the
" insertion without selecting anything (to respect the user's decision),
" there's only one solution:
"
"         C-n Up    (lifepillar) works but breaks undo sequence
"
" The other solutions would either not work or violate a user's decision:
"
"         C-n       (me)         works but doesn't respect the user's decision
"                                of not selecting an entry
"
"         C-n C-p   (me)         doesn't work at all
"                                C-n would temporarily insert an entry,
"                                then C-p would immediately remove it
"
"}}}
" FIXME: "{{{
"
" The 'uspl' method of lifepillar doesn't work when the cursor is just at the
" end of word but not at the end of the line.
" Example:
"
"     helzo| people
"
" The pipe represents the cursor, where the method is invoked.
" 'uspl' tries to fix the word `people` instead of `helzo`.
" It probably comes down to the usage of the `:norm` command.
"
" Besides the method uses 2 functions, one to collect suggestions, and another
" to display them in a menu.
"
" One function could be enough. And we could get rid of the problematic
" `:norm` command, using the `spellbadword()` and `spellsuggest()` functions.
" It would fix the first issue.
"
" Tell lifepillar about it. Share our implementation.
" And ask him, why we have to prefix our mapping with `C-o : CR` to avoid
" a spurious bug.
"
"}}}
" FIXME: "{{{
"
" The methods `c-n` and `c-p` are tricky to invoke.
"
" Indeed, we don't know in advance WHEN they will be invoked.
" As the first ones? Or after other failing methods?
"
" For example, if `c-n` is the first method to be invoked after hitting Tab,
" then there's NO problem.
" But if it's invoked after another one, there MIGHT be a problem.
" Suppose the previous failing method left us in `C-x` submode (C-x C-…),
" then `C-n` will be interpreted, WRONGLY, as an attempt to cycle in the menu.
" So, we should prefix `C-n` with `C-e` to exit `C-x` submode, right?
" Nope.
" Because then, if the `C-n` method was the first one to be invoked, then
" `C-e` will be interpreted as ’copy the character below the current one’.
"
" MUcomplete.vim chooses the solution of prefixing the trigger keys with:
"
"         C-x C-b BS
"
" What does it do?
" `C-b` is not a valid key in C-x submode. Any invalid key makes us leave the
" submode, and is inserted. So, we leave the submode, C-b is inserted, and BS
" deletes it.
" And why did lifepillar choose SPECIFICALLY C-b?
" For 2 reasons.
"
"     1 - It's invalid in C-x submode, as we just saw it.
"     2 - It's unmapped in basic insert mode, see: :h i_CTRL-B-gone
"
" So, C-b is a good choice because it won't cause any side-effect.
"
" All in all, this trick works.
" BUT, there's a problem for me. I have remapped C-B to move the cursor back.
" Because of this, the trick won't work.
"
" We have to choose another key. I'm going to use `C-g C-g`.
" Why this key?
" Because by default, C-g is used as a prefix in insert mode for various kind
" of actions. To get a list of them, type: :h i_^g C-d
" Currently, behind this prefix, there is:
"
"         CTRL-J
"         CTRL-K
"         Down
"         Up
"         j
"         k
"         u
"         U
"
" Vim may map other actions in the future on other keys, but for the moment
" nothing is mapped on CTRL-G.
"
" It seems to work, but are we sure it is as good as `C-x C-b`?
" Ask lifepillar what he thinks, here:
"
"     https://github.com/lifepillar/vim-mucomplete/issues/4
"
" But don't ask him to integrate the change. He doesn't want. He added the tag
" `wontfix` and closed the issue.
"
" "}}}
" FIXME: "{{{
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
"
"}}}
" FIXME: "{{{
"
" In the completion mappings (C-x C-f, C-x C-n, …), lifepillar used the prefix
" `s:cnp` (I call it `s:exit_ctrl_x`), only when he thought it was necessary.
" For example, he thought it was not necessary to exit `C-x` submode before
" trying the 'omni' method.
" Indeed, if you try the 'keyn' method and it fails, you can try the 'omni'
" method immediately, without exiting the submode:
"
"     C-x C-n    C-x C-o    ✔
"
" But it seems that the necessity of exiting the submode is not a function of
" only the next method to try, but also of the previous method.
" For example, we need to exit the submode when we just tried the 'cmd' method
" and it failed (no matter the next method, including the 'omni' method):
"
"     C-x C-v (fail)                     C-x C-o    ✘
"     C-x C-v (fail)   {exit submode}    C-x C-o    ✔
"
" So, I ended up using the prefix for all the methods where the completion
" mapping doesn't begin with `C-r =`. Because in this case, it seems there's
" no problem, even if the previous method failed.
"
""}}}
" Why do we need to prepend `s:exit_ctrl_x` in front of "\<c-x>\<c-l>"? "{{{
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

" To look for all the global variables used by this plugin, search the
" pattern:
"         \v^(".*)@!.*\zsg:[^ ,]

" Variables "{{{

let s:exit_ctrl_x    = "\<c-g>\<c-g>"

let s:compl_mappings = {
                       \ 'abbr' : "\<c-r>=mucomplete#abbr#complete()\<cr>",
                       \ 'c-n'  : s:exit_ctrl_x."\<c-n>",
                       \ 'c-p'  : s:exit_ctrl_x."\<c-p>",
                       \ 'cmd'  : s:exit_ctrl_x."\<c-x>\<c-v>",
                       \ 'defs' : s:exit_ctrl_x."\<c-x>\<c-d>",
                       \ 'dict' : s:exit_ctrl_x."\<c-x>\<c-k>",
                       \ 'digr' : s:exit_ctrl_x."\<c-x>\<c-z>",
                       \ 'file' : "\<c-r>=mucomplete#file#complete()\<cr>",
                       \ 'incl' : s:exit_ctrl_x."\<c-x>\<c-i>",
                       \ 'keyn' : s:exit_ctrl_x."\<c-x>\<c-n>",
                       \ 'keyp' : s:exit_ctrl_x."\<c-x>\<c-p>",
                       \ 'line' : s:exit_ctrl_x."\<c-x>\<c-l>",
                       \ 'omni' : s:exit_ctrl_x."\<c-x>\<c-o>",
                       \ 'spel' : "\<c-o>:\<cr>\<c-r>=mucomplete#spel#complete()\<cr>",
                       \ 'tags' : s:exit_ctrl_x."\<c-x>\<c-]>",
                       \ 'thes' : s:exit_ctrl_x."\<c-x>\<c-t>",
                       \ 'ulti' : "\<c-r>=mucomplete#ultisnips#complete()\<cr>",
                       \ 'unic' : s:exit_ctrl_x."\<c-x>\<c-g>",
                       \ 'user' : s:exit_ctrl_x."\<c-x>\<c-u>",
                       \ }
unlet s:exit_ctrl_x

let s:select_entry = { 'c-p' : "\<c-p>\<down>", 'keyp': "\<c-p>\<down>" }
" Internal state
let s:methods      = []
let s:word         = ''

" `s:auto` is a flag which, when it's set, means that autocompletion is enabled.
" Its used by `s:act_on_pumvisible()` to know whether it must insert the first
" entry in the menu. Indeed, when autocompletion is enabled, we don't want to
" automatically insert anything. Bad idea.
" It would constantly insert undesired text, and the user would have to undo
" it. The popup menu with suggestions is enough.

let s:auto         = 0
let s:dir          = 1
let s:cycling      = 0

" Indexes of the methods which have been tried since the last time we asked
" for a cycle.
let s:i_history = []

let s:i          = 0
let s:pumvisible = 0

" Default pattern to decide when automatic completion should be triggered.
let g:mc_trigger_auto_pattern = '\k\k$'

" Default completion chain

let g:mc_chain = [ 'digr' ]
let g:mc_chain = [ 'cmd' ]
let g:mc_chain = [ 'cmd', 'digr' ]

" FIXME:
" When the current method is 'dict', ctrl-k selects the next entry in the menu
" instead of cycling backward in the chain like it should.
" Lifepillar has a similar problem.
" He uses `C-h` and `C-l` to cyle in the chain, instead of `C-k` and `C-j`.
" When the current method is 'line', `C-l` selects the previous entry in the
" menu instead of cycling forward in the chain like it should.

" FIXME:
" We can move forward in the chain by hitting `C-j` as many times as we want.
" We will cycle in the chain: when reaching the end, we go back to the
" beginning.
" But we can't do the same in the other direction.
" Hitting `C-k` stops when we reach the first method in the chain.
" It doesn't matter if it succeeds or if it fails, `C-k` doesn't go back to
" the end of the chain.

let g:mc_chain = [ 'cmd', 'omni', 'spel', 'keyn', 'file', 'keyp' ]

" let g:mc_chain = [
"                  \ 'abbr',
"                  \ 'c-p' ,
"                  \ 'cmd' ,
"                  \ 'dict',
"                  \ 'digr',
"                  \ 'file',
"                  \ 'keyp',
"                  \ 'line',
"                  \ 'omni',
"                  \ 'spel',
"                  \ 'tags',
"                  \ 'ulti',
"                  \ 'unic',
"                  \ ]

" Conditions to be verified for a given method to be applied."{{{
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
                      \ 'dict' : { t -> strlen(&l:dictionary) > 0 },
                      \ 'digr' : { t -> get(g:, 'loaded_unicodePlugin', 0) },
                      \ 'file' : { t -> t =~# '\v[/~]\f*$' },
                      \ 'omni' : { t -> strlen(&l:omnifunc) > 0 },
                      \ 'spel' : { t -> &l:spell && !empty(&l:spelllang) },
                      \ 'tags' : { t -> !empty(tagfiles()) },
                      \ 'ulti' : { t -> get(g:, 'did_plugin_ultisnips', 0) },
                      \ 'unic' : { t -> get(g:, 'loaded_unicodePlugin', 0) },
                      \ 'user' : { t -> strlen(&l:completefunc) > 0 },
                      \ }

"}}}
" s:act_on_textchanged "{{{

" Purpose: "{{{
"
" Try an autocompletion every time the text changes in insert mode.
"
" This function is only called when autocompletion is enabled.
" Technically, it tries an autocompletion by typing `<plug>(MUcompleteAuto)`
" which calls `mucomplete#complete(1)`.
"
" It's not called when the popup menu is visible. Indeed, when we navigate in
" the menu and it inserts different entries, `TextChangedI` is not triggered.
"
" However, if an autocompletion is successful, i.e. finds a method which gives
" suggestions, and we hit Enter on a candidate in the menu, the text will change,
" and this function will be called.
" But we don't want autocompletion to be invoked again right after a successful
" autocompletion. Most of the time, it wouldn't make sense, and would probably
" be annoying. We could even get stuck in an infinite loop of autocompletions.
"
" So we need a flag to know when a completion is done, and call
" `mucomplete#complete(1)` only when it's off.
" This flag is `s:completedone`.
"
" "}}}

fu! s:act_on_textchanged() abort

    " s:completedone "{{{
    "
    " s:completedone is a flag, which is on only when 2 conditions are met:
    "
    "     - autocompletion is enabled
    "     - some text has been completed (`CompleteDone` event)
    "
    " It's almost always off, because as soon as it's enabled,
    " the `TextChangedI` event is triggered, and `s:act_on_textchanged()` is
    " called. The latter checks the value of `s:completedone` and resets it when
    " it's on.
"}}}

    if s:completedone

    " If the text changed AND a completion was done, we reset: "{{{
    "
    "     - s:completedone
    "
    "     When this flag is on, the function doesn't invoke an autocompletion.
    "     So it needs to be off for the next time the function will be called.
    "
    "     - g:mc_with_key
    "
    "     When this variable /flag is on, it means the completion was initiated
    "     manually.
    "     We can use this info to disable a method when autocompletion is
    "     enabled, but still be able to use it manually.
    "
    "     For example, we could disable the 'thes' method:
    "
    "         let g:mc_conditions.thes =  { t -> g:mc_with_key && strlen(&l:thesaurus) > 0 }
    "
    "     Now, the `thes` method can only be tried when 'thesaurus' has
    "     a value, AND the completion was initiated manually by the user.
    "
    "     "}}}

        let s:completedone = 0
        let g:mc_with_key  = 0

        " Usually, when a completion has been done, we don't want
        " autocompletion to be invoked again right afterwards.
        "
        " Exception:    'file' method
        "
        " If we just autocompleted a filepath component (i.e. the current method
        " is 'file'), we want autocompletion to be invoked again, to handle the
        " next component, in case there's one.
        " We just make sure that the character before the cursor is in 'isf'.

           if s:methods[s:i] ==# 'file' && matchstr(getline('.'), '.\%'.col('.').'c') =~# '\v\f'
               sil call mucomplete#file#complete()
           endif

    " Purpose of g:mc_trigger_auto_pattern: "{{{
    "
    " strpart(…) matches the characters from the beginning of the line up to
    " the cursor.
    "
    " We compare them to `{g:|b:}mc_trigger_auto_pattern`, which is a pattern
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
    " \a\a\a is longer than \a\a, and \a\a is more precise than \k
    " So in increasing order of autocompletion frequency:
    "
    "     \a\a\a  <  \a\a  <  \k
"}}}

    " FIXME:
    " Why does lifepillar write:
    "
    "     match(strpart(…), g:…) > -1
    "
    " instead of simply:
    "
    "     strpart(…) =~ g:…

    elseif strpart(getline('.'), 0, col('.') - 1) =~#
                \  { exists('b:mc_trigger_auto_pattern') ? 'b:' : 'g:' }mc_trigger_auto_pattern

        sil call feedkeys("\<plug>(MUcompleteAuto)", 'i')
    endif
endfu

"}}}
" enable_auto "{{{

fu! mucomplete#enable_auto() abort
    let s:completedone = 0
    let g:mc_with_key  = 0

    augroup MUcompleteAuto
        autocmd!
        " FIXME:
        " By default autocmds do not nest, unless you use the `nested` argument.
        " So, are the `noautocmd` commands really necessary?
        " Or is it just a precaution?
        autocmd TextChangedI * noautocmd call s:act_on_textchanged()
        autocmd CompleteDone * noautocmd let s:completedone = 1
    augroup END
    let s:auto = 1
endfu

"}}}
" disable_auto "{{{

fu! mucomplete#disable_auto() abort
    if exists('#MUcompleteAuto')
        autocmd! MUcompleteAuto
        augroup! MUcompleteAuto
    endif
    let s:auto = 0
endfu

"}}}
" toggle_auto "{{{

fu! mucomplete#toggle_auto() abort
    if exists('#MUcompleteAuto')
        call mucomplete#disable_auto()
        echom '[MUcomplete] Auto off'
    else
        call mucomplete#enable_auto()
        echom '[MUcomplete] Auto on'
    endif
endfu

"}}}
" s:act_on_pumvisible "{{{
"
" Purpose:
" insert the first entry in the menu

fu! s:act_on_pumvisible() abort
    let s:pumvisible = 0

    " If autocompletion is enabled don't do anything (respect the value of 'cot'). "{{{
    "
    " Why?
    " Automatically inserting text without the user having asked for a completion
    " (hitting Tab) is a bad idea.
    " It will regularly insert undesired text, and the user will constantly have
    " to undo it.
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
    "        If the method is 'c-p' or 'keyp', `Up` will make us select the
    "        second but last entry, then `C-n` will select and insert the last
    "        entry.
    "        For all the other methods, `Up` will make us leave the menu,
    "        then `C-n` will select and insert the first entry.
    "
    "        Basically, `Up` and `C-n` cancel each other out no matter the method.
    "        But `C-n` asks for an insertion. The result is that we insert the
    "        currently selected entry.
    "
"}}}

    return s:auto || s:methods[s:i] ==# 'spel'
                \ ? ''
                \ : (stridx(&l:completeopt, 'noselect') == -1
                \     ? (stridx(&l:completeopt, 'noinsert') == - 1 ? '' : "\<c-p>\<c-n>")
                \     : get(s:select_entry, s:methods[s:i], "\<c-n>\<up>")
                \   )

endfu

"}}}
" s:can_complete "{{{
"
" Purpose:
"
" During `s:next_method()`, find a method which can be applied.

fu! s:can_complete() abort
    return get({ exists('b:mc_conditions') ? 'b:' : 'g:' }mc_conditions,
                \ s:methods[s:i], s:yes_you_can)(s:word)
endfu

"}}}
" menu_is_up "{{{
"
" Purpose:
"
" just store 1 in `s:pumvisible`, at the very end of `s:next_method()`,
" when a method has been invoked, and it succeeded to find completions displayed
" in a menu.
"
" `s:pumvisible` is used as a flag to know whether the menu is open.
" This flag allows `mucomplete#verify_completion()` to choose between acting
" on the menu if there's one, or trying another method.

fu! mucomplete#menu_is_up() abort
    let s:pumvisible = 1
    return ''
endfu

"}}}
" complete "{{{

" Precondition: pumvisible() is false.
fu! mucomplete#complete(dir) abort
    let s:word = matchstr(strpart(getline('.'), 0, col('.') - 1), '\S\+$')

    if empty(s:word)
        return (a:dir > 0 ? "\<plug>(MUcompleteTab)" : "\<plug>(MUcompleteCtd)")
    endif

    let s:dir       = a:dir
    let s:cycling   = 0
    let s:i_history = []

    let s:methods = get(b:, 'mc_chain', g:mc_chain)
    let s:N       = len(s:methods)

    let s:i = s:dir > 0 ? -1 : s:N

    return s:next_method()
endfu

"}}}
" cycle "{{{

fu! mucomplete#cycle(dir) abort
    let s:dir       = a:dir
    let s:cycling   = 1
    let s:i_history = []

    " Why do we test the existence of `s:N`?
    " Because we could be stupid and ask to cycle in the chain, never having
    " entered the chain. That is, never having used a completion method in the
    " chain. Never hit Tab before.
    " When it happens, `s:next_method()` raises an error because `s:N` doesn't
    " exist. Indeed `s:N` is created by `mucomplete#complete()`, which is
    " called when we hit Tab and use a method in the chain.
    " We must call this function at least once for `s:N` to be created.
    "
    " We could also initialize `s:N` outside `mucomplete#complete()`, but
    " I don't think it makes a lot of sense to try and support such an edge
    " case. Asking for moving forward or backward inside the chain implies that
    " you have a position inside.
    " But if you were never in the chain, you don't have any position.

    return exists('s:N') ? "\<c-e>" . s:next_method() : ''
endfu

"}}}
" s:next_method "{{{

" Description "{{{
"
" s:next_method() is called by:
"
"     - mucomplete#verify_completion()    after a failed completion
"     - mucomplete#complete()             1st attempt to complete (auto / manual)
"     - mucomplete#cycle()                after a cycling

" Precondition: pumvisible() is false.
"
"         s:dir     = 1     flag:                            initial direction,                  never changes
"         s:i       = -1    number (positive or negative):   idx of the method to try,           CHANGES
"         s:cycling = 0     flag:                            did we ask to move in the chain ?,  never changes
"         s:N       = 7     number (positive):               number of methods in the chain,     never changes
"
" The valid values of `s:i` will vary between 0 and s:N-1.
" It is initialized by `cycle_or_select()`, which gives it the value:
"
"         -1      if we go forward in the chain
"         s:N     "        backward "
"
"}}}

fu! s:next_method() abort

    if s:cycling

        " Explanation of the formula: "{{{
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
        " There's still a problem though.
        "
        " Here is a general formula:
        "
        "     next_idx = (cur_idx + 1 + N) % N
        "
        " … where N is the length of the list we're indexing.
"
"}}}

        " FIXME: "{{{
        "
        " Why does lifepillar add `s:N`, like this:
        "
        "     let s:i = (s:i + s:dir + s:N) % s:N
        "
        " Maybe he's concerned with negative indexes, and the inconsistency of
        " the different implementations of the modulo operation over negative
        " numbers, depending on the compiler, environment, programming language…
        "
        "     http://stackoverflow.com/questions/4467539/javascript-modulo-not-behaving#comment4882815_4467559
        "     https://www.reddit.com/r/vim/comments/4lfc4v/psa_modulo_returns_negative_numbers/d3mwlds/
        "     http://stackoverflow.com/a/11720975
        "
        "     $ perl -E 'say -10 % 3'              →  2
        "     $ perl -Minteger -E 'say -10 % 3'    → -1
        "
        " But here `s:i` vary between `0` and `s:N - 1` (positive numbers).
        " So, what's the point?
        "
        " Besides, even if he was right to be concerned, the formula doesn't
        " seem to be enough robust.
        " This one seems to be more popular:
        " http://javascript.about.com/od/problemsolving/a/modulobug.htm
        "
        "     ((n%p)+p)%p
        "
        " … where `n` and `p` are resp. a negative and positive number.
        "
        " Adding `p` converts a possible negative result given by the modulo
        " operator into a positive number:
        "
        "     if     (-5 % 4)     = -1
        "     then   (-5 % 4) + 4 = 3
        "
        " But adding `p` would give us a too big result if `n` was a positive
        " number, instead of being negative:
        "
        "     (5 % 4) + 4 = 5
        "
        " So we need the second modulo to cover both cases with the same
        " formula:
        "
        "     ((5 % 4) + 4) % 4 = 1
"}}}

        let s:i = (s:i + s:dir) % s:N

        " We will get out of the loop as soon as: "{{{
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

        while (s:i+1) % (s:N+1) != 0  && !s:can_complete()
            let s:i = (s:i + s:dir + s:N) % s:N
        endwhile

    else

        let s:i += s:dir
        while (s:i+1) % (s:N+1) != 0  && !s:can_complete()
            let s:i += s:dir
        endwhile
    endif

    " After the while loop: "{{{
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
    "     && !count(s:i_history, s:i)
    "
    " … ? We want to make sure that the method to be tried hasn't already been
    " tried since the last time the user asked for a cycle.
    " Otherwise, we could be stuck in an endless loop of failing methods.
    " For example:
    "
    "       2 → 4 → 2 → 4 → …
    "
    ""}}}

    if (s:i+1) % (s:N+1) != 0 && !count(s:i_history, s:i)

        " If we're cycling, we store the index of the method to be tried, in
        " a list. We'll use it to compare its items with the index of the
        " next method to be tried.

        if s:cycling
            let s:i_history += [s:i]
        endif

        " 1 - Type the keys to invoke the chosen method."{{{
        "
        " 2 - Store the state of the menu in `s:pumvisible` through
        "     `mucomplete#menu_is_up()`.
        "
        " 3 - call `mucomplete#verify_completion()` through `<plug>(MUcompleteNxt)`
        "
        ""}}}

        " FIXME:
        "
        " Why does lifepillar use C-r twice.
        " Usually it's used to insert the contents of a register literally.
        " To prevent the interpretation of special characters like backspace:
        "
        "     register contents         insertion
        "     xy^Hz                →    xz
        "
        " Here we insert the expression register, which will store an empty
        " string. There's nothing to interpret. So why 2 C-r? Why not just one.

        return s:compl_mappings[s:methods[s:i]] .
                    \ "\<c-r>\<c-r>=pumvisible()?mucomplete#menu_is_up():''\<cr>\<plug>(MUcompleteNxt)"

    endif

    return ''
endfu

"}}}
" verify_completion "{{{
"
" Purpose:
"
" It's invoked by `<plug>(MUcompleteNxt)`, which itself is typed at
" the very end of `s:next_method()`.
" It checks whether the last completion succeeded by looking at
" the state of the menu.
" If it's open, the function calls `s:act_on_pumvisible()`.
" If it's not, it recalls `s:next_method()` to try another method.

fu! mucomplete#verify_completion() abort
    return s:pumvisible ? s:act_on_pumvisible() : s:next_method()
endfu

"}}}
" tab_complete "{{{

fu! mucomplete#tab_complete(dir) abort
    if pumvisible()
        return mucomplete#cycle_or_select(a:dir)
    else
        let g:mc_with_key = 1
        return mucomplete#complete(a:dir)
    endif
endfu

"}}}
" cycle_or_select "{{{

fu! mucomplete#cycle_or_select(dir) abort
    if get(g:, 'mc_cycle_with_trigger', 0)
        return mucomplete#cycle(a:dir)
    else
        return (a:dir > 0 ? "\<c-n>" : "\<c-p>")
    endif
endfu

"}}}
