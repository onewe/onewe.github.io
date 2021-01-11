---
title: windows解决logback中文乱码,以及高亮问题
date: 2018/9/17 23:10:34
comments: true
tags: 
- java
- logback
categories: logback
cover: https://gitee.com/oneww/onew_image/raw/master/logback_win_cover.png
author: 
  nick: onew
  link: https://onew.me
subtitle: 使用logback记录日志,奈何用cmd运行中文乱码,没有颜色高亮,在此记录解决办法!
---



# 前言

近日在windows上开发一款小工具,为了方便排查问题,特地的加入了logback进行记录日志,奈何在cmd中运行的时候中文就乱码了,并且也没有颜色高亮.下文就是我的解决办法.



# 一、中文乱码

面对中文乱码这个问题,首先想到的是改编码集,这里就分为两个端了.可以改cmd的编码集,也可以改java的编码集.一上最方便的是改cmd的编码,只需要在命令执行之前加上一句`chcp 65001`就可以了.但是这种方式感觉不太自然,于是就跑去改了logback的编码,logback修改编码也很简单.配置如下:

```xml
<appender name="CONSOLE" class="ch.qos.logback.core.ConsoleAppender">
        <encoder>
            <pattern>${CONSOLE_LOG_PATTERN}</pattern>
            <!--填写GBK即可-->
            <charset>GBK</charset>
        </encoder>
    </appender>
```



# 二、无高亮

虽然乱码解决了,但看着黑乎乎的窗口还是有点烦呀.google了一下,发现没有颜色的根本原因是cmd不支持ANSI escape code,但mac和linux是天生支持的,所以mac和linux能够正常显示高亮,而win不行.这里有了两个解决办法,第一是,下载一个支持ANSI的终端来替代cmd,但是这种太牵强了;第二种使用logback的官方解决方案即可,配置如下:

```xml
<appender name="CONSOLE" class="ch.qos.logback.core.ConsoleAppender">
    <!--withJansi 参数改为true-->
    <withJansi>true</withJansi>
    <encoder>
        <pattern>${CONSOLE_LOG_PATTERN}</pattern>
        <charset>GBK</charset>
    </encoder>
</appender>
```

只加这个参数是不行的,还要导入一个jar包pom 如下:

```xml
<dependency>
    <groupId>org.fusesource.jansi</groupId>
    <artifactId>jansi</artifactId>
    <version>1.17.1</version>
</dependency>
```



# 三、总结

内事不决问百度,外事不决问谷歌.
