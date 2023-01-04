"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"let g:python3_host_prog = expand('/nfs/site/home/phuongn2/local/spack/opt/spack/linux-ubuntu22.04-skylake_avx512/gcc-11.2.0/python-3.9.12-anzeaau5iznpgfdhh7rwojqrregp2k4m/bin/python3')

" Basic Settings
set nocompatible            " disable compatibility to old-time vi
set showmatch               " show matching brackets.
set ignorecase              " case insensitive matching
set mouse=v                 " middle-click paste with mouse
set hlsearch                " highlight search results
set autoindent              " indent a new line the same amount as the line just typed
set number                  " add line numbers
set wildmode=longest,list   " get bash-like tab completions
"set cc=80                   " set an 80 column border for good coding style
filetype plugin indent on   " allows auto-indenting depending on file type
set tabstop=4               " number of columns occupied by a tab character
set expandtab               " converts tabs to white space
set smarttab
set shiftwidth=4            " width for autoindents
set softtabstop=4           " see multiple spaces as tabstops so <BS> does the right thing
set backspace=indent,eol,start
"set paste
set visualbell
set t_vb=

"filetype off                  " required

let mapleader=","

" Return to last edit position when opening files
au BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g'\"" | endif

"remap F5 to delete trailing whitespace
:nnoremap <silent> <F5> :let _s=@/<Bar>:%s/\s\+$//e<Bar>:let @/=_s<Bar>:nohl<CR>

" Flagging Unnecessary Whitespace
au BufRead,BufNewFile *.py,*.pyw,*.c,*.h,*.cpp,*.f90 match BadWhitespace /\s\+$/

:highlight BadWhitespace ctermfg=16 ctermbg=253 guifg=#000000 guibg=#F8F8F0

" Enable folding
set foldmethod=indent
set foldlevel=99

" Enable folding with the spacebar
nnoremap <space> za

"Plugin 'tmhedberg/SimpylFold'
"let g:SimpylFold_docstring_preview=1

" UTF-8 Support
set encoding=utf-8

if has('python3')
endif

map <Leader>e :call Spellchk_en()<cr>
:set spellfile=~/.vim/spell/empty.add

let g:spellchk_on = 0

function! Spellchk_en()
  if g:spellchk_on == 0
    :setlocal spell spelllang=en_us
    :set spellfile=~/.vim/spell/en.utf-8.add
    let g:spellchk_on = 1
  else
    :setlocal spell spelllang=
    :set spellfile=/.vim/spell/empty.add
    let g:spellchk_on = 0
  endif
endfunction

" Grammar check
map <Leader>g :call Grammarchk_en()<cr>

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

call plug#begin()            " required

Plug 'norcalli/nvim.lua'

" Different colorcheme
Plug 'EdenEast/nightfox.nvim'
Plug 'Mofiqul/dracula.nvim'
Plug 'kyazdani42/nvim-web-devicons' " Recommended (for coloured icons)
" Plug 'ryanoasis/vim-devicons' Icons without colours
Plug 'akinsho/bufferline.nvim', { 'tag': 'v2.*' }
Plug 'folke/tokyonight.nvim', { 'branch': 'main' }

Plug 'jonstoler/werewolf.vim'

"Bundle 'rhysd/vim-grammarous'
"let g:grammarchk_on = 0
"function! Grammarchk_en()
"  if g:grammarchk_on == 0
"    GrammarousCheck
"    let g:grammarchk_on =1
"  else
"    GrammarousReset
"    let g:grammarchk_on = 0
"  endif
"endfunction
"
"let g:grammarous#hooks = {}
"function! g:grammarous#hooks.on_check(errs) abort
"    nmap <buffer><C-n> <Plug>(grammarous-move-to-next-error)
"    nmap <buffer><C-p> <Plug>(grammarous-move-to-previous-error)
"endfunction
"
"function! g:grammarous#hooks.on_reset(errs) abort
"    nunmap <buffer><C-n>
"    nunmap <buffer><C-p>
"endfunction

"Syntax Checking/Highlighting
"Plug 'vim-syntastic/syntastic'
"Plug 'nvie/vim-flake8'
"let python_highlight_all=1
"syntax on

"Plug 'roxma/nvim-completion-manager'
"Plug 'SirVer/ultisnips'
"Plug 'honza/vim-snippets'

""""""""""""""""""""""""""""""
" File Browsing - NERDTree
Plug 'preservim/nerdtree'
Plug 'Xuyuanp/nerdtree-git-plugin' "Shows Git status flags for files and folders in NERDTree.
"Plug 'ryanoasis/vim-devicons' "Adds filetype-specific icons to NERDTree files and folders,
Plug 'tiagofumo/vim-nerdtree-syntax-highlight' "Adds syntax highlighting to NERDTree based on filetype.
"Plug 'scrooloose/nerdtree-project-plugin' "Saves and restores the state of the NERDTree between sessions.
"Plug 'PhilRunninger/nerdtree-buffer-ops' "1) Highlights open files in a different color. 2) Closes a buffer directly from NERDTree.
"Plug 'PhilRunninger/nerdtree-visual-selection' "Enables NERDTree to open, delete, move, or copy multiple Visually-selected files at once.
"
" Start NERDTree when Vim is started without file arguments.
autocmd StdinReadPre * let s:std_in=1
autocmd VimEnter * if argc() == 0 && !exists('s:std_in') | NERDTree | endif

" Start NERDTree when Vim starts with a directory argument.
autocmd StdinReadPre * let s:std_in=1
autocmd VimEnter * if argc() == 1 && isdirectory(argv()[0]) && !exists('s:std_in') |
    \ execute 'NERDTree' argv()[0] | wincmd p | enew | execute 'cd '.argv()[0] | endif

" Exit Vim if NERDTree is the only window remaining in the only tab.
autocmd BufEnter * if tabpagenr('$') == 1 && winnr('$') == 1 && exists('b:NERDTree') && b:NERDTree.isTabTree() | quit | endif

" Start NERDTree with Ctr-N
nnoremap <C-n> :NERDTree<CR>
"""""""""""""""""""""""""""""

" Super Searching
Plug 'kien/ctrlp.vim'

" Line Numbering
set nu
"set ruler

" Git Integration
Plug 'tpope/vim-fugitive'

" Powerline
"Plug 'Lokaltog/powerline', {'rtp': 'powerline/bindings/vim/'}

" System Clipboard
"set clipboard=unnamed

""" PYTHON
" PEP 8 indentation
au FileType python setlocal tabstop=4 softtabstop=4 shiftwidth=4 textwidth=79 expandtab fileformat=unix
au FileType python Plug 'vim-scripts/indentpython.vim'  " Auto-Indentation

""" C/C++
au FileType c,cpp,cc setlocal tabstop=2 softtabstop=2 shiftwidth=2 enc=utf-8 fenc=utf-8 termencoding=utf-8 t_Co=256 showmatch comments=sl:/*,mb:\ *,elx:\ */
au FileType c,cpp,cc let g:tagbar_autoclose=1
au FileType c,cpp,cc nnoremap <silent><F8> :TagbarToggle<CR>
au FileType c,cpp,cc Plug 'preservim/tagbar'

""" Fortran
"autocmd FileType fortran setlocal smarttab expandtab smartindent autoindent tabstop=2 shiftwidth=2 bs=2
au FileType fortran setlocal tabstop=2 shiftwidth=2 bs=2 incsearch      ignorecase smartcase
au FileType fortran let fotran_free_source=1
au FileType fortran let fortran_do_enddo=1
au FileType fortran let fortran_more_precise=1
au FileType fortran Plug 'rudrab/vimf90'

Plug 'Shougo/deoplete.nvim', { 'do': ':UpdateRemotePlugins' }
let g:deoplete#enable_at_startup = 1

""" Latex
au FileType tex Plug 'lervag/vimtex'

"""" Clang format
"" Add maktaba and codefmt to the runtimepath.
"" (The latter must be installed before it can be used.)
"Plug 'google/vim-maktaba'
"Plug 'google/vim-codefmt'
"" Also add Glaive, which is used to configure codefmt's maktaba flags. See
"" `:help :Glaive` for usage.
"Plug 'google/vim-glaive'
"augroup autoformat_settings
"  autocmd FileType bzl AutoFormatBuffer buildifier
"  autocmd FileType c,cpp,proto,javascript,arduino AutoFormatBuffer clang-format
"  autocmd FileType dart AutoFormatBuffer dartfmt
"  autocmd FileType go AutoFormatBuffer gofmt
"  autocmd FileType gn AutoFormatBuffer gn
"  autocmd FileType html,css,sass,scss,less,json AutoFormatBuffer js-beautify
"  autocmd FileType java AutoFormatBuffer google-java-format
"  autocmd FileType python AutoFormatBuffer yapf
"  " Alternative: autocmd FileType python AutoFormatBuffer autopep8
"  autocmd FileType rust AutoFormatBuffer rustfmt
"  autocmd FileType vue AutoFormatBuffer prettier
"  autocmd FileType swift AutoFormatBuffer swift-format
"augroup END

call plug#end()            " required

"""
"let g:werewolf_day_themes = ['morning']
"let g:werewolf_night_themes = ['desert']
colorscheme dayfox


