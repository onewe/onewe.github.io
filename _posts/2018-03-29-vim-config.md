---
title: vim个性化配置
date: 2018/3/29 16:39:25
tags: vim
categories: mac
cover: https://gitee.com/oneww/onew_image/raw/master/mac_vim_cover.png
author: 
  nick: onew
  link: https://onew.me
subtitle: vim,装逼必备,打造酷炫的vim,可谓是装逼的核心思想.
---
# vim个性配置
> 使用vim是否是逼格满满呢?? 如果在个性话一点是不是更有逼格呢?

## 安装macVim
> 之前折腾了很久vim后来还是放弃治疗装上了macVim,别问我为什么.

- 下载并按照
    使用brew安装可谓是非常的简单,这里推荐覆盖安装的方式`brew install macvim --with-override-system-vim`
- 简单个性配置
    安装好以后发现,vim没有颜色,感觉不好看,这里就默认配置一下,编辑用户目录下面的.vimrc文件,没有则创建一个.
    ```Shell
        #设置代码折叠根据语义折叠
        set foldmethod=syntax
        #设置vim开启时不开启折叠
        set nofoldenable
        
        #共享剪贴板
        set clipboard+=unnamed
        
        #显示行号
        set number 
        
        #设置字体及其大小
        set guifont=Source_Code_Pro:h15
        
        #字符编码相关设置
        set termencoding=utf-8
        set encoding=utf-8
        set fileencodings=utf8,ucs-bom,gbk,cp936,gb2312,gb18030
        
        #设置命令行高度
        set cmdheight=2
        
        #在编辑过程中，在右下角显示光标位置的状态行
        set ruler
        
        #显示命令
        set showcmd
        
        #autowrite
        set autowrite
        set autowriteall
        
        #autoread
        set autoread
        
        
        set confirm
        
        #光标移动到buffer的顶部和底部时保持3行距离
        set scrolloff=3
        
        set wildmenu
        set history=50
        
        #在Visual模式时，按Ctrl+c复制选择的内容
        vmap <C-c> "+y
        
        #字符间插入的像素行数目
        set linespace=0
        
        #键入闭括号时显示它与前面的那个开括号匹配
        set showmatch
        set matchtime=2
        
        #语法高亮
        syntax on
        syntax enable
        
        #用浅色高亮当前行
        autocmd InsertLeave * se nocul
        autocmd InsertEnter * se cul
        
        #search
        set hlsearch
        set incsearch
        
        #智能对齐
        set smartindent
        set autoindent
        
        #bakcspace
        set backspace=eol,start,indent
        
        #backup 不进行备份
        set nobackup
        set nowb
        set noswapfile
        
        #tab
        set tabstop=4
        set softtabstop=4
        set shiftwidth=4
        set noexpandtab
      
    ```
## 安装插件
- 插件管理插件Vundle
    - 使用命令`git clone https://github.com/gmarik/Vundle.vim.git ~/.vim/bundle/Vundle.vim`  
    - 配置vim使之生效
    ```shell
      filetype off
      set rtp+=~/.vim/bundle/Vundle.vim
      call vundle#begin()
      Plugin 'VundleVim/Vundle.vim'
      call vundle#end()
      filetype plugin indent on
    ```
- 安装powerLine插件
    - 使用vundle安装,添加配置如下
    ```shell
      filetype off
      set rtp+=~/.vim/bundle/Vundle.vim
      call vundle#begin()
      Plugin 'VundleVim/Vundle.vim'
      Plugin 'Lokaltog/vim-powerline'# 你需要安装的插件
      call vundle#end()
      filetype plugin indent on
    ```
    - 进入vim中先按:,在输入PluginInstall 直到提升done就算是安装成功
    - 配置powerLine使之生效
    ```Shell
        #powerLine 配置
        set laststatus=2
        set t_Co=256
        let g:Powerline_symbols= 'unicode'
    ```
ok,vim 美美哒,当然你还可以安装更多的插件来丰富你的vim.
