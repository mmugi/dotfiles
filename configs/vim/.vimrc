" :options

" 24 multi-byte characters
set encoding=utf-8
scriptencoding utf-8

" 2 moving around, searching and patterns
set incsearch
set nowrapscan
set ignorecase

" 4 displaying text
set list
set listchars=tab:>-,trail:-,extends:»,precedes:«,nbsp:%
silent! set fillchars=vert:│
set number

" 5 syntax, highlighting and spelling
filetype plugin indent on
syntax enable
set background=dark
set hlsearch
set cursorcolumn
set cursorline
silent! colorscheme quiet
highlight Normal ctermbg=NONE

" 6 multiple windows
set laststatus=2
set statusline=\ %F\ %m%r%h%w%=%{&fileencoding.'\ '}
set hidden
set splitbelow
set splitright

" 9 using the mouse
set mouse=a

" 11 messages and info
set showcmd
set noruler
set belloff=all

" 12 selecting text
set clipboard=unnamed

" 13 editing text
set backspace=indent,eol,start
set nrformats=bin,hex

" 14 tabs and indenting
set tabstop=4
set shiftwidth=2
set smarttab
set softtabstop=0
set expandtab
set autoindent

" 17 mapping
set ttimeout ttimeoutlen=50

" 20 command line editing
set wildmenu
silent! set wildmode=longest,full:noselect
silent! set wildoptions=pum,fuzzy
set cmdwinheight=15

" highlight the cursor only in the current window
augroup vimrc_cursor
  autocmd!
  autocmd WinLeave * setlocal nocursorline nocursorcolumn
  autocmd WinEnter * setlocal cursorline cursorcolumn
augroup END

" highlight trailing whitespace in normal file buffers
highlight ErrTrailingWhitespace ctermfg=7 ctermbg=1
augroup vimrc_trailing_whitespace
  autocmd!
  autocmd BufEnter,BufWinEnter,WinEnter *
    \ execute &buftype == '' ? 'match ErrTrailingWhitespace /\s\+$/' : 'match none'
augroup END

" keymaps
let mapleader = "\<space>"
let maplocalleader = "\\"

nnoremap c "_c
nnoremap C "_C
nnoremap s "_s
nnoremap S "_S
nnoremap x "_x
nnoremap X "_X
xnoremap c "_c
xnoremap C "_C
xnoremap s "_s
xnoremap S "_S
xnoremap x "_x
xnoremap X "_X
xnoremap p "_dP

nnoremap <silent> <leader>n :tabnext<cr>
nnoremap <silent> <leader>p :tabprevious<cr>
nnoremap <silent> <leader><leader> :buffers<cr>
nnoremap <silent> <leader>m
  \ :exec &mouse!="" ? "set mouse=" : "set mouse=a"<cr>
  \ :echo 'mouse:'.(&mouse!='' ? 'enabled' : 'disabled')<cr>
nnoremap <silent> <esc><esc> :nohlsearch<cr>

nnoremap <silent> <c-h> :wincmd h<cr>
nnoremap <silent> <c-j> :wincmd j<cr>
nnoremap <silent> <c-k> :wincmd k<cr>
nnoremap <silent> <c-l> :wincmd l<cr>

cnoremap <c-w> <c-f>
cnoremap <c-b> <left>
cnoremap <c-f> <right>
cnoremap <c-a> <home>
cnoremap <c-d> <del>
cnoremap <c-k> <c-\>estrpart(getcmdline(), 0, getcmdpos() - 1)<cr>
