if exists('g:loaded_completion')
    finish
endif
let g:loaded_completion = 1

" Commands {{{1

com -bar McAutoEnable  call completion#enable_auto()
com -bar McAutoDisable call completion#disable_auto()
com -bar McAutoToggle  call completion#toggle_auto()

" Mappings {{{1
" completion {{{2

" expand snippet or complete, when pressing Tab, or S-Tab
ino  <silent><unique> <tab>                    <c-r>=completion#snippet_or_complete(1)<cr>
ino  <silent><unique> <s-tab>                  <c-r>=completion#snippet_or_complete(-1)<cr>
imap <expr><silent>   <plug>(MC_tab_complete)  completion#tab_complete(1)
imap <expr><silent>   <plug>(MC_stab_complete) completion#tab_complete(-1)

" same thing for `C-g Tab`; useful when we're expanding a snippet
imap <expr><silent><unique> <c-g><tab> completion#tab_complete(1)

snor <silent><unique>   <tab> <esc>:call UltiSnips#JumpForwards()<cr>
snor <silent><unique> <s-tab> <esc>:call UltiSnips#JumpBackwards()<cr>

" The next mappings are necessary to prevent custom mappings from interfering.
" We don't want recursiveness for those keys when we're in regular insert mode.
" In C-x submode, custom mappings should not interfere.

" typed/returned by `completion#complete()`
ino <silent> <plug>(MC_tab) <tab>
ino <silent> <plug>(MC_c-d) <c-d>

" typed/returned by `completion#cycle()`
ino <silent> <plug>(MC_c-e) <c-e>
ino <silent> <plug>(MC_c-n) <c-n>
ino <silent> <plug>(MC_c-p) <c-p>
ino <silent> <plug>(MC_c-r) <c-r>
ino <silent> <plug>(MC_c-x_c-v) <c-x><c-v>
ino <silent> <plug>(MC_c-x_c-d) <c-x><c-d>
ino <silent> <plug>(MC_c-x_c-k) <c-x><c-k>
ino <silent> <plug>(MC_c-x_c-i) <c-x><c-i>
ino <silent> <plug>(MC_c-x_c-n) <c-x><c-n>
ino <silent> <plug>(MC_c-x_c-p) <c-x><c-p>
ino <silent> <plug>(MC_c-x_c-l) <c-x><c-l>
ino <silent> <plug>(MC_c-x_c-o) <c-x><c-o>
ino <silent> <plug>(MC_c-x_c-]) <c-x><c-]>
ino <silent> <plug>(MC_c-x_c-t) <c-x><c-t>
ino <silent> <plug>(MC_c-x_c-u) <c-x><c-u>
ino <silent> <plug>(MC_down) <down>
ino <silent> <plug>(MC_up) <up>
cno          <plug>(MC_cr) <cr>

" Because  of a  mapping in  `vim-readline`, we've  lost the  ability to  exit a
" completion menu. Restore it on `c-q`.
" TODO: Document why we need `#restore_base()`.
" Hint: it's due to `longest` being in `'cot'`.
" Also, document why we don't invoke `#restore_base()` in `<plug>(MC_c-e)`.
" Hint: it would break the dot command too frequently (as soon as we cycle).
ino <silent> <c-q> <c-e><c-r>=completion#restore_base()<cr>

" cycling {{{2

imap <expr><silent><unique> <c-j>         pumvisible() ? completion#cycle(1) : '<plug>(MC_cr)'
ino        <silent>         <plug>(MC_cr) <cr>

" To cycle back, we can't use `c-k` because it would be shadowed by `c-k c-k`
" (vimrc) which deletes from cursor till end of line.
" It's hard to find a key for this mapping (can't use `c-h`, `c-l`, `c-k`, …).
" We'll try `c-o` with the mnemonic: Old (cycle back).
imap <expr><silent><unique> <c-o>          pumvisible() ? completion#cycle(-1) : '<plug>(MC_c-o)'
ino        <silent>         <plug>(MC_c-o) <c-o>

imap <expr><silent> <plug>(MC_next_method) completion#verify_completion()
imap <expr><silent> <plug>(MC_Auto)        completion#complete(1)

nno <silent><unique> [oM :<c-u>call completion#enable_auto()<cr>
nno <silent><unique> ]oM :<c-u>call completion#disable_auto()<cr>
nno <silent><unique> coM :<c-u>call completion#toggle_auto()<cr>

" improved default methods {{{2
" C-p         &friends {{{3

" What's the purpose of `completion#util#custom_isk()`?{{{
"
" Most default ftplugins don't include `-`  in 'isk', but it's convenient to
" include it temporarily when we complete a word such as `foo-bar-baz`.
"
" So we invoke this function to temporarily add it.
"}}}
ino <silent><unique> <c-p>      <c-r>=completion#util#custom_isk('-')[-1]<cr><c-p>
ino <silent><unique> <c-x><c-n> <c-r>=completion#util#custom_isk('-')[-1]<cr><c-x><c-n>
ino <silent><unique> <c-x><c-p> <c-r>=completion#util#custom_isk('-')[-1]<cr><c-x><c-p>

" C-x C-]     tag {{{3

" Some Vim tags contain a colon or begin with a less-than sign.{{{
"
" Maybe we should add `:` to `'isk'` unconditionally:
"
"     '-:'..(&ft is# 'vim' ? '<' : '')
"
" But it doesn't seem necessary atm.
"}}}
"                                                                      │
ino <silent><unique> <c-x><c-]> <c-r>=completion#util#custom_isk('-'..(&ft is# 'vim' ? ':<' : ''))[-1]<cr><c-x><c-]>

" C-x C-k     dictionary {{{3

ino <silent><unique> <c-x><c-k> <c-r>=completion#util#setup_dict()[-1]<cr><c-x><c-k>

" C-x C-s     fix Spelling error {{{3

ino <expr><silent><unique> <c-x><c-s> completion#spel#fix()

" C-x C-t     synonym {{{3

" Pb:
" If a synonym contains several words (e.g. important → of vital importance),
" the completion function considers each of them as a distinct synonym.
" Thus, if  a synonym contains  3 words, the function  populates the pum  with 3
" matches.

" Solution: http://stackoverflow.com/a/21132116
"
" Create a  wrapper around C-x C-t  to temporarily include the  space and hyphen
" characters in 'isk'. We'll  remove them as soon as the  completion is done (or
" cancelled).
" It doesn't seem to affect the completed text, only the synonyms.
" Even with a space in 'isk', the completion function only tries to complete the
" last word before the cursor.

ino <silent><unique> <c-x><c-t> <c-r>=completion#util#custom_isk(' -')[-1]<cr><c-x><c-t>
"}}}2
" new methods {{{2
" C-x s       function Signature {{{3

" Usage:
"
"    1. insert `call matchadd(`
"    2. press `C-x s`
"    3. you get `call matchadd({group}, {pattern} [, {priority} [, {id} [, {dict}]]])`

" Why not using a single `:noremap!` with the `<expr>` argument?{{{
"
" We can't use `<expr>` because of an issue with Nvim.
" After pressing  the lhs, you would  need to insert an  additional character to
" cause a redraw; otherwise, you would not see the completed text.
"
" It's probably due to:
" https://github.com/neovim/neovim/issues/9006
"
" And we  can't use a single  `:noremap!`, because we want  `<silent>` in insert
" mode, but  we can't use  it in command-line mode  (again, we wouldn't  see the
" completed text, neither in Vim nor in Nvim).
"}}}
ino <silent><unique> <c-x>s <c-r>=completion#custom#signature(mode())<cr>
cno         <unique> <c-x>s <c-\>e completion#custom#signature(mode())<cr>

" C-z         easy C-x C-p {{{3

" Inspiration:
" https://www.reddit.com/r/vim/comments/78h4pr/plugins_andor_keybindings_you_couldnt_live_without/dou7z5n/
ino <silent><unique> <c-z> <c-r>=completion#custom#easy_c_x_c_p()<cr><c-x><c-p>
"}}}1
" Options {{{1
" complete {{{2

" where should Vim look when pressing `C-n`/`C-p`
set complete=.,w,b
"            │ │ │
"            │ │ └ buffers in buffer list
"            │ └ other windows
"            └ current buffer

" completeopt {{{2
" menuone {{{3

" We add `menuone` for 3 reasons:{{{
"
"    - the menu allows us to cancel  a completion if the inserted text is not
"      the one we wanted
"
"    - when there's only 1 match and `noinsert` is absent from `'cot'`, the menu
"      will not  open and vim-completion  will think  that the current  method has
"      failed, then will immediately try the  next one; because of this, we could
"      end up with 2 or more completed texts
"
"    - when there's only 1 match and `noinsert` is in `'cot'`, *all* completion commands fail:
"
"         $ vim +"pu ='xxabc'" +"pu ='xx'" +'startinsert!' +'set cot=menu,noinsert'
"         " press `C-x C-n`: nothing is inserted
"}}}
set cot+=menuone

" noinsert {{{3

" We remove `noinsert` for 3 reasons:{{{
"
"    - it breaks the repetition of `C-x C-p`
"
"      The  first invocation  works,  but  the consecutive  ones  don't work  as
"      expected.  Indeed,  we have  to press  enter to insert  a match  from the
"      menu.  This CR breaks the chaining of `C-x C-p`.
"
"    - if we remove `menuone`, it  would break all completion mechanisms when
"      there's only 1 match
"
"    - it's annoying while in auto-completion mode
"
"      vim-completion already makes sure that  `noinsert` is not in `'cot'` while
"      in auto mode, but still...
"}}}
set cot-=noinsert

" noselect {{{3

" do *not* include `noselect`{{{
"
" We use a completion system which would break the undo sequence when `noselect`
" is in  `'cot'`.  It means  that some text  would be lost  when we use  the dot
" command to repeat a completion.
"
" I think that's  because of the keys stored in  `s:SELECT_MATCH` and pressed by
" `s:act_on_pumvisible()`.
"}}}
set cot-=noselect

" longest {{{3

" Rationale:{{{
"
" When we  tab-complete a  word, if there  are several matches  and we  insert a
" character to reduce their number, the popup menu closes.
"
" Adding `noselect` in `'cot'` would fix this issue, but it would also break the
" dot command, because our plugin would press an up or down key.
"
" So, instead, we include `longest`; it doesn't fix the issue entirely, but it helps.
" To test its effect, write this in a file:
"
"     xxa
"     xxab
"     xxabc
"     xxabcd
"
" Then:
"
"    - insert 'xx'
"    - press Tab
"    - insert 'a': the menu doesn't close
"    - insert 'b': the menu doesn't close
"
" The pum doesn't close anymore.
" However, it *will* after you've selected a match:
"
"    - insert 'xx'
"    - press Tab
"    - press `C-n` until `xxa` is selected
"    - insert 'b': the menu closes
"
" ---
"
" `longest` is also useful when:
"
"    - the pum contains a lot of matches
"    - the match you want is *not* near the start/end of the pum, but somewhere in the middle
"    - the initial inserted match is much longer than the initial text
"
" When  the 3  previous statements  are true,  completing your  text is  painful
" without `longest`.
"
" MWE:
"
"     $ vim -Nu <(cat <<'EOF'
"         let seed = srand()
"         let lines = range(200)->map({-> 'we_dont_want_this_'..range(10)->map({-> (65 + rand(g:seed) % 26)->nr2char()})->join('')})
"         sil 0pu=lines
"         100t100 | s/$/_actually_we_do_want_this_one/ | 0pu='# press C-x C-n to complete the next line into `'..getline(101)..'`'
"         set cot=menu,longest
"         1pu='we_'
"         startinsert!
"     EOF
"     )
"
" On the first line of the file, you should see sth like:
"
"     # press C-x C-n to complete the next line into `we_dont_want_this_QGDSIYNDSI_actually_we_do_want_this_one`
"
" Press `C-x C-n`: a huge menu should be opened (>200 matches).
" Press `Q`: the menu gets much smaller, and you should probably see your match.
" If you don't see it, it should appear after pressing `G`, or maybe after `D`.
" The point is that finding your match is easy.
"
" OTOH,  if `longest`  was  not in  `'cot'` (repeat  the  same experiment  after
" executing  `set  cot-=longest`),   you  would  probably  need   to  remove  10
" characters, before inserting `Q`, `G`, `D`...
" This may seem like a minor issue; it's not. In practice, you don't always know
" exactly how many characters you need to remove.
" And when  that happens,  each time you  remove a character  and the  menu gets
" updated, you may need to scroll through the menu to look for your match.
" Anyway, the whole process is usually too cumbersome.
"}}}
set cot+=longest

" preview → popup {{{3

" When we press `C-x C-g` by  accident, the unicode.vim plugin opens the preview
" window (digraph completion), and we have to close it manually.  It's annoying.
"
" If one day, we  need to add 'preview' in 'cot' again, we  could get around the
" unicode.vim  plugin issue  with an  autocmd  which closes  the preview  window
" automatically each time we complete a text:
"
"     au CompleteDone * if pumvisible() == 0 | pclose | endif

set cot-=preview

" a popup doesn't suffer from this issue, and is less obtrusive in general;
" unfortunately, Nvim doesn't support a float equivalent atm
if !has('nvim')
    set cot+=popup
endif
"}}}2
" infercase {{{2

" Add some intelligence regarding the case of a text which is completed.{{{
"
" For example, suppose we have the word `WeirdCaseWord` in a buffer.
" We insert `weirdc` and press `C-x C-n` to complete:
"
"    - with `noinfercase`, we get `WeirdCaseWord`
"    - with `infercase`  , we get `weirdcaseword`
"
" ---
"
" Commented because I find it annoying at the moment.
" Besides,  it's a  buffer-local option,  so it  should be  set from  a filetype
" plugin.
"}}}
"     set infercase

" isfname {{{2

" A filename can contain an `@` character.
" Example: /usr/lib/systemd/system/getty@.service
"
" It's important to include  `@` in `'isf'`, so that we  can complete a filename
" by pressing Tab.
set isfname+=@-@

" thesaurus {{{2

" `C-x C-t`  looks for synonyms in  all the files  whose path is present  in the
" option `'thesaurus'`.
" Each  line of  the  file must  contain  a  group of  synonyms  separated by  a
" character which is not in `'isk'` (space or comma for example).
"
" We can download such a file at the following url:
" https://archive.org/stream/mobythesauruslis03202gut/mthesaur.txt
"
" Otherwise, search the following query on google:
"
"     mthesaur.txt filetype:txt

set thesaurus+=$HOME/.vim/tools/mthesaur.txt
"}}}1
" Autocmds {{{1

" Keep this autocmd **after** setting `'cot'`!
augroup hoist_cot
    au!
    au User MyFlags call statusline#hoist('global',
        \ '%2*%{&cot !=# "'..&cot..'" && mode(1) is# "n"? "[cot+]" : ""}', 25,
        \ expand('<sfile>')..':'..expand('<sflnum>'))
    au OptionSet completeopt call timer_start(0, {-> execute('redrawt')})
augroup END

