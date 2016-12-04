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
" variable, `s:next_method()` hit `<plug>(MC_next_method)`, which calls
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
" FIXME: "{{{
"
" When the current method is 'dict', `C-k` selects the next entry in the menu
" instead of cycling backward in the chain like it should.
" Lifepillar has a similar problem.
" He uses `C-h` and `C-l` to cyle in the chain, instead of `C-k` and `C-j`.
" When the current method is 'line', `C-l` selects the previous entry in the
" menu instead of cycling forward in the chain like it should.
"
" I don't know if something can be done. Because even if we remap C-k to
" something else, Vim still doesn't take our mapping into account.
"
"     ino <c-k> pumvisible() ? '<c-p>' : '<c-p>'    ✘
"     ino <c-k> <nop>                               ✘
"
" Even with the 2 previous mappings, C-k still selects the next (!= previous)
" entry in the menu, after we've hit `C-x C-k`.
"
" We could try to find other mappings, but it would be difficult to find ones
" that make sense, and which aren't overridden by Vim, like when we hit C-k
" after C-x C-k, or C-l after C-x C-l.
"
"}}}
" FIXME: "{{{
"
" Lifepillar gave the value 1 to `s:completedone`.
" I think `!empty(v:completed_item)` would be better, because it would allow
" to have an autocompletion even when the previous one failed.
" For most methods, such a thing is useless, but not for all ('digr' is
" a counter-example).
"
" For more info, see the comment where we set `s:completedone` inside
" `mucomplete#enable_auto()`.
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
"
""}}}
" FIXME: "{{{
"
" Inside `s:act_on_textchanged()`,
"
" We write several times `s:methods[s:i]` in this file.
" Lifepillar uses `get()` only 2 times to get this value.
" Once in `s:act_on_textchanged()`, and once in `s:act_on_pumvisible()`.
" Only for the 1st occurrence.
"
" The reason why he does it inside `s:act_on_textchanged()` is to prevent
" a bug which may occur, when autocompletion is enabled and all the methods in
" the chain fail.
" I describe the bug at the end of `s:next_method()`, where I wrote a better
" fix:
"
"     if s:i ==# s:N
"         let s:i = 0
"     endif
"
" Submit a PR for this fix.
"
" But should we also use `get()` for the 1st occurrence of `s:methods[s:i]`
" in `s:act_on_pumvisible()`? Why does Lifepillar use it there too? Ask him
" inside the PR.
"
"}}}
" FIXME: "{{{
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
"
"}}}
"FIXME: "{{{
"
" Lifepillar initialized `s:auto` to 0 inside the plugin.
" It causes an issue if autocompletion is enabled and we manually source the
" script. It should be:
"
"     let s:auto = get(s:, 'auto', 0)
"
""}}}

" To look for all the global variables used by this plugin, search the
" pattern:
"         \v^(\s*".*)@!.*\zsg:[^ ,]

" Variables "{{{

" Internal state
let s:methods      = []
let s:word         = ''

" flag: in which direction will we move in the chain
let s:dir   = 1

" flag: did we ask to move in the chain ?
let s:cycle = 0

" Indexes of the methods which have been tried since the last time we asked
" for a cycling.
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

" Purpose of `s:auto`: "{{{
"
" `s:auto` is a flag which, when it's set, means that autocompletion is enabled.
" Its used by `s:act_on_pumvisible()` to know whether it must insert the first
" entry in the menu. Indeed, when autocompletion is enabled, we don't want to
" automatically insert anything. Bad idea.
" It would constantly insert undesired text, and the user would have to undo
" it. The popup menu with suggestions is enough.
"
"}}}
" Why do we use `get()` ? "{{{
"
" Consider this:
" autocompletion is enabled, and we source manually the plugin, it will
" wrongly, set `s:auto` to 0. The consequence will be that now autocompletions
" will automatically insert text.
"
"}}}

let s:auto    = get(s:, 'auto', 0)



let s:exit_ctrl_x    = "\<c-g>\<c-g>"

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
let s:compl_mappings = {
                       \ 'abbr' : "\<c-r>=mucomplete#abbr#complete()\<cr>",
                       \ 'c-n'  : s:exit_ctrl_x."\<c-n>",
                       \ 'c-p'  : s:exit_ctrl_x."\<c-p>",
                       \ 'cmd'  : s:exit_ctrl_x."\<c-x>\<c-v>",
                       \ 'defs' : s:exit_ctrl_x."\<c-x>\<c-d>",
                       \ 'dict' : s:exit_ctrl_x."\<c-x>\<c-k>",
                       \ 'digr' : s:exit_ctrl_x."\<c-x>\<c-g>",
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
                       \ 'unic' : s:exit_ctrl_x."\<c-x>\<c-z>",
                       \ 'user' : s:exit_ctrl_x."\<c-x>\<c-u>",
                       \ }
unlet s:exit_ctrl_x

let s:select_entry = { 'c-p' : "\<c-p>\<down>", 'keyp': "\<c-p>\<down>" }

" Default pattern to decide when automatic completion should be triggered.
let g:mc_auto_pattern = '\k\k$'

" Default completion chain

let g:mc_chain = [
                 \ 'abbr',
                 \ 'c-p' ,
                 \ 'cmd' ,
                 \ 'dict',
                 \ 'digr',
                 \ 'file',
                 \ 'keyp',
                 \ 'line',
                 \ 'omni',
                 \ 'spel',
                 \ 'tags',
                 \ 'ulti',
                 \ 'unic',
                 \ ]

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
                      \ 'dict' : { t -> s:setup_dict_option() },
                      \ 'digr' : { t -> get(g:, 'loaded_unicodePlugin', 0) },
                      \ 'file' : { t -> t =~# '\v[/~]\f*$' },
                      \ 'omni' : { t -> !empty(&l:omnifunc) },
                      \ 'spel' : { t -> &l:spell && !empty(&l:spelllang) },
                      \ 'tags' : { t -> !empty(tagfiles()) },
                      \ 'ulti' : { t -> get(g:, 'did_plugin_ultisnips', 0) },
                      \ 'unic' : { t -> get(g:, 'loaded_unicodePlugin', 0) },
                      \ 'user' : { t -> !empty(&l:completefunc) },
                      \ }

"}}}
" act_on_pumvisible "{{{

" Purpose: "{{{
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

    " If autocompletion is enabled don't do anything (respect the value of 'cot'). "{{{
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

    return s:auto || s:methods[s:i] ==# 'spel'
                \ ? ''
                \ : (stridx(&l:completeopt, 'noselect') == -1
                \     ? (stridx(&l:completeopt, 'noinsert') == - 1 ? '' : "\<c-p>\<c-n>")
                \     : get(s:select_entry, s:methods[s:i], "\<c-n>\<up>")
                \   )

endfu

"}}}
" act_on_textchanged "{{{

" Purpose: "{{{
"
" Try an autocompletion every time the text changes in insert mode.
"
" This function is only called when autocompletion is enabled.
" Technically, it tries an autocompletion by typing `<plug>(MC_Auto)`
" which calls `mucomplete#complete(1)`. Similar to hitting Tab.
"
" "}}}

fu! s:act_on_textchanged() abort

    " s:completedone "{{{
    "
    " s:completedone is a flag, which is only on when 2 conditions are met:
    "
    "     - autocompletion is enabled
    "     - some text has been completed
    "      `CompleteDone` event + `!empty(v:completed_item)`
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

    " If the text changed AND a completion was done, we reset: "{{{
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
    "     Inside mucomplete#tab_complete(), it's set to 1.
    "     Inside mucomplete#enable_auto(), it's set to 0.
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
        let g:mc_manual    = 0

        " Why do we call mucomplete#file#complete()? "{{{
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

           if s:methods[s:i] ==# 'file' && matchstr(getline('.'), '.\%'.col('.').'c') =~# '\v\f'
               sil call mucomplete#file#complete()
           endif

    " Purpose of g:mc_auto_pattern: "{{{
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

"}}}
" can_complete "{{{
"
" Purpose:
"
" During `s:next_method()`, test whether the current method can be applied.
" If it's not, `s:next_method()` will try the next one.

fu! s:can_complete() abort
    return get({ exists('b:mc_conditions') ? 'b:' : 'g:' }mc_conditions,
                \ s:methods[s:i], s:yes_you_can)(s:word)
endfu

"}}}
" complete "{{{

fu! mucomplete#complete(dir) abort
    let s:word    = matchstr(getline('.')[:col('.')-2], '\S\+$')
    if empty(s:word)
        return (a:dir > 0 ? "\<plug>(MC_Tab)" : "\<plug>(MC_C-d)")
    endif

    let s:cycle = 0
    let s:dir   = a:dir

    let s:i_history = []
    let s:i         = s:dir > 0 ? -1 : s:N

    let s:methods = get(b:, 'mc_chain', g:mc_chain)
    let s:N       = len(s:methods)

    return s:next_method()
endfu

"}}}
" cycle "{{{

fu! mucomplete#cycle(dir) abort
    let s:cycle     = 1
    let s:dir       = a:dir
    let s:i_history = []

    " Why do we test the existence of `s:N`? "{{{
    "
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
    "
"}}}

    return exists('s:N') ? "\<c-e>" . s:next_method() : ''
endfu

"}}}
" cycle_or_select "{{{

" Purpose:
" When we hit Tab or S-Tab, decide whether we want to cycle in the chain, or
" select another entry in the menu.
" If we don't use Tab / S-Tab to cycle in the chain, we could probably get rid
" of this function, and merge its contents with `tab_complete()`.

fu! mucomplete#cycle_or_select(dir) abort
    if get(g:, 'mc_cycle_with_trigger', 0)
        return mucomplete#cycle(a:dir)
    else
        return (a:dir > 0 ? "\<c-n>" : "\<c-p>")
    endif
endfu

"}}}
" disable_auto "{{{

fu! mucomplete#disable_auto() abort
    if exists('#MC_Auto')
        autocmd! MC_Auto
        augroup! MC_Auto
    endif
    let s:auto = 0
endfu

"}}}
" enable_auto "{{{

fu! mucomplete#enable_auto() abort
    let s:completedone = 0
    let g:mc_manual    = 0

    augroup MC_Auto
        autocmd!

        " FIXME:
        "
        " By default autocmds do not nest, unless you use the `nested` argument.
        " So, are the `noautocmd` commands really necessary?
        " Or is it just a precaution?

        " When are `CompleteDone` and `TextChangedI` triggered? "{{{
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
        "         C-x C-G    → does NOT trigger TextChangedI
        "         C-x C-S
        "         C-x C-V
        "         C-x C-Z
        "
        "         C-x C-D    → triggers TextChangedI
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
        " However, in our custom completion code, the event is NEVER triggered when the
        " completion fails. Why?
        " Because at the end of `s:next_method()`, the keys which are returned look
        " something like this:
        "
        "     C-x C-n … Plug(MC_next_method)
        "
        " If there wasn't `Plug(…)`, `TextChangedI` would always be triggered,
        " regardless of wheter a method succeeds.
        " But because of it, `TextChangedI` is not triggered when all the methods fail.
        "
        " Why? I don't know. Ask stackexchange or Lifepillar.
        " How do you know `Plug(…)` is the cause of this?
        " Write this inside vimrc:
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
        "
        " Another way to watch when both `TextChangedI` and `CompleteDone` occur:
        "
        "     let g:debug = { 'cd' : 0, 'tci' : 0, }
        "     augroup TEST
        "         au!
        "         au TextChangedI * let g:debug.tci += 1
        "         au CompleteDone * let g:debug.cd += 1
        "     augroup END
        ""}}}

        autocmd TextChangedI * noautocmd call s:act_on_textchanged()

        " Why do we define `s:completedone` as `!empty(v:completed_item)`? "{{{
        "
        " We want to use it to prevent an autocompletion to be performed right
        " after a successful one (in this case defining it as `1` would be enough),
        " BUT we do want to allow an autocompletion after a failed one (`1`
        " isn't enough anymore).
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

        autocmd CompleteDone * noautocmd let s:completedone = !empty(v:completed_item)
    augroup END
    let s:auto = 1
endfu

"}}}
" menu_is_up "{{{

" Purpose: "{{{
"
" just store 1 in `s:pumvisible`, at the very end of `s:next_method()`,
" when a method has been invoked, and it succeeded to find completions displayed
" in a menu.
"
" `s:pumvisible` is used as a flag to know whether the menu is open.
" This flag allows `mucomplete#verify_completion()` to choose between acting
" on the menu if there's one, or trying another method.
"
" It's reset to 0 at the beginning of `s:act_on_pumvisible()`.
"
"}}}

fu! mucomplete#menu_is_up() abort
    let s:pumvisible = 1
    return ''
endfu

"}}}
" next_method "{{{

" Description "{{{
"
" s:next_method() is called by:
"
"     - mucomplete#verify_completion()    after a failed completion
"     - mucomplete#complete()             1st attempt to complete (auto / manual)
"     - mucomplete#cycle()                when we cycle
"
"}}}
" Purpose: "{{{
"
" The function is going to [in|de]crement the index of the next method to try.
" It does it one time.
" Then it checks whether this next method can be applied.
" If it's not, it [in|de]crement it repeatedly until:
"
"     - it finds one if we're manually cycling (`s:cycle` is set)
"     - it finds one OR we reach the beginning/end of the chain if we're not cycling
"
"}}}

fu! s:next_method() abort
    if s:cycle

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
        " Here is a general formula:
        "
        "     next_idx = (cur_idx + 1) % N
        "
        " … where N is the length of the list we're indexing.
"
"}}}

        " Why do we add `s:N` ? "{{{
        "
        " At the end of this function, before hitting the completion mappings,
        " we will make sure that `s:i` is different than `-1` and `s:N`.
        "
        " Because, if we're not cycling, and the value of `s:i` is `-1` or
        " `s:N`, it means we've tested all the methods in the chain. It's
        " pointless to go on. We could even get stuck in a loop if no methods
        " can be applied. Besides, `s:methods[s:N]` does not even exist.
        "
        " So, this check is necessary. But it cause an issue.
        " If we've hit `C-k` to go back in the chain (`s:cycle` is set), and we
        " reach the beginning of the chain (s:i = 0), we won't be able to get
        " back any further. We won't be able to go back to the end of the
        " chain, because the function won't even try the last / -1 method.
        "
        " To allow `C-k` to go back to the end of the chain, in the definition
        " of `s:i`, we add `s:N`.
        " When `s:i` is different than -1, it won't make any difference,
        " because of the `% s:N` operation.
        " But when the value of `s:i` is -1, adding `s:N` will convert the
        " negative index into a positive one, which matches the same method in
        " the chain. The last one.
        "
        " "}}}

        let s:i = (s:i + s:dir + s:N) % s:N

        " Why is there no risk to be stuck in a loop? "{{{
        "
        " We could be afraid to be stuck in a loop, and to prevent that, add the
        " condition that `s:i` is different than `-1` and `s:N`.
        "
        " But it's unnecessary. We can't be stuck in a loop.
        " Indeed, if we ask for a cycling, it means that the popup menu is
        " currently visible and that a method was successful.
        " So, when we ask for a cycling, we can be sure that there's AT LEAST
        " one method which can be applied, i.e. a method for which
        " `s:can_complete()` returns true/1.
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

        let s:i += s:dir

        " Why the first 2 conditions? "{{{
        "
        " In the previous case (`if s:cycle`), the only condition to stay in
        " the loop was:
        "
        "     !s:can_complete()
        "
        " This time, we have to add:
        "
        "     s:i != -1 && s:i != s:N
        "
        " Indeed, we're not cycling. We've just hit Tab/S-Tab.
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
    " tried since the last time the user asked for a cycling.
    " Otherwise, we could be stuck in an endless loop of failing methods.
    " For example:
    "
    "       2 → 4 → 2 → 4 → …
    "
    ""}}}

    " FIXME: "{{{
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

    " Why the 2 first conditions? "{{{
    "
    " If we're cycling, `s:i` can't be `-1` nor `s:N`.
    " However, if we're NOT cycling (Tab, S-Tab), then if all the methods
    " failed, we could reach the beginning/end of the chain and then `s:i`
    " could be `-1` or `s:N`.
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

    if s:i != -1 && s:i != s:N && !count(s:i_history, s:i)

        " If we're cycling, we store the index of the method to be tried, in
        " a list. We use it to compare its items with the index of the next
        " method to be tried.

        if s:cycle
            let s:i_history += [s:i]
        endif

        " 1 - Type the keys to invoke the chosen method. "{{{
        "
        " 2 - Store the state of the menu in `s:pumvisible` through
        "     `mucomplete#menu_is_up()`.
        "
        " 3 - call `mucomplete#verify_completion()` through `<plug>(MC_next_method)`
        "
        ""}}}

        " FIXME: "{{{
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
        "
        " "}}}

        return s:compl_mappings[s:methods[s:i]] .
                    \ "\<c-r>\<c-r>=pumvisible()?mucomplete#menu_is_up():''\<cr>\<plug>(MC_next_method)"

    endif

    " Why do we reset `s:i` here? "{{{
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
    " A solution is to use get() like lifepillar did, but I don't like it,
    " because it only treats the consequences of some underlying issue.
    "
    " I prefer treating the issue itself. Because who knows, maybe it could
    " cause other unknown issues in the future.
    "
    " To tackle the root issue, we reset `s:i` to 0, here, when no completion
    " mapping was hit and when `s:i = s:N`.
    "
    " We don't really need this reset anymore, because we've redefined
    " `s:completedone`. Still, I keep it, because better be safe than sorry.
"}}}

    if s:i ==# s:N
        let s:i = 0
    endif

    return ''
endfu

"}}}
" setup_dict_option "{{{

fu! s:setup_dict_option() abort
    if count([ 'en', 'fr' ], &l:spelllang)
        let &l:dictionary = &l:spelllang ==# 'en' ? '/usr/share/dict/words' : '/usr/share/dict/french'
        return 1
    else
        return 0
    endif
endfu

"}}}
" tab_complete "{{{

" We can't get rid of this function, and put its code inside `complete()`.
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

fu! mucomplete#tab_complete(dir) abort
    if pumvisible()
        return mucomplete#cycle_or_select(a:dir)
    else
        let g:mc_manual = 1
        return mucomplete#complete(a:dir)
    endif
endfu

"}}}
" toggle_auto "{{{

fu! mucomplete#toggle_auto() abort
    if exists('#MC_Auto')
        call mucomplete#disable_auto()
        echom '[MC] Auto off'
    else
        call mucomplete#enable_auto()
        echom '[MC] Auto on'
    endif
endfu

"}}}
" verify_completion "{{{

" Purpose: "{{{
"
" It's invoked by `<plug>(MC_next_method)`, which itself is typed at
" the very end of `s:next_method()`.
" It checks whether the last completion succeeded by looking at
" the state of the menu.
" If it's open, the function calls `s:act_on_pumvisible()`.
" If it's not, it recalls `s:next_method()` to try another method.
"
"}}}

fu! mucomplete#verify_completion() abort
    return s:pumvisible ? s:act_on_pumvisible() : s:next_method()
endfu

"}}}
