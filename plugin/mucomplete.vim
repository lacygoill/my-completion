imap <expr> <silent> <plug>(MUcompleteCycFwd) pumvisible()?mucomplete#cycle_or_select( 1):"\<plug>(MUcompleteFwdKey)"
imap <expr> <silent> <plug>(MUcompleteCycBwd) pumvisible()?mucomplete#cycle_or_select(-1):"\<plug>(MUcompleteBwdKey)"
imap <expr> <silent> <plug>(MUcompleteNxt)    mucomplete#verify_completion()
imap <expr> <silent> <plug>(MUcompleteAuto)   mucomplete#complete(1)
imap <expr> <silent> <plug>(MUcompleteFwd)    mucomplete#tab_complete( 1)
imap <expr> <silent> <plug>(MUcompleteBwd)    mucomplete#tab_complete(-1)
ino         <silent> <plug>(MUcompleteTab)    <tab>
ino         <silent> <plug>(MUcompleteCtd)    <c-d>

imap              <tab>                    <plug>(MUcompleteFwd)
imap              <s-tab>                  <plug>(MUcompleteBwd)
ino      <silent> <plug>(MUcompleteFwdKey) <c-j>
imap              <c-j>                    <plug>(MUcompleteCycFwd)
ino      <silent> <plug>(MUcompleteBwdKey) <c-k>
imap              <c-k>                    <plug>(MUcompleteCycBwd)

com! -nargs=0 MUcompleteAutoOn     call mucomplete#enable_auto()
com! -nargs=0 MUcompleteAutoOff    call mucomplete#disable_auto()
com! -nargs=0 MUcompleteAutoToggle call mucomplete#toggle_auto()
