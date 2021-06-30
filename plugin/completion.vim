vim9script noclear

if exists('loaded') | finish | endif
var loaded = true

# TODO: Implement the concept of "scoped chains".
# That is, make Vim use different chains depending on the syntax under the cursor.
# https://github.com/lifepillar/vim-mucomplete/commit/c765784f621e9ed2615cc7490fac446db61466bb

# Commands {{{1

command -bar McAutoEnable  completion#enableAuto()
command -bar McAutoDisable completion#disableAuto()
command -bar McAutoToggle  completion#toggleAuto()

# Mappings {{{1
# completion {{{2

# expand snippet or complete, when pressing Tab, or S-Tab
inoremap  <silent><unique> <Tab>               <Cmd>call completion#snippetOrComplete(1)<CR>
inoremap  <silent><unique> <S-Tab>             <Cmd>call completion#snippetOrComplete(-1)<CR>
imap <expr><silent>   <Plug>(MC_tab_complete)  completion#tabComplete(1)
imap <expr><silent>   <Plug>(MC_stab_complete) completion#tabComplete(-1)

# same thing for `C-g Tab`; useful when we're expanding a snippet
imap <expr><silent><unique> <C-G><Tab> completion#tabComplete(1)

snoremap <unique>   <Tab> <C-\><C-N><Cmd>call UltiSnips#JumpForwards()<CR>
snoremap <unique> <S-Tab> <C-\><C-N><Cmd>call UltiSnips#JumpBackwards()<CR>

# The next mappings are necessary to prevent custom mappings from interfering.
# We don't want recursiveness for those keys when we're in regular insert mode.
# In C-x submode, custom mappings should not interfere.

# typed/returned by `completion#complete()`
inoremap <Plug>(MC_tab) <Tab>
inoremap <Plug>(MC_c-d) <C-D>

# typed/returned by `completion#cycle()`
inoremap <Plug>(MC_c-e) <C-E>
inoremap <Plug>(MC_c-n) <C-N>
inoremap <Plug>(MC_c-p) <C-P>
inoremap <Plug>(MC_c-r) <C-R>
inoremap <Plug>(MC_c-x_c-v) <C-X><C-V>
inoremap <Plug>(MC_c-x_c-d) <C-X><C-D>
inoremap <Plug>(MC_c-x_c-k) <C-X><C-K>
inoremap <Plug>(MC_c-x_c-i) <C-X><C-I>
inoremap <Plug>(MC_c-x_c-n) <C-X><C-N>
inoremap <Plug>(MC_c-x_c-p) <C-X><C-P>
inoremap <Plug>(MC_c-x_c-l) <C-X><C-L>
inoremap <Plug>(MC_c-x_c-o) <C-X><C-O>
inoremap <Plug>(MC_c-x_c-]) <C-X><C-]>
inoremap <Plug>(MC_c-x_c-t) <C-X><C-T>
inoremap <Plug>(MC_c-x_c-u) <C-X><C-U>
inoremap <Plug>(MC_down) <Down>
inoremap <Plug>(MC_up) <Up>
cnoremap <Plug>(MC_cr) <CR>

# Because  of a  mapping in  `vim-readline`, we've  lost the  ability to  exit a
# completion menu.  Restore it on `C-q`.
# TODO: Document why we need `#restore_base()`.
# Hint: it's due to `longest` being in `'completeopt'`.
# Also, document why we don't invoke `#restore_base()` in `<Plug>(MC_c-e)`.
# Hint: it would break the dot command too frequently (as soon as we cycle).
inoremap <C-Q> <C-E><Cmd>call completion#restoreBase()<CR>

# cycling {{{2

imap <expr><silent><unique> <C-J> pumvisible() ? completion#cycle(1) : '<Plug>(MC_cr)'
inoremap <Plug>(MC_cr) <CR>

# To cycle back, we can't use `C-k` because it would be shadowed by `C-k C-k`
# (vimrc) which deletes from cursor till end of line.
# It's hard to find a key for this mapping (can't use `C-h`, `C-l`, `C-k`, ...).
# We'll try `C-o` with the mnemonic: Old (cycle back).
imap <expr><silent><unique> <C-O> pumvisible() ? completion#cycle(-1) : '<Plug>(MC_c-o)'
inoremap <Plug>(MC_c-o) <C-O>

imap <expr><silent> <Plug>(MC_next_method) completion#verifyCompletion()
imap <expr><silent> <Plug>(MC_Auto)        completion#complete(1)

nnoremap [oM <Cmd>call completion#enableAuto()<CR>
nnoremap ]oM <Cmd>call completion#disableAuto()<CR>
nnoremap coM <Cmd>call completion#toggleAuto()<CR>

# improved default methods {{{2
# C-p         &friends {{{3

# What's the purpose of `completion#util#customIsk()`?{{{
#
# Most default ftplugins  don't include `-` in 'iskeyword',  but it's convenient
# to include it temporarily when we complete a word such as `foo-bar-baz`.
#
# So we invoke this function to temporarily add it.
#}}}
inoremap <unique> <C-P>      <Cmd>call completion#util#customIsk('-')<CR><C-P>
inoremap <unique> <C-X><C-N> <Cmd>call completion#util#customIsk('-')<CR><C-X><C-N>
inoremap <unique> <C-X><C-P> <Cmd>call completion#util#customIsk('-')<CR><C-X><C-P>

# C-x C-]     tag {{{3

# Some Vim tags contain a colon or begin with a less-than sign.{{{
#
# Maybe we should add `:` to `'iskeyword'` unconditionally:
#
#     '-:' .. (&filetype ==# 'vim' ? '<' : '')
#
# But it doesn't seem necessary atm.
#}}}
#                                                                        │
inoremap <unique> <C-X><C-]> <Cmd>call completion#util#customIsk('-' .. (&filetype ==# 'vim' ? ':<' : ''))<CR><C-X><C-]>

# C-x C-k     dictionary {{{3

inoremap <unique> <C-X><C-K> <Cmd>call completion#util#setupDict()<CR><C-X><C-K>

# C-x C-s     fix Spelling error {{{3

inoremap <expr><unique> <C-X><C-S> completion#spel#fix()

# C-x C-t     synonym {{{3

# Pb:
# If a synonym contains several words (e.g. important → of vital importance),
# the completion function considers each of them as a distinct synonym.
# Thus, if  a synonym contains  3 words, the function  populates the pum  with 3
# matches.

# Solution: http://stackoverflow.com/a/21132116
#
# Create a  wrapper around C-x C-t  to temporarily include the  space and hyphen
# characters in  'iskeyword'.  We'll remove  them as  soon as the  completion is
# done (or cancelled).
# It doesn't seem to affect the completed  text, only the synonyms.  Even with a
# space in 'iskeyword', the completion function  only tries to complete the last
# word before the cursor.

inoremap <unique> <C-X><C-T> <Cmd>call completion#util#customIsk(' -')<CR><C-X><C-T>
#}}}2
# new methods {{{2
# C-x s       function Signature {{{3

# Usage:
#
#    1. insert `call matchadd(`
#    2. press `C-x s`
#    3. you get `call matchadd({group}, {pattern} [, {priority} [, {id} [, {dict}]]])`

inoremap <unique> <C-X>s <Cmd>call mode()->completion#custom#signature()<CR>
cnoremap <unique> <C-X>s <C-\>e mode()->completion#custom#signature()<CR>

# C-z         easy C-x C-p {{{3

# Inspiration:
# https://www.reddit.com/r/vim/comments/78h4pr/plugins_andor_keybindings_you_couldnt_live_without/dou7z5n/
inoremap <unique> <C-Z> <Cmd>call completion#custom#easyCXCP()<CR><C-X><C-P>
#}}}1
# Options {{{1
# complete {{{2

# where should Vim look when pressing `C-n`/`C-p`
&complete = '.,w,b'
#            │ │ │
#            │ │ └ buffers in buffer list
#            │ └ other windows
#            └ current buffer

# completeopt {{{2
# menuone {{{3

# We add `menuone` for 3 reasons:{{{
#
#    - the menu lets us cancel a completion if the inserted text is not the one we wanted
#
#    - when there's only 1 match and `noinsert` is absent from `'completeopt'`, the menu
#      will not  open and vim-completion  will think  that the current  method has
#      failed, then will immediately try the  next one; because of this, we could
#      end up with 2 or more completed texts
#
#    - when there's only 1 match and `noinsert` is in `'completeopt'`,
#      *all* completion commands fail:
#
#         $ vim +"put ='xxabc'" +"put ='xx'" +'startinsert!' +'set completeopt=menu,noinsert'
#         " press `C-x C-n`: nothing is inserted
#}}}
set completeopt+=menuone

# noinsert {{{3

# We remove `noinsert` for 3 reasons:{{{
#
#    - it breaks the repetition of `C-x C-p`
#
#      The  first invocation  works,  but  the consecutive  ones  don't work  as
#      expected.  Indeed,  we have  to press  enter to insert  a match  from the
#      menu.  This CR breaks the chaining of `C-x C-p`.
#
#    - if we remove `menuone`, it  would break all completion mechanisms when
#      there's only 1 match
#
#    - it's annoying while in auto-completion mode
#
#      vim-completion already makes sure that  `noinsert` is not in `'completeopt'`
#      while in auto mode, but still...
#}}}
set completeopt-=noinsert

# noselect {{{3

# do *not* include `noselect`{{{
#
# We use a completion system which would break the undo sequence when `noselect`
# is in `'completeopt'`.  It means that some  text would be lost when we use the
# redo command to repeat a completion.
#
# I think  that's because of  the keys stored  in `SELECT_MATCH` and  pressed by
# `ActOnPumvisible()`.
#}}}
set completeopt-=noselect

# longest {{{3

# Rationale:{{{
#
# When we  tab-complete a  word, if there  are several matches  and we  insert a
# character to reduce their number, the popup menu closes.
#
# Adding `noselect` in  `'completeopt'` would fix this issue, but  it would also
# break the dot command, because our plugin would press an up or down key.
#
# So, instead, we include `longest`; it doesn't fix the issue entirely, but it helps.
# To test its effect, write this in a file:
#
#     xxa
#     xxab
#     xxabc
#     xxabcd
#
# Then:
#
#    - insert 'xx'
#    - press Tab
#    - insert 'a': the menu doesn't close
#    - insert 'b': the menu doesn't close
#
# The pum doesn't close anymore.
# However, it *will* after you've selected a match:
#
#    - insert 'xx'
#    - press Tab
#    - press `C-n` until `xxa` is selected
#    - insert 'b': the menu closes
#
# ---
#
# `longest` is also useful when:
#
#    - the pum contains a lot of matches
#    - the match you want is *not* near the start/end of the pum, but somewhere in the middle
#    - the inserted match is much longer than the original text
#
# When  the 3  previous statements  are true,  completing your  text is  painful
# without `longest`.
#
# MWE:
#
#     $ vim -Nu <(cat <<'EOF'
#         vim9script
#
#         var seed: list<number> = srand()
#         var lines = range(200)
#             ->mapnew((_, _) => 'we_dont_want_this_'
#                 .. range(10)->mapnew((_, _) => (65 + rand(seed) % 26)->nr2char())
#                  ->join(''))
#
#         silent :0 put =lines
#         :100 copy 100
#         substitute/$/_actually_we_do_want_this_one/
#         :0 put ='# press C-x C-n to complete the next line into `' .. getline(101) .. '`'
#         set completeopt=menu,longest
#         :1 put ='we_'
#         startinsert!
#     EOF
#     )
#
# On the first line of the file, you should see sth like:
#
#     # press C-x C-n to complete the next line into `we_dont_want_this_QGDSIYNDSI_actually_we_do_want_this_one`
#
# Press `C-x C-n`: a huge menu should be opened (>200 matches).
# Press `Q`: the menu gets much smaller, and you should probably see your match.
# If you don't see it, it should appear after pressing `G`, or maybe after `D`.
# The point is that finding your match is easy.
#
# OTOH,  if `longest`  was not  in `'completeopt'`  (repeat the  same experiment
# after executing `set completeopt-=longest`), you would probably need to remove
# 10 characters, before inserting `Q`, `G`, `D`...
# This may  seem like a  minor issue; it's not.   In practice, you  don't always
# know exactly how many characters you need to remove.
# And when  that happens,  each time you  remove a character  and the  menu gets
# updated, you may need to scroll through the menu to look for your match.
# Anyway, the whole process is usually too cumbersome.
#}}}
set completeopt+=longest

# preview → popup {{{3

# When we press `C-x C-g` by  accident, the unicode.vim plugin opens the preview
# window (digraph completion), and we have to close it manually.  It's annoying.
#
# If one  day, we  need to add  'preview' in 'completeopt'  again, we  could get
# around the unicode.vim  plugin issue with an autocmd which  closes the preview
# window automatically each time we complete a text:
#
#     autocmd CompleteDone * if pumvisible() == 0 | pclose | endif

set completeopt-=preview

# a popup doesn't suffer from this issue, and is less obtrusive in general
set completeopt+=popup
#}}}2
# infercase {{{2

# Add some intelligence regarding the case of a text which is completed.{{{
#
# For example, suppose we have the word `WeirdCaseWord` in a buffer.
# We insert `weirdc` and press `C-x C-n` to complete:
#
#    - with `noinfercase`, we get `WeirdCaseWord`
#    - with `infercase`  , we get `weirdcaseword`
#
# ---
#
# Commented because I find it annoying at the moment.
# Besides,  it's a  buffer-local option,  so it  should be  set from  a filetype
# plugin.
#}}}
#     &infercase = true

# isfname {{{2

# A filename can contain an `@` character.
# Example: /usr/lib/systemd/system/getty@.service
#
# It's  important to  include `@`  in  `'isfname'`, so  that we  can complete  a
# filename by pressing Tab.
set isfname+=@-@

# thesaurus {{{2

# `C-x C-t`  looks for synonyms in  all the files  whose path is present  in the
# option `'thesaurus'`.
# Each  line of  the  file must  contain  a  group of  synonyms  separated by  a
# character which is not in `'iskeyword'` (space or comma for example).
#
# We can download such a file at the following url:
# https://archive.org/stream/mobythesauruslis03202gut/mthesaur.txt
#
# Otherwise, search the following query on google:
#
#     mthesaur.txt filetype:txt

set thesaurus+=$HOME/.vim/tools/mthesaur.txt
#}}}1
