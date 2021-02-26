---
title: jenkins部署hexo找不到hexo命令问题
date: 2018/5/10 12:16:25
tags:
- jenkins
- hexo
categories: jenkins
cover: https://gitee.com/oneww/onew_image/raw/master/hexo_cover.jpg
author: 
  nick: onew
  link: https://onew.me
subtitle: 算的上jenkins集成的小坑的吧
---



# 一、前言

在弄jenkins 自动集成的时候,部署hexo提示找不到hexo这个命令`hexo: command not found`,当时就懵逼了.上服务器看了一下环境变量,貌似是有的.鼓捣了半天想出个比较弱鸡的办法.希望能给广大的网友一点帮助,虽然有点弱鸡.



# 二、解决办法

解决办法很简单,把hexo命令链接到/usr/bin目录下面去,如果提示找不到node命令,同样的也可以这样做.

```shell
ln -s /root/.nvm/versions/node/v10.0.0/bin/hexo /usr/bin/hexo
ln -s /root/.nvm/versions/node/v10.0.0/bin/node /usr/bin/node
```

ok,虽然鸡肋,但还是把问题解决
