if exists('g:loaded_completion')
    finish
endif
let g:loaded_completion = 1

" Commands {{{1

com! -bar McAutoEnable  call completion#enable_auto()
com! -bar McAutoDisable call completion#disable_auto()
com! -bar McAutoToggle  call completion#toggle_auto()

" Mappings {{{1
" completion {{{2

" Expand snippet or complete, when hitting Tab, or S-Tab
ino   <silent><unique>    <tab>                   <c-r>=completion#snippet_or_complete(1)<cr>
ino   <silent><unique>  <s-tab>                   <c-r>=completion#snippet_or_complete(-1)<cr>
imap  <expr><silent>    <plug>(MC_tab_complete)   completion#tab_complete(1)
imap  <expr><silent>    <plug>(MC_stab_complete)  completion#tab_complete(-1)

" Same thing for C-g Tab; useful when we're expanding a snippet
imap  <expr><silent><unique>  <c-g><tab>          completion#tab_complete(1)

snor  <silent><unique>    <tab>                   <esc>:call UltiSnips#JumpForwards()<cr>
snor  <silent><unique>  <s-tab>                   <esc>:call UltiSnips#JumpBackwards()<cr>

" The next mappings are necessary to prevent custom mappings from interfering.

" Typed/returned by completion#complete()
ino  <silent>  <plug>(MC_tab)  <tab>
ino  <silent>  <plug>(MC_c-d)  <c-d>

" Typed/returned by completion#cycle()
ino  <silent>  <plug>(MC_c-e)   <c-e>
ino  <silent>  <plug>(MC_c-n)   <c-n>
ino  <silent>  <plug>(MC_c-p)   <c-p>
ino  <silent>  <plug>(MC_c-r)   <c-r>
ino  <silent>  <plug>(MC_down)  <down>
ino  <silent>  <plug>(MC_up)    <up>

" We don't want recursiveness for those keys when we're in regular insert mode.
" In C-x submode, custom mappings should not interfere.

" cycling {{{2

imap  <expr><silent><unique>  <c-j>          pumvisible() ? completion#cycle(1) : '<plug>(MC_cr)'
ino         <silent>          <plug>(MC_cr)  <cr>

" To cycle back, we can't use `c-k` because it would be shadowed by `c-k c-k`
" (vimrc) which deletes from cursor till end of line.
" It's hard to find a key for this mapping (can't use `c-h`, `c-l`, `c-k`, …).
" We'll try `c-o` with the mnemonic: Old (cycle back).
imap  <expr><silent><unique>  <c-o>           pumvisible() ? completion#cycle(-1) : '<plug>(MC_c-o)'
ino         <silent>          <plug>(MC_c-o)  <c-o>

imap  <expr><silent>  <plug>(MC_next_method)  completion#verify_completion()
imap  <expr><silent>  <plug>(MC_Auto)         completion#complete(1)

nno  <silent><unique>  [om  :<c-u>call completion#enable_auto()<cr>
nno  <silent><unique>  ]om  :<c-u>call completion#disable_auto()<cr>
nno  <silent><unique>  com  :<c-u>call completion#toggle_auto()<cr>

" improved default methods {{{2
" C-p         &friends {{{3

" What's the purpose of `completion#util#custom_isk()`?{{{
"
" Most default ftplugins don't include `-`  in 'isk', but it's convenient to
" include it temporarily when we complete a word such as `foo-bar-baz`.
"
" So we invoke this function to temporarily add it.
"}}}
" What's the purpose of `completion#util#hyphen_is_already_in_isk()`?{{{
"
" Some default  ftplugins DO include  `-` in 'isk';  we shouldn't remove  it for
" them.
"
" How to find which default ftplugins include `-` in 'isk'?
"
"     :noa vim /\vsetl%[ocal]\s+isk%[eyword]\+?\=.*-%(\@|\w)@!/gj $VIMRUNTIME/**/*.vim | cw
"}}}

ino  <silent><unique>  <c-p>       <c-r>=completion#util#custom_isk(index(completion#util#hyphen_is_already_in_isk(), &ft) ==# -1 ? '-' : '')<cr><c-p>
ino  <silent><unique>  <c-x><c-n>  <c-r>=completion#util#custom_isk(index(completion#util#hyphen_is_already_in_isk(), &ft) ==# -1 ? '-' : '')<cr><c-x><c-n>
ino  <silent><unique>  <c-x><c-p>  <c-r>=completion#util#custom_isk(index(completion#util#hyphen_is_already_in_isk(), &ft) ==# -1 ? '-' : '')<cr><c-x><c-p>

" C-x C-]     tag {{{3

ino  <silent><unique>  <c-x><c-]>  <c-r>=completion#util#custom_isk('-'.(&ft is# 'vim' ? ':<' : ''))<cr><c-x><c-]>
"                                                                        │
" Some Vim tags contain a colon or begin with a less-than sign.{{{
"
" Maybe we should add `:` to 'isk' unconditionally:
"
"     '-:'.(&ft is# 'vim' ? '<' : '')
"
" But it doesn't seem necessary atm.
"}}}

" C-x C-k     dictionary {{{3

ino  <silent><unique>  <c-x><c-k>  <c-r>=completion#util#setup_dict()<cr><c-x><c-k>

" C-x C-s     fix Spelling error {{{3

ino  <expr><silent><unique>  <c-x><c-s>  completion#spel#fix()

" C-x C-t     synonym {{{3

" Pb:
" If a synonym contains several words (e.g. important → of vital importance),
" the completion function considers each of them as a distinct synonym.
" Thus, if a synonym contains 3 words, the function populates the popup
" menu with 3 entries.

" Solution:
"         http://stackoverflow.com/a/21132116
"
" Create a  wrapper around C-x C-t  to temporarily include the  space and hyphen
" characters in 'isk'. We'll  remove them as soon as the  completion is done (or
" cancelled).
" It doesn't seem to affect the completed text, only the synonyms.
" Even with a space in 'isk', the completion function only tries to complete the
" last word before the cursor.

ino  <silent><unique>  <c-x><c-t>  <c-r>=completion#util#custom_isk(' -')<cr><c-x><c-t>

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
ino  <silent><unique>  <c-x>s  <c-r>=completion#custom#signature(mode(1))<cr>
cno          <unique>  <c-x>s  <c-\>ecompletion#custom#signature(mode(1))<cr>

" C-z         easy C-x C-p {{{3

" Inspiration:
" https://www.reddit.com/r/vim/comments/78h4pr/plugins_andor_keybindings_you_couldnt_live_without/dou7z5n/
ino  <expr><silent><unique>  <c-z>  completion#custom#easy_c_x_c_p()

" Options {{{1
" complete {{{2
"
" where should Vim look when using C-n/C-p
set complete=.,w,b
"            │ │ │
"            │ │ └─ buffers in buffer list
"            │ └─ other windows
"            └─ current buffer

" completeopt {{{2
" menuone {{{3
"
" We add 'menuone' for 2 reasons:
"
"     - the menu allows us to cancel  a completion if the inserted text is not
"       the one we wanted
"
"     - when  there's   only  1  candidate,  the  menu  will   not  open  and
"       vim-completion will  think that the  current method has failed,  then will
"       immediately try the  next one; because of  this we could end up  with 2 or
"       more completed texts
set cot+=menuone

" Issue1:
" When we press C-d / C-u while the  popup menu is visible, and there are only a
" few entries, we don't want to move in the menu, we want to delete text.
" This issue is particularly annoying when there's only one entry in the menu.

" Issue2:
" If there's only 1 candidate to complete  a word and 'noinsert' is in 'cot', we
" won't be able to complete the  latter. This is an issue for default completion
" mechanisms (C-x  C-p, …),  but also  for our  completion plugin  which will,
" wrongly, think that the method has failed, and try the next one.
"
" Warning:
" So, make sure that you don't have 'noinsert' without 'menuone' in 'cot':
"
"     * +noinsert -menuone    ✘ ALL completion mechanisms broken when there's only 1 candidate
"     * -noinsert -menuone    ✘ vim-completion broken            "
"     * +noinsert +menuone    ✔
"     * -noinsert +menuone    ✔

" noinsert {{{3
"
" We remove 'noinsert' for 3 reasons:
"
"     - it breaks the repetition of C-x C-p
"
"       The  first invocation  works, but  the  consecutive ones  don't work  as
"       expected.  Indeed, we  have to hit enter to insert  a candidate from the
"       menu.  This CR breaks the chaining of C-x C-p.
"
"     - if we remove 'menuone', it  would break all completion mechanisms when
"       there's only 1 candidate
"
"     - it's annoying while in auto-completion mode
"
"       vim-completion already makes sure that  'noinsert' is not in 'cot' while
"       in auto mode, but still …
set cot-=noinsert

" noselect {{{3
"
" Do NOT  add 'noselect', because we  use a completion system  which would break
" the undo sequence when 'noselect' is in  'cot'.  It means that some text would
" be lost when we use the dot command to repeat a completion.
set cot-=noselect

" preview {{{3
"
" When we  hit `C-x C-g` by  accident, the unicode.vim plugin  opens the preview
" window (digraph completion), and we have to close it manually.  It's annoying.
"
" If one day, we  need to add 'preview' in 'cot' again, we  could get around the
" unicode.vim  plugin issue  with an  autocmd  which closes  the preview  window
" automatically each time we complete a text:
"
"         au CompleteDone * if pumvisible() ==# 0 | pclose | endif
set cot-=preview

" infercase {{{2
"
" Add some intelligence regarding the case of a text which is completed.
"
" For example, suppose we have the word 'WeirdCaseWord' in a buffer.
" We type:    weirdc    … and press Tab to complete,
"                         with `noinfercase`, we get `WeirdCaseWord`;
"                         with `infercase`  , we get `weirdcaseword`.
"
" Commented because I find it annoying at the moment.
" Besides,  it's a  buffer-local option,  so it  should be  set from  a filetype
" plugin.
"
"         set infercase
