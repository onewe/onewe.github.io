---
title: redis 配置supervisor
date: 2018/4/13 18:49:34
comments: true
tags: 
 -redis
 -redis supervisor
categories: redis
cover: https://gitee.com/oneww/onew_image/raw/master/redis_install.png
author: 
  nick: onew
  link: https://onew.me
subtitle: 记录一下redis与supervisor后台运行的坑
---

# 一、坑

redis安装还是挺简单的,按照官方的教程一步一步的来,基本上来说是没什么问题.至于后台运行,只需要在redis的配置文件中设置`daemonize yes`即可,但是