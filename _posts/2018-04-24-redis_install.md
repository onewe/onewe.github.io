---
title: redis安装笔记
date: 2018/4/24 21:55:34
comments: true
tags: redis-install
categories: redis
cover: https://gitee.com/oneww/onew_image/raw/master/redis_install.png
author: 
  nick: onew
  link: https://onew.me
subtitle: redis,一个强大的非关系型数据库,高速缓存,天下第一!
---



# redis 安装笔记

## 一、前言

改代码的时候需要用redis的环境来验证代码正确性,很遗憾家中没有redis环境,只有自己安装一个redis了.此文作为安装笔记,以免后面踩踩过的.



## 二、安装与编译

官方的文档上面是自己编译安装.首先得要下载redis的源码,进行编译.

1. 下载源码

   ```
   wget http://download.redis.io/releases/redis-4.0.9.tar.gz
   ```

2. 解压

   ```
   tar xzf redis-4.0.9.tar.gz
   ```

3. 编译

   ```
   //编译前先安装依赖gc 和 gc++
   yum install gcc gcc-c++ -y
   cd redis-4.0.9 && make MALLOC=libc
   ```

4. Test

   ```
   //测试之前安装tcl
   yum install tcl -y
   make test
   ```

5. 安装

   ```
   make install
   ```

## 三、使用redis

1. 修改redis 配置文件为后台启动

   ```
   //在redis 解压包中有个redis.conf文件,这个配置文件是官方的配置示例文件
   //找到redis.conf中的daemonize  设置为yes
   ```

2. 启动redis-server并加载配置文件

   ```
   redis-server /root/redis-4.0.9/redis.conf
   ```

3. 使用redis-cli 连接redis-server

   ```
   redis-cli //默认连接本地默认端口的redis-server
   ```

## 四、总结

redis安装还是听简单的,只要安装官方的文档来就不会出错!
