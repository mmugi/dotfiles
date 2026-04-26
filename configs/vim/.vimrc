" packages
"   package manager: vim-jetpack (https://github.com/tani/vim-jetpack)
"   インストール後に JetpackSync を実行
let s:jetpackfile = expand('$HOME') . '/.vim/pack/jetpack/opt/vim-jetpack/plugin/jetpack.vim'
if filereadable(s:jetpackfile)
  packadd vim-jetpack
  call jetpack#begin()
    Jetpack 'tani/vim-jetpack', { 'opt': 1 } " bootstrap
    Jetpack 'wadackel/vim-dogrun', { 'as': 'dogrun' }
    Jetpack 'iamcco/markdown-preview.nvim', { 'do': { -> mkdp#util#install() }, 'for': ['markdown', 'vim-plug']}
  call jetpack#end()
endif

" generals
set clipboard=unnamed
set incsearch
set mouse=a
set wildmenu
set nowrapscan

" tab & space
set autoindent
set expandtab
set shiftwidth=2
set softtabstop=0
set tabstop=4

" keymaps
let mapleader = "\<space>"
nnoremap <silent> <leader>h :set hlsearch!<cr>
nnoremap <silent> <leader>i :<cr>
nnoremap <silent> <leader>j :bprev<cr>
nnoremap <silent> <leader>k :bnext<cr>
nnoremap <silent> <leader>l :ls<cr>
nnoremap <silent> <leader>m
  \ :exec &mouse!="" ? "set mouse=" : "set mouse=a"<cr>
  \ :echo 'mouse:'.(&mouse!='' ? 'enabled' : 'disabled')<cr>
nnoremap <silent> <leader>n :set number!<cr>:set cursorcolumn!<cr>
nnoremap <silent> <leader>t :tabnew<cr>
nnoremap <silent> <leader><tab> :tabnext<cr>
nnoremap <silent> <leader><s-tab> :tabprevious<cr>

nnoremap <silent> <esc><esc> :nohlsearc<cr>

nnoremap c "_c
nnoremap C "_C
nnoremap s "_s
nnoremap S "_S
nnoremap x "_x
nnoremap X "_X

" appearance
set background=dark
set cursorline
"set cursorcolumn
set hlsearch
"set number
set statusline=\ %F\ %m%r%h%w%=%{&fileencoding}\ \|\ ^%l>%c\ \|\ %p%%\ 
set list
set laststatus=2
set listchars=tab:>-,trail:-,extends:»,precedes:«,nbsp:%
syntax enable
highlight SpecialKey ctermbg=red ctermfg=black
highlight EndOfBuffer ctermbg=none
highlight LineNr ctermbg=none
highlight CursorLineNr ctermbg=none cterm=underline
highlight StatusLine ctermbg=63 ctermfg=white cterm=none
highlight CursorLine ctermbg=none cterm=underline
highlight Normal ctermbg=none
highlight TabLine ctermbg=white ctermfg=black cterm=none
highlight TabLineSel ctermbg=63 ctermfg=white cterm=bold
highlight TabLineFill ctermbg=none cterm=none
