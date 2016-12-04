imap <expr> <silent> <plug>(MUcompleteCycFwd) pumvisible()?mucomplete#cycle( 1):"\<plug>(MUcompleteFwdKey)"
imap <expr> <silent> <plug>(MUcompleteCycBwd) pumvisible()?mucomplete#cycle(-1):"\<plug>(MUcompleteBwdKey)"
imap <expr> <silent> <plug>(MUcompleteNxt)    mucomplete#verify_completion()
imap <expr> <silent> <plug>(MUcompleteAuto)   mucomplete#complete(1)

ino      <silent> <plug>(MUcompleteFwdKey) <c-j>
imap              <c-j>                    <plug>(MUcompleteCycFwd)
ino      <silent> <plug>(MUcompleteBwdKey) <c-k>
imap              <c-k>                    <plug>(MUcompleteCycBwd)

" initiate manual completion, when hitting Tab or S-Tab
imap <expr> <silent> <Tab>   mucomplete#tab_complete(1)
imap <expr> <silent> <S-Tab> mucomplete#tab_complete(-1)

" typed/returned by mucomplete#complete()
ino         <silent> <plug>(MUcompleteTab)    <Tab>
ino         <silent> <plug>(MUcompleteCtd)    <c-d>
