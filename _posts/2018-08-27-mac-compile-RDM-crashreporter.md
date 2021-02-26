---
title: Mac OS X下编译Redis Desktop Manager(RDM)的依赖crashreporter
date: 2018/8/27 10:25:25
tags:
- RDM crashreporter
- crashreporter
categories: mac
cover: https://gitee.com/oneww/onew_image/raw/master/redis-desktop-manager-cover.jpg
author: 
  nick: onew
  link: https://onew.me
subtitle: 在Redis Desktop Manager 提供的源码中crashreporter,并不是必须的,但有些同学想编译这个东西,那我就写边博客记录记录啦..
---



# 前言

> 在Redis Desktop Manager(RDM) 官网上已经不提供0.9.x版本之后的Mac dmg包了,官方给我们的选择是要么付费订阅,要么自己手动编译(有条件的同学可以付费支持一下,毕竟开源不容易!).在之前我写了一篇通过源码编译RDM的教程,但编译的时候是忽略掉crashreporter这个依赖的(感觉这个没啥太大用处),为了不上之前的坑,特地在写一篇编译crashreporter的教程.



## 第一步,下载crashreporter源码

- `git clone https://github.com/RedisDesktop/CrashReporter.git`



## 第二步,配置QT

- 选择release

- 配置QT编译参数,在额外参数里面加上`DESTDIR+=.`,构建目录随你心情了.

  ![LQXrg9](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/LQXrg9.jpg)

- 修改 `Sources\src\main.cpp`中的代码,因为有些变量没有定义,所以会导致编译不通过,需要手动定义一下变量

  ![WdBlhH](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/WdBlhH.jpg)在mian函数上添加以下代码:

  ```c
  /**
  * 这些变量的值,都可以瞎写!
  */
  static char * APP_NAME = "RDM_CARSH_REPORTER";
  static char * APP_VERSION = "0.9.5";
  static char * CRASH_SERVER_URL = "https://www.baidu.com";
  ```

- 点击构建,构建完成之后你就会在你的构建目录中看到一个,crashreporter的二进制文件,ok.完成了.



# 总结

在之前对QT熟悉的时候,老是编译不出来,各种报错,差点就要放弃了,还一度的以为官方是为了收费故意刁难我的.结果是自己对这个不熟.哈哈哈.摸熟了就好了(虽然我不是搞QT的,慢慢摸索还是能看点门道出来!).还是前言中的话,如果有条件的同学,请多多支持一下官方.另外,编译好的RDM dmg我已经放在[github](https://github.com/onewe/RedisDesktopManager-Mac)上了,不想编译的话可以下载来用用.想编译的同学可以参考我另一篇[Mac OS X下编译Redis Desktop Manager(RDM)](https://onew.me/2018/03/29/mac-compile-RDM/).
