---
title: Mac OS X下编译Redis Desktop Manager(RDM)
key: 2018-03-29-mac-compile-RDM.md
date: 2018/3/29 16:39:25
tags:
- RDM
- Redis Desktop Manager
categories: mac
cover: https://gitee.com/oneww/onew_image/raw/master/redis-desktop-manager-cover.jpg
author: 
  nick: onew
  link: https://onew.me
subtitle: 虽然自己编译了,能支持官方还是支持一下的比较好.
---

# 前言

> rdm 算得上是一个比较好的redis图形化工具,但是最新的版本要自己编译才可以(除非你在官网上进行付费),通过brew安装的也只能安装0.8的版本.所有最新的版本需要我们自己编译.由于自己编译的时候遇到了不少的坑,所以在此记录一下. 最近看到有些小伙伴,编译不成功呀.重新写一下.

## 第一步,准备编译环境
- 下载源码  
  `git clone --recursive https://github.com/uglide/RedisDesktopManager.git -b 0.9 rdm && cd ./rdm`,这里的recursive参数是允许下载其他的依赖.

- 安装qt creator 和 qt (用来编译源码),如果不想用brew 安装可以下载安装包(这个安装包有点大估计要3个多G)进行安装,附上国内镜像的地址`http://download.qt.io/official_releases/qt/5.9/5.9.6/`,安装的时候一定要选上`Qt Charts`这个模块.

  下面是brew 安装的命令 
  `brew cask install qt-creator`

  `brew install qt`

## 第二步,修改info.plist
- `cd ./src && cp ./resources/Info.plist.sample ./resources/Info.plist`  plist里面的参数可以根据需求进行修改
- `./configure`

## 第三步,开始编译
- 打开qt-creator,导入RDM工程,构建配置选择release

  ![images](https://gitee.com/oneww/onew_image/raw/master/mac_rdm_build.png)

- 修改rdm.pro,注释掉debug相关的参数,以及crashreporter相关的配置(如果不注释掉的需要编单独crashreporter这个依赖,为了避免麻烦就先注释掉了.如果需要的话,可以参考另一篇文章!)

  ![images](https://gitee.com/oneww/onew_image/raw/master/mac_rdm_pro.png)

- 点击构建

- 编译后的文件在`rdm/bin/osx/release`目录下面,接下来只要把编译后的rdm.app复制到Application中去就可以了

- 如果需要打包成dmg格式需要使用 macdeployqt(这个程序在QT的bin目录下面) 进行打包.

- 后续考虑出一篇打包的博文

# 总结

开源不容易,如果有添加请支持一下官方.如果没条件还不想编译,我也提供编译好的dmg版本.

https://github.com/onewe/RedisDesktopManager-Mac/releases
