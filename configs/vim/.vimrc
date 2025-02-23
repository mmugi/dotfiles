" Generals "

set mouse=a
set clipboard=unnamed
set number
set cursorline
set cursorcolumn
set hlsearch
set incsearch
set listchars=tab:>.,trail:_,extends:»,precedes:«,nbsp:%
set list
set expandtab
set laststatus=2
set statusline=\ %F\ %m%r%h%w%=%{&fileencoding}\ \|\ ^%l>%c\ \|\ %p%%\ 
set wildmenu
" F12でmouse利用/行番号のオンオフ
" マウスでterminal側の選択コピー等を利用できるように
noremap <F12> <ESC>:set number!<CR>:exec &mouse!=""? "set mouse=" : "set mouse=a"<CR>

" xでyankしない
nnoremap x "_x
nnoremap X "_X


" Packages "
"   Package Manager: vim-jetpack (https://github.com/tani/vim-jetpack)
"   Install後にJetpackSyncを実行

let s:jetpackfile = $HOME .. '/.vim/pack/jetpack/opt/vim-jetpack/plugin/jetpack.vim'
if filereadable(s:jetpackfile)
    packadd vim-jetpack
    call jetpack#begin()
        Jetpack 'tani/vim-jetpack', { 'opt': 1 } " bootstrap
        Jetpack 'wadackel/vim-dogrun', { 'as': 'dogrun' }
        Jetpack 'iamcco/markdown-preview.nvim', { 'do': { -> mkdp#util#install() }, 'for': ['markdown', 'vim-plug']}
    call jetpack#end()
endif


" Theme "

syntax enable

" Default settings
highlight CursorLine cterm=underline ctermbg=none
highlight CursorLineNr cterm=underline ctermbg=none ctermfg=63
highlight EndOfBuffer ctermbg=none
highlight LineNr ctermbg=none ctermfg=63
highlight NonText ctermfg=63
highlight Normal ctermbg=none ctermfg=none
highlight Search ctermbg=220 ctermfg=black
highlight StatusLine cterm=none ctermbg=63 ctermfg=white

" Apply color scheme
if filereadable(s:jetpackfile)
    autocmd colorscheme dogrun highlight LineNr ctermfg=240
    colorscheme dogrun
endif

" Override settings
highlight SpecialKey ctermbg=red ctermfg=white
