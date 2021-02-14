vim9script noclear

if exists('loaded') | finish | endif
var loaded = true

# FIXME: {{{1
#
# I  keep  this section,  but  it's  not a  good  idea  because it  could  cause
# autocompletion to press Tab indefinitely.
# See `completion#enableAuto()` for more info.
#
# Lifepillar gave the value 1 to `completedone`.
# I think `!empty(v:completed_item)` would be better, because it would allow
# to have an autocompletion even when the previous one failed.
# For most methods, such a thing is useless, but not for all ('digr' is
# a counter-example).
#
# For  more   info,  see  the   comment  where  we  set   `completedone`  inside
# `completion#enableAuto()`.
#
# Incidentally, this new definition also fixes  a bug which occurs when `i` ends
# with the value `N`, and `completedone`'s value is 1.
# Setting  `completedone`  to  `!empty(v:completed_item)` means  that  when  all
# the  methods   fail  during  an   autocompletion  and  nothing   is  inserted,
# `completedone`'s   value  is   still   0,  even   though  `CompleteDone`   was
# triggered  several  times.  And  the  next  time  we  insert a  character  and
# `ActOnTextchanged()` is called, it won't execute the first block of code which
# tries to get `methods[i]` (`i = N`).
#
# We don't really  need this new definition  to fix this bug, because  we have a
# more reliable way to do it, at the end of `NextMethod()`.
#
#     if i == N
#         i = 0
#     endif
#
# But still, one could argue that it's another reason in favor of the new definition.

# FIXME: {{{1
#
# Inside `ActOnTextchanged()`, why does lifepillar write:
#
#     strpart(...)->match(g:...) > -1
#
# instead of simply:
#
#     strpart(...) =~ g:...
#
# ---
#
# To look for all the global variables used by this plugin, search the
# pattern:
#
#     ^\%(\s*".*\)\@!.*\zsg:[^ ,]
#}}}1

# Init {{{1

# Warnings:
# Do *not* add the 'line' method. {{{
#
# It works, but it's annoying to get a whole line when all you want is a word.
#
# When that happens, you have to either press `C-q` to cancel the completion, or
# `C-j` to invoke the next method.
#
# But even  after pressing `C-j`, finding  the right method, and  completing the
# desired word, sometimes  if you press `Tab` again (because  you're expanding a
# snippet and  you want  to jump to  the next tabstop),  you may  re-invoke this
# fucking 'line' method.
#
# Bottom line:
# Line completion  is too cumbersome  to be automated.   Use `C-x C-l`  when you
# know you *really* need it.
#}}}
# Do *not* use `keyp` nor `c-p`.{{{
#
# `:h 'cot /ctrl-l` doesn't work with `C-x C-p` and `C-p`:
#
#     $ vim -Nu NONE +'set cot=menu,longest|startinsert!' =(cat <<'EOF'
#         xx
#         xxabc
#         xxab
#         xxa
#     EOF
#     )
#
# If you press `C-x C-p`: `xxa` is completed.
# If you then press `C-l`: no character is inserted.
#
# Had you pressed `C-x C-n` instead of `C-x C-p`, `C-l` would have inserted `b`.
#}}}
const MC_CHAIN: list<string> =<< trim END
    file
    keyn
    ulti
    abbr
    c-n
    dict
END

var methods: list<string> = get(b:, 'mc_chain', MC_CHAIN)
var N: number = len(methods)
var word: string

var manual: bool = true
var completedone: bool = true

# flag: in which direction will we move in the chain
var dir: number = 1

# flag: did we ask to move in the chain ?
var cycling: bool = false

# Indexes of the  methods which have been  tried since the last  time we've been
# cycling.
var i_history: list<number> = []

# number (positive or negative):   idx of the current method to try
var i: number = 0
# The valid values of `i` will vary between 0 and `N - 1`.
# It is initialized by `complete()`, which gives it the value:
#
#    ┌────┬─────────────────────────────────┐
#    │ -1 │ if we move forward in the chain │
#    ├────┼─────────────────────────────────┤
#    │ N  │ "          backward "           │
#    └────┴─────────────────────────────────┘
#
# It's updated by `NextMethod()`.

# flag:   state of the popup menu
var pumvisible: bool
# Its value is tested in `verify_completion()`, which is being called at the end
# of `NextMethod()`.

# Purpose: {{{
#
# `auto` is a flag which, when it's set, means that autocompletion is enabled.
# Its used by  `ActOnPumvisible()` to know whether it must  insert the first
# entry in the  menu.  Indeed, when autocompletion is enabled,  we don't want to
# automatically insert anything.  Bad idea.
# It would constantly insert undesired text, and the user would have to undo it.
# The popup menu with matches is enough.
#}}}
var auto: bool

# We could also use "\<c-x>\<c-z>\<bs> {{{
# In this case update the warning.
#
# Currently we have a mapping using C-x C-z, installed by the unicode plugin.
# We would have to unmap it in this script:
#
#     iunmap <C-x><C-z>
#
# We can't unmap  it in the vimrc,  because it would be too  soon.  The mappings
# for a plugin are defined after the vimrc is sourced.
#}}}
const EXIT_CTRL_X: string = "\<c-g>\<c-g>"

if !mapcheck('<c-g><c-g>', 'i')->empty()
    var msg: list<string> =<< trim END
        Warning: you have a mapping whose {lhs} is or begins with C-g C-g.
        See the output of `execute('verb imap <c-g><c-g>')`.

        MC (My Completion) presses those keys before pressing the keys of some methods.
        It does this to make sure you are out of C-x submode before trying them.

        Your current mapping could lead to some unexpected behavior.
        Please remove/change it.
    END
    echohl WarningMsg
    echo join(msg, "\n")
    echohl None
endif

# Why do we need to prepend `EXIT_CTRL_X` in front of "\<c-x>\<c-l>"? {{{
#
# Suppose we have the following buffer:
#
#     hello world
#
# On another line, we write:
#
#     hello C-x C-l
#
# The line completion suggests us `hello world`, but we refuse and go on typing:
#
#     hello people
#
# If we press `C-x C-l` again, the line completion will insert a newline.
# Why?
# It's probably one of Vim's quirks / bugs.
# It shouldn't insert anything, because now the line is unique.
#
# According to lifepillar, this can cause a problem when autocompletion
# is enabled.
# I can see how.  The user set up line completion in his completion chain.
# Line completion  is invoked automatically  but he refuses the  suggestion, and
# goes on typing.  Later, line completion is invoked a second time.
# This time, there will be no suggestion, because the current line is likely
# unique (the user typed something that was nowhere else), but line completion
# will still insert a newline.
#
# Here's what lifepillar commented on the patch that introduced it:
#
#    > Fix 'line' completion method inserting a new line.
#    >
#    > Line completion seems to work differently from other completion methods:
#    > typing a character that does not belong to an entry does not exit
#    > completion. Before this commit, with autocompletion on such behaviour
#    > resulted in µcomplete inserting a new line while the user was typing,
#    > because µcomplete would insert <c-x><c-l> while in ctrl-x submode.
#    >
#    > To fix that, we use the same trick as with 'c-p': make sure that we are
#    > out of ctrl-x submode before typing <c-x><c-l>.
#
# Source: commit `59169596e96c8ff3943e9179a626391ff76f4b76`
#
# There's  a case,  though,  where adding  a  newline can  make  sense for  line
# completion.  When  we're at the *end*  of a line existing  in multiple places,
# and we press  `C-x C-l`.  Invoking line completion twice  inserts a newline to
# suggest us the next line:
#
#     We have 2 identical lines:    L1 and L1'
#     After L1, there's L2.
#     The cursor is at the end of L1'.
#     The first `C-x C-l` invocation only suggests L1.
#     The second one inserts a newline and suggests L2.
#}}}
const COMPL_MAPPINGS: dict<string> = {
    abbr: "\<plug>(MC_c-r)=completion#abbr#complete()\<Plug>(MC_cr)",
    c-n: EXIT_CTRL_X .. "\<plug>(MC_c-n)",
    c-p: EXIT_CTRL_X .. "\<plug>(MC_c-p)",
    cmd: "\<plug>(MC_c-x_c-v)",
    defs: "\<plug>(MC_c-x_c-d)",
    dict: "\<plug>(MC_c-x_c-k)",
    digr: "\<plug>(DigraphComplete)",
    file: "\<plug>(MC_c-r)=completion#file#complete()\<Plug>(MC_cr)",
    incl: "\<plug>(MC_c-x_c-i)",
    keyn: "\<plug>(MC_c-x_c-n)",
    keyp: "\<plug>(MC_c-x_c-p)",
    line: EXIT_CTRL_X .. "\<plug>(MC_c-x_c-l)",
    omni: "\<plug>(MC_c-x_c-o)",
    spel: "\<plug>(MC_c-r)=completion#spel#suggest()\<plug>(MC_cr)",
    tags: "\<plug>(MC_c-x_c-])",
    thes: "\<plug>(MC_c-x_c-t)",
    ulti: "\<plug>(MC_c-r)=completion#ultisnips#complete()\<plug>(MC_cr)",
    unic: "\<plug>(UnicodeComplete)",
    user: "\<plug>(MC_c-x_c-u)",
    }

const SELECT_MATCH: dict<string> = {
    c-p: "\<plug>(MC_c-p)\<plug>(MC_down)",
    keyp: "\<plug>(MC_c-p)\<plug>(MC_down)",
    }

# Default pattern to decide when automatic completion should be triggered.
const MC_AUTO_PATTERN: string = '\k\k$'

# Conditions to be verified for a given method to be applied.{{{
#
# Explanation of the regex for the file completion method:
#
#     [/~]\f*$
#
# Before the cursor, there must a slash or a tilda, then zero or more characters
# in `'isfname'`.
# By default the tilda is in `'isf'`, so why not simply:
#
#     /\=\f*
#
# Because then, it would match anything.  The condition would be useless.
# At the very least, we want a slash or a tilda before the cursor.
# The filename characters afterwards are optional, because we could try to
# complete `some_dir/` or just `~`.
#}}}
const YES_YOU_CAN: func = (_) => true
const MC_CONDITIONS: dict<func> = {
    c-p: (_) => manual && completion#util#customIsk('-'),
    dict: (_) => manual && completion#util#setupDict(),
    digr: (_) => manual && get(g:, 'loaded_unicodePlugin', 0),
    file: (t) => t =~ '[/~]\f*$',
    omni: (_) => !empty(&l:omnifunc) && &ft != 'markdown',
    spel: (_) => &l:spell && !empty(&l:spelllang),
    tags: (_) => manual
                && !tagfiles()->empty()
                && completion#util#customIsk('-' .. (&ft == 'vim' ? ':<' : '')),
    ulti: (_) => get(g:, 'did_plugin_ultisnips', 0),
    unic: (_) => manual && get(g:, 'loaded_unicodePlugin', 0),
    user: (_) => !empty(&l:completefunc),
    }

# Interface {{{1
def completion#complete(arg_dir: number): string #{{{2
    #                                                         ┌ don't use `\k`, it would exclude `/`
    #                                                         │ and we need to include slash for file completion
    #                                                         │
    word = getline('.')->strpart(0, col('.') - 1)->matchstr('\S\+$')

    #                  ┌ if the cursor is right at the beginning of a line:
    #                  │
    #                  │    - col('.') - 2                              will be negative
    #                  │    - getline('.')->strpart(0, col('.') - 1)    will give us the whole line
    #                  │    - matchstr(...)                             will give us the last word on the line
    #                  │
    #                  ├───────────┐
    if word !~ '\k' || col('.') <= 1
        return (arg_dir > 0 ? "\<plug>(MC_tab)" : "\<plug>(MC_c-d)")
    endif

    cycling = false
    dir = arg_dir

    i_history = []
    i = dir > 0 ? -1 : N

    methods = get(b:, 'mc_chain', MC_CHAIN)
    N = len(methods)

    return NextMethod()
enddef
# Why don't you merge this function with `NextMethod()`? {{{
#
# Because, among other things, the latter would  reset `i` each time it would be
# called, so the index of the method to try would be stuck on the same value.
#
# We couldn't merge it into `tab_complete()` either, because we want to use
# the latter for when we press Tab manually, not for autocompletion.
# Eventually, pressing Tab will call `complete()`, and autocompletion also calls
# (directly) this function.  That's why  we simply call it `complete()`, because
# all kind of completions (manual/auto) use it.
#
# BUT, by making the 2 kind of completions call different functions / hook
# into the algo at different points, we can implement some logic, such as:
#
#    - if the completion is automatic, don't try this method because it's too expensive
#    - if the completion is manual,    try first to expand a snippet
# }}}

def completion#cycle(arg_dir: number): string #{{{2
    cycling = true
    manual = true
    dir = arg_dir
    i_history = []

    return "\<plug>(MC_c-e)" .. NextMethod()
enddef
# Why don't you merge this function with `cycle_or_select()`? {{{
#
# Because of the mappings c-j and c-o which cycle in the chain.  They don't want
# to call `cycle_or_select()`, their purpose is really to call `cycle()`.
#}}}

def completion#disableAuto() #{{{2
    if exists('#McAuto')
        autocmd! McAuto
        augroup! McAuto
    endif
    auto = false
    if cot_save != ''
        &cot = cot_save
        cot_save = ''
    endif
    echo '[auto completion] OFF'
enddef

def completion#enableAuto() #{{{2
    auto = true
    manual = false
    cot_save = &cot
    completedone = false

    # automatically   inserted   text   is  particularly   annoying   while   in
    # auto-completion mode
    set cot+=noinsert

    augroup McAuto | au!
        au TextChangedI * ActOnTextchanged()
        # Why don't you define `completedone` as `!empty(v:completed_item)`? {{{
        #
        # Because it could make autocompletion press Tab indefinitely.
        # Here's how to reproduce this bug:
        #
        #    1. const MC_CHAIN: list<string> = ['keyn', 'cmd']
        #
        #    2. open a buffer and write `test`
        #
        #    3. write `te`, the autocompletion kicks in and suggests `test`
        #       accept and insert
        #
        #    4. write `va` → autocompletion keeps trying to complete `va`
        #
        # FIXME:
        # It's a weird bug, because if we write `va` on a different line, it
        # doesn't occur.
        #
        # Anyway, why *was* it tempting to redefine `completedone` like this?
        #
        # We  want to  use `completedone`  to  prevent an  autocompletion to  be
        # performed right after a successful one.
        # In this case defining it as `1` would be enough.
        # *But* we wanted to allow an autocompletion after a failed one.
        # `1` isn't enough anymore.
        #
        # But if the last failed, does it make sense to try a new one?
        # It depends on which text a given method is trying to complete.
        # If a method tries to complete this:
        #
        #     getline('.')->strpart(0, col('.') - 1)->matchstr('\S\+$')
        #
        # ... then it doesn't make sense to try an autocompletion after a failed one.
        # Because inserting a new character will make the text to complete even harder.
        # So, if it failed last time, it will fail with this new character.
        # However, it can make sense with some methods, like 'digr', which tries to
        # complete only the last 2 characters.
        # In this case, inserting a new character doesn't make the text harder to
        # complete, it just makes it different.
        # It can be checked when we insert the text `xtxv`.
        # If we define `completedone` as `1`, no autocompletion is tried against
        # `xv` to suggest us `✔`.
        # OTOH, if we define it as `!empty(v:completed_item)`, we get an
        # autocompletion.
        #}}}
        au CompleteDone * completedone = true
    augroup END

    echo '[auto completion] ON'
enddef

def completion#menuIsUp(): string #{{{2
    pumvisible = true
    return ''
enddef
# Purpose:{{{
#
# just store 1 in `pumvisible`, at the very end of `NextMethod()`, when a method
# has been invoked, and it succeeded to find completions displayed in a menu.
#
# `pumvisible` is used as a flag to know whether the menu is open.
# This flag  lets `completion#verifyCompletion()`  choose between acting  on the
# menu if there's one, or trying another method.
#
# It's reset to 0 at the beginning of `ActOnPumvisible()`.
#}}}

def completion#snippetOrComplete(arg_dir: number) #{{{2
    if pumvisible()
        feedkeys(arg_dir > 0 ? "\<c-n>" : "\<c-p>", 'in')
        return
    endif

    # Why not checking the existence of `UltiSnips#ExpandSnippet()`?{{{
    #
    #     if !exists('*UltiSnips#ExpandSnippet')
    #
    # What we  really want, is  not checking  whether this function  exists, but
    # whether the UltiSnips plugin is enabled in our vimrc.
    #}}}
    if !exists('g:did_plugin_ultisnips')
        feedkeys(arg_dir > 0 ? "\<plug>(MC_tab_complete)" : "\<plug>(MC_stab_complete)", 'i')
        return
    endif

    # Note: you might also be interested in these functions:{{{
    #
    #    - UltiSnips#CanExpandSnippet()
    #    - UltiSnips#CanJumpForwards()
    #    - UltiSnips#CanJumpBackwards()
    #}}}
    UltiSnips#ExpandSnippet()

    if !g:ulti_expand_res
        if arg_dir > 0
            UltiSnips#JumpForwards()
            if !g:ulti_jump_forwards_res
                feedkeys("\<plug>(MC_tab_complete)", 'i')
            endif
        else
            UltiSnips#JumpBackwards()
            if !g:ulti_jump_backwards_res
                feedkeys("\<plug>(MC_stab_complete)", 'i')
            endif
        endif
    endif

    completedone = false
    manual = false
enddef

def completion#tabComplete(arg_dir: number): string #{{{2
    manual = true
    orig_line = getline('.')
    return completion#complete(arg_dir)
enddef
var orig_line: string
# Why don't you merge this function with `complete()`? {{{
#
# If we did that, every time `complete()` would be called, `manual` would be set
# to  1.   It  would  be  wrong,  when  `complete()`  would  be  called  by  the
# autocompletion (`<Plug>(MC_Auto)`).
#
# We could find a workaround, by passing a second argument to `complete()`
# inside the mappings `Tab`, `S-Tab`, and `<plug>(MC_auto)`.
# It would serve as a flag whose meaning is whether we're performing a manual
# or automatic completion.
# But, it means that every time the  autocompletion would kick in, it would test
# whether the popup menu is visible.  It could make it a bit slower...
#}}}

def completion#toggleAuto() #{{{2
    if exists('#McAuto')
        completion#disableAuto()
    else
        completion#enableAuto()
    endif
enddef

def completion#verifyCompletion(): string #{{{2
    return pumvisible
        ?     ActOnPumvisible()
        :     NextMethod()
enddef
# Purpose: {{{
#
# It's invoked  by `<plug>(MC_next_method)`, which  itself is typed at  the very
# end of `NextMethod()`.
# It checks whether the last completion succeeded by looking at the state of the
# menu.
# If it's open, the function calls `ActOnPumvisible()`.
# If it's not, it recalls `NextMethod()` to try another method.
#}}}

def completion#restoreBase() #{{{2
    if orig_line != ''
        setline('.', orig_line)
        augroup CompletionUnletOrigLine | au!
            au CursorMovedI,TextChangedI,InsertLeave,InsertEnter *
                \   exe 'au! CompletionUnletOrigLine'
                | orig_line = ''
        augroup END
    endif
enddef
#}}}1
# Core {{{1
def ActOnPumvisible(): string #{{{2
    pumvisible = false

    # If autocompletion is enabled don't do anything (respect the value of 'cot'). {{{
    #
    # Note that if 'cot' doesn't contain 'noinsert' nor 'noselect', Vim will
    # still automatically insert an entry from the menu.
    # That's why we'll have to make sure that 'cot' contains 'noselect' when
    # autocompletion is enabled.
    #
    # If the method is 'spel', don't do anything either.
    #
    # Why?
    # Fixing a spelling error is a bit different from simply completing text.
    # It's much more error prone.
    # We don't want to force the insertion of the first spelling suggestion.
    # We want `Tab` to respect the value of 'cot'.
    # In particular, the values 'noselect' and 'noinsert'.
    #
    # Otherwise, autocompletion is off, and the current method is not 'spel'.
    # In this case, we want to insert the first or last entry of the menu,
    # regardless of the values contained in 'cot'.
    #
    # Depending on the values in 'cot', there are 3 cases to consider:
    #
    #    1. 'cot' contains 'noselect'
    #
    #       Vim won't do anything (regardless whether 'noinsert' is there).
    #       So, to insert an entry of the menu, we'll have to return:
    #
    #        * `C-p Down` for the methods 'c-p' or 'keyp' (LAST entry)
    #        * `C-n Up`   for all the others              (FIRST entry)
    #
    #       It works but `Down` and `Up`  breaks the undo sequence, meaning that
    #       if we want to repeat the completion with the dot command, a part of
    #       the completion will be lost.
    #
    #       We could also do:
    #
    #         C-n                    works but doesn't respect the user's
    #                                decision of not selecting an entry
    #
    #         C-n C-p                doesn't work at all
    #                                C-n would temporarily insert an entry,
    #                                then C-p would immediately remove it
    #
    #       This means we shouldn't put 'noselect' in 'cot', at least for the
    #       moment.
    #
    #    2. 'cot' doesn't contain 'noselect' nor 'noinsert'
    #
    #       Vim will automatically insert and select an entry.  So, nothing to do.
    #
    #    3. 'cot' doesn't contain 'noselect' but it DOES contain 'noinsert'
    #
    #       Vim will automatically select an entry, but it won't insert it.
    #       To force the insertion, we'll have to return `C-p C-n`.
    #
    #       It will work no matter the method.
    #       If the method is 'c-p' or 'keyp', `C-p` will make us select the
    #       second but last entry, then `C-n` will select and insert the last
    #       entry.
    #       For all the other methods, `C-p` will make us leave the menu,
    #       then `C-n` will select and insert the first entry.
    #
    #       Basically, `C-p` and `C-n` cancel each other out no matter the method.
    #       But `C-n` asks for an insertion.  The result is that we insert the
    #       currently selected entry.
    #}}}

    # For some  reason, we really need  to use non-recursive mappings  for C-n /
    # C-p, even if the popup menu  is visible.  The latter should prevent custom
    # mappings from interfering but it doesn't always.
    # Reproduce:
    #     var MC_CHAIN: string = ['c-p']
    #     ino <c-p> foobar
    #     setl cot=menu,noinsert
    return auto || get(methods, i, '') == 'spel'
        ?     ''
        : stridx(&l:completeopt, 'noselect') == -1
        ? stridx(&l:completeopt, 'noinsert') == -1
        ?     ''
        :     "\<plug>(MC_c-p)\<plug>(MC_c-n)"
        :     get(SELECT_MATCH, methods[i], "\<plug>(MC_c-n)\<plug>(MC_up)")
enddef
# Purpose: {{{
#
# Automatically insert the first (or last) entry in the menu, but only when
# autocompletion is disabled.
#
# Indeed,  when  autocompletion  is  enabled,  we  don't  want  anything  to  be
# automatically inserted.   Because, sometimes it  could be what we  wanted, but
# most of the time it wouldn't be, and we would have to undo the insertion.
# Annoying.  We only want automatic insertion when we press Tab ourselves.
#}}}

def ActOnTextchanged() #{{{2
    # Why is this function in Vim9 script?{{{
    #
    # For this line to work as expected:
    #
    #     && getline('.')->strpart(0, col('.') - 1)[-1] =~ '\f'
    #                                              ^--^
    # In legacy, `[-1]` doesn't refer to anything.
    # In legacy, `[-1:-1]` refers to the last byte.
    # In Vim9, `[-1]` refers to the last character.
    #}}}
    if pumvisible()
        return
    endif

    # What is `completedone`? {{{
    #
    # A flag, which is only on when 3 conditions are met:
    #
    #    - autocompletion is enabled
    #    - a completion has ended (successfully or not); `CompleteDone` event
    #    - we inserted a whitespace or we're at the beginning of a line
    #
    # It's  almost   always  off,   because  as  soon   as  it's   enabled,  the
    # `TextChangedI` event is triggered, and `ActOnTextchanged()` is called.
    # The latter checks the value of the flag and resets it when it's on.
    #
    # What is its purpose?
    #
    # It prevents an autocompletion when one was already performed.
    # Triggering an autocompletion just after another one would probably be an
    # annoyance (except for file completion).
    # If I just autocompleted something, I'm probably done.  I don't need Vim to
    # try another  autocompletion, which may  suggest me matches that  I already
    # saw in the popup menu last time.
    #}}}
    if completedone
        # When an autocompletion has just been performed, we don't need a new one{{{
        # until we insert a whitespace or we're at the beginning of a new line.
        # Indeed, if autocompleting a word just failed, it doesn't make sense to
        # go on trying to autocomplete it, every time we add a character.
        #
        # Besides, autocompletion will be performed only when `completedone` is set.
        # Based on these 2 informations, when `completedone` is set to 1,
        # we shouldn't reset it to 0 until we insert a whitespace:
        #
        #     getline('.')->strpart(0, col('.') - 1)[-1]
        #
        # ... or we are at the beginning of a new line.
        #
        #     col('.') == 1
        #}}}
        if getline('.')->strpart(0, col('.') - 1)[-1] =~ '\s' || col('.') == 1
        # If the text changed *and* a completion was done, we reset `completedone`:{{{
        #
        # When this flag is on, the function doesn't invoke an autocompletion.
        # So it needs to be off for the next time the function will be called.
        #
        # And we reset `manual`.
        #
        # When this variable /flag is on,  it means the completion was initiated
        # manually.
        # We can use this info to  temporarily disable a too costful method when
        # autocompletion is enabled, but still be able to use it manually.
        #
        # For example, we could disable the 'thes' method:
        #
        #     MC_CONDITIONS.thes = () => manual && !empty(&l:thesaurus)
        #
        # Now, the `thes` method can only be tried when 'thesaurus' has a value,
        # *and* the completion was initiated manually by the user.
        #
        # Why do we reset it here?
        # Inside `completion#tabComplete()`, it's set to 1.
        # Inside `completion#enableAuto()`, it's set to 0.
        #
        # Now think about  this.  Autocompletion is enabled,  and we've inserted
        # some text which hasn't been autocompleted, because the text before the
        # cursor didn't match `MC_AUTO_PATTERN`.
        # We still want a completion, so we press Tab.
        # It sets `manual` to 1.  We complete our text, then go on typing.
        #
        # Now, `manual`  will remain with  the value 1, while  autocompletion is
        # still active.
        # It means  autocompletion will try all  the methods in the  chain, even
        # those that we wanted to disable; to prevent that, we reset it here.
        #}}}
            completedone = false
            manual = false
        endif

        # Why `completion#file#complete()`? {{{
        #
        # Usually, when a completion has been done, we don't want
        # autocompletion to be invoked again right afterwards.
        #
        # Exception:    'file' method
        #
        # If we just autocompleted a filepath component (i.e. the current method
        # is 'file'), we want autocompletion to be invoked again, to handle the
        # next component, in case there's one.
        # We just make sure that the character before the cursor is in 'isf'.
        #}}}
        # Why `get()`? {{{
        #
        # Without it, sometimes, we have an error such as:
        #
        #     Error detected while processing function <SNR>67_act_on_textchanged:~
        #     line   81:~
        #     E684: list index out of range: 0~
        #     Error detected while processing function <SNR>67_act_on_textchanged:~
        #     line   81:~
        #     E15: Invalid expression: methods[i] ...~
        #}}}
        if get(methods, i, '') == 'file'
            && getline('.')->strpart(0, col('.') - 1)[-1] =~ '\f'
            sil completion#file#complete()
        endif

    # Purpose of `MC_AUTO_PATTERN`: {{{
    #
    # `strpart(...)` matches the characters from the beginning of the line up to
    # the cursor.
    #
    # We compare them to `mc_auto_pattern`, which is a pattern such as: `\k\k$`.
    #
    # This pattern conditions autocompletion.
    # If its value is `\k\k$`, then autocompletion will only occur when the
    # cursor is after 2 keyword characters.
    # So, for example, there would be no autocompletion, if the cursor was after
    # ` a`, because even though `a` is in 'isk', the space is not.
    #
    # It allows the user to control the frequency of autocompletions.
    # The longer and the more precise the pattern is, the less frequent the
    # autocompletions will be.
    #
    # \a\a is longer than \a, and \a is more precise than \k
    # So in increasing order of autocompletion frequency:
    #
    #     \a\a  <  \a  <  \k
    #}}}
    elseif getline('.')->strpart(0, col('.') - 1) =~ get(b:, 'mc_auto_pattern', MC_AUTO_PATTERN)
        sil feedkeys("\<plug>(MC_Auto)", 'i')
    endif
enddef
# Purpose:{{{
#
# Try an autocompletion every time the text changes in insert mode.
#
# This function is only called when autocompletion is enabled.
# Technically,  it tries  an  autocompletion by  typing `<plug>(MC_Auto)`  which
# calls `completion#complete(1)`.  Similar to pressing Tab.
#}}}

def CanComplete(): bool #{{{2
    return get(b:, 'mc_conditions', MC_CONDITIONS)
          ->get(methods[i], YES_YOU_CAN)(word)
enddef
# Purpose:{{{
#
# During `NextMethod()`, test whether the current method can be applied.
# If it's not, `NextMethod()` will try the next one.
#}}}

def NextMethod(): string #{{{2
    if cycling
        # Explanation of the formula: {{{
        #
        # Suppose we have the list:
        #
        #     let list = ['foo', 'bar', 'baz', 'qux']
        #
        # And we want `var`  to get a value from this list,  then the next, then
        # the next,  ..., and when  we reach  the end of  the list, we  want the
        # variable to get the first item.
        #
        # To store a value from `list` inside `var`, we can write:
        #
        #     let var = list[idx]
        #
        # ... where `idx` is just a number.
        #
        # But what's the relation between 2 consecutive indexes?
        # It can't be as simple as:
        #
        #     next_idx = cur_idx + 1
        #
        # ... because even  though it will work  most of the time,  it will fail
        # when we reach the end of the list.
        #
        # Here is a working formula:
        #
        #     next_idx = (cur_idx + 1) % 4
        #
        # ... where `4` is the length of the list.
        #
        # Indeed, when the current index is below the length of the list,
        # the modulo operator (`% 4`) won't change anything.
        # But when it will reach the end of the list (3), the modulo operator
        # will make the next index go back to the beginning:
        #
        #     (3 + 1) % 4 = 0
        #
        # It works because VimL (and most other programming languages?)
        # indexes a list beginning with 0 (and not 1).
        # If it began with 1, we would have to replace `% 4` with `% 5`.
        #
        # Here is a general formula:
        #
        #     next_idx = (cur_idx + 1) % N
        #
        # ... where N is the length of the list we're indexing.
        #}}}
        # Why do we add `N` ? {{{
        #
        # At the end of this  function, before pressing the completion mappings,
        # we will make sure that `i` is different from `-1` and `N`.
        #
        # Because, if we aren't cycling, and the value of `i` is `-1` or `N`, it
        # means we've tested all the methods in the chain.
        # It's pointless  to go on.   We could  even get stuck  in a loop  if no
        # methods can be applied.  Besides, `methods[N]` does not even exist.
        #
        # So, this check is necessary.  But it cause an issue.
        # If we've press `C-o`  to go back in the chain  (`cycling` is set), and
        # we reach the beginning  of the chain (i = 0), we won't  be able to get
        # back any  further.  We  won't be  able to go  back to  the end  of the
        # chain, because the function won't even try the last / -1 method.
        #
        # To allow `C-o` to  go back to the end of the  chain, in the definition
        # of `i`, we add `N`.
        # When `i` is  different from -1, it won't make  any difference, because
        # of the `% N` operation.
        # But when the value of `i` is  -1, adding `N` will convert the negative
        # index into a positive one, which matches the same method in the chain.
        # The last one.
        #
        # "}}}
        i = (i + dir + N) % N

        # Why is there no risk to be stuck in a loop? {{{
        #
        # We could be afraid to be stuck in a loop, and to prevent that, add the
        # condition that `i` is different from `-1` and `N`.
        #
        # But it's unnecessary.  We can't be stuck in a loop.
        # Indeed, if we're cycling, it means that the popup menu is currently
        # visible and that a method was successful.
        # So,  when we're  cycling, we  can be  sure that  there's AT  LEAST one
        # method which can  be applied, i.e. a method  for which `CanComplete()`
        # returns true/1.
        #
        # Besides, `i` can be equal to `-1` or `N`.
        # It can't be equal  to `N` because it was defined as  the result of a
        # `% N` operation.  The result of such operation can't be `N`.  When
        # you divide something by `n`, the rest is necessarily inferior to `n`.
        # And it can't be equal to `-1`, because in the definition, we add `N`
        # so the result is necessarily positive (zero included).
        #}}}
        while !CanComplete()
            i = (i + dir + N) % N
        endwhile

    else
        # We will get out of the loop as soon as: {{{
        #
        #     the next idx is beyond the chain
        # OR
        #     the method of the current idx can be applied

        # Condition to stay in the loop:
        #
        #     (i+1) % (N+1) != 0    the next idx is not beyond the chain
        #                           IOW there *is* a *next* method
        #
        #     && !CanComplete()     *and* the method of the *current* one can't be applied
        #}}}

        i += dir

        # Why the first 2 conditions? {{{
        #
        # In the previous case (`if cycling`), the only condition to stay in the
        # loop was:
        #
        #     !CanComplete()
        #
        # This time, we have to add:
        #
        #     i != -1 && i != N
        #
        # Indeed, we aren't cycling.  We've just press Tab/S-Tab.
        # So, we don't know whether there's a method which can be applied.
        # If there's none, we could be stuck in a loop.
        # This additional  condition makes sure that  we stop once we  reach the
        # beginning/end of the  chain.  It wouldn't make sense to  go on anyway,
        # because at that point, we would have tried all the methods.
        #}}}
        while i != -1 && i != N && !CanComplete()
            i += dir
        endwhile
    endif

    # What's the meaning of: `&& index(i_history, i) == -1`?{{{
    #
    # We want to make sure that the method to be tried hasn't already been
    # tried since the last time the user was cycling.
    # Otherwise, we could be stuck in an endless loop of failing methods.
    # For example:
    #
    #       2 → 4 → 2 → 4 → ...
    #}}}
    # FIXME: Lifepillar writes:{{{
    #
    #     (i + 1) % (N + 1) != 0
    #
    # I prefer:
    #
    #     i != -1 && i != N
    #
    # It it really equivalent?
    #
    # Besides, currently,  lifepillar's expression states that  `i` is different
    # than `-1` and  `N`, but could it  be extended to any couple  of values `a`
    # and `b`?
    #
    # IOW:
    #
    #     x != -1   &&  x != b    ⇔    (x + 1) % (b + 1) != 0
    #     x != a    &&  x != b    ⇔    ???
    #
    # ---
    #
    # After the while loop:
    #
    #     if (i + 1) % (N + 1) != 0
    #
    # ... is equivalent to:
    #
    #     if CanComplete()
    #
    # Why don't we use that, then?
    # Probably to save some time, the function call would be slower.
    #}}}
    # Why the 2 first conditions? {{{
    #
    # If we're cycling, `i` can't be `-1` nor `N`.
    # However,  if we  are NOT  cycling (Tab,  S-Tab), then  if all  the methods
    # failed, we could  reach the beginning/end of the chain  and then `i` could
    # be `-1` or `N`.
    #
    # In this case, we don't want to try a method.
    # Indeed, we could be stuck in a loop,  and it doesn't make any sense to try
    # any  further.  At  that  point,  we would  have  tested  all the  existing
    # methods.  Besides, there's no `methods[N]` (but there is a `methods[-1]`).
    #
    # Therefore, before pressing the completion  mappings, we make sure that `i`
    # is different from `-1` and `N`.
    #}}}
    if i != -1 && i != N && index(i_history, i) == -1
        # If we're cycling, we  store the index of the method to  be tried, in a
        # list.  We  use it  to compare  its items  with the  index of  the next
        # method to be tried.
        if cycling
            i_history += [i]
        endif

        # 1 - Type the keys to invoke the chosen method. {{{
        #
        # 2 - Store the state of the menu in `pumvisible` through `completion#menuIsUp()`.
        #
        # 3 - call `completion#verifyCompletion()` through `<plug>(MC_next_method)`
        #}}}
        # FIXME: A part of the sequence may be unexpectedly dumped into the buffer.{{{
        #
        #     =pumvisible()?completion#menuIsUp():''
        #
        # That happens if you press `C-c`  to interrupt a method which takes too
        # much time.
        #
        # MWE:
        #
        # First temporarily disable `completion#util#setupDict()` in `MC_CONDITIONS`:
        #
        #     dict: (_) => manual && completion#util#setupDict(),
        #     →
        #     dict: (_) => manual,
        #
        # Then, run this:
        #
        #     $ vim -S <(cat <<'EOF'
        #         vim9script
        #         set dict=/tmp/words
        #         readfile('/usr/share/dict/words')->repeat(10)->writefile('/tmp/words')
        #         startinsert
        #         feedkeys("e\<tab>")
        #     EOF
        #     )
        #
        # Finally, press `C-j` until you  reach the dictionary completion method
        # (right now,  pressing it once  is enough).   Once you reach  it, press
        # `C-c` to interrupt  it.  If Vim is  too fast to populate  the pum, and
        # you  don't  have  enough  time  to  interrupt  it,  increase  `10`  in
        # `->repeat(10)`; the  longer `/tmp/words`  is, the  more time  Vim will
        # need to populate the pum.
        #}}}
        return COMPL_MAPPINGS[methods[i]]
            .. "\<plug>(MC_c-r)=pumvisible()?completion#menuIsUp():''\<cr>\<plug>(MC_next_method)"
    endif

    # Why do we reset `i` here? {{{
    #
    # Consider some unique text, let's say 'jtx', and suppose autocompletion is
    # enabled.
    # When I will insert `x`, an error will occur inside `ActOnTextchanged()`.
    # Specifically when it will try to get:
    #
    #     methods[i]
    #
    # The error occurs because at that moment,  `i` = `N`, and there's no method
    # whose index is `N`. `N`  is the length of the chain,  so the biggest index
    # is `N - 1`.
    #
    # But what leads to this situation?
    #
    # When  I insert  the 1st  character  `j`, `TextChangedI`  is triggered  and
    # `ActOnTextchanged()` is called.  The function does nothing if:
    #
    #     MC_AUTO_PATTERN = \k\k$
    #
    # Then I insert `t`. `TextChangedI` is triggered a second time, the function
    # is called again, and this time it does something, because `jt` match the
    # pattern `\k\k$`.
    # It presses `Tab` for us, to try to autocomplete `jt`.
    # If the text is unique then all the methods in the chain will fail, and `i`
    # will end up with the value `N`.
    # Even though the methods failed, `CompleteDone` was triggered after each of
    # them, and `completedone` was set to `1` each time.
    # `TextChangedI` was  NOT triggered,  because of  our `Plug(MC_next_method)`
    # mapping  at the  end  of `NextMethod()`,  so  `ActOnTextchanged()` is  not
    # called again.
    # Finally,  when we  insert `x`,  `TextChangedI` is  triggered a  last (3rd)
    # time, `ActOnTextchanged()`  is called and  it executes its first  block of
    # code which requires to get the item `methods[i]`.
    #
    # A solution is to use get() like lifepillar did, but it only treats the
    # consequences of some underlying issue.
    #
    # I want to also treat the issue  itself.  Because who knows, maybe it could
    # cause other unknown issues in the future.
    #
    # To tackle  the root  issue, we reset  `i` to 0,  here, when  no completion
    # mapping was press and when `i = N`.
    #}}}
    if i == N
        i = 0
    endif

    return ''
enddef
# Description {{{
#
# `NextMethod()` is called by:
#
#    - `completion#verifyCompletion()`    after a failed completion
#    - `completion#complete()`            1st attempt to complete (auto / manual)
#    - `completion#cycle()`               when we cycle
#}}}
# Purpose: {{{
#
# The function is going to [in|de]crement the index of the next method to try.
# It does it one time.
# Then it checks whether this next method can be applied.
# If it's not, it [in|de]crement it repeatedly until:
#
#    - it finds one if we're cycling
#    - it finds one OR we reach the beginning/end of the chain if we're not cycling
#}}}

