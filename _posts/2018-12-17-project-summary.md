---
title: 近半月项目总结
date: 2018/12/17 11:23:01
tags:
- java
- arcsoft
- javaCV
categories: java
cover: https://gitee.com/oneww/onew_image/raw/master/project_summary_cover.jpg
author: 
  nick: onew
  link: https://onew.me
subtitle: 忙活了大半个月,新技术没学到,倒是踩了很多零零散散的坑.故此汇总记录一下.
---



# 一、前言

这段时间公司里的任务要用到虹软的人脸识别,以及openCV获取onvif的视频流.由于没怎么接触过这两个东西.于是踩了不少的坑.特别是openCV的坑.太致命了,来不来就crash jvm,头大.

由于经常crash jvm 并没找到原因,退而求其次的方案是加上一个看门狗,当jvm crash 的时候,自动拉起程序.哈哈,是不是个小机灵鬼??但在windows上的这个看门狗,也让我踩了session隔离的坑.也头大.



# 二、挖坑与填坑



## 虹软的挖与填

1. 坑: 虹软1.0的版本在做人脸识别的时候不能多线程并发识别.
2. 填: 通过线程池,并且集成线程池对象,让每个线程都持有一个虹软的engine,达到多线程识别的目的
3. 坑: 线程池使用forkjoin的方式,会出现内存泄露的问题
4. 填: 由于forkjoin创建了线程,并不长期的复用,结束任务之后就会被销毁.如果每个线程对象持有一个虹软的engine,会导致线程销毁的时候engine并没有被释放掉,而且频繁创建engine和销毁engine也是一种开销,所以解决方案是,池化虹软的engine对象,自定义threadFactory,控制每个线程独享一个engine.

## openCV的挖与填

1. 坑: openCV 使用rtsp时,使用UDP方式,延迟特别大
2. 填: 使用TCP方式,在option中加入`grabber.setOption("rtsp_transport","tcp")`
3. 坑: 截取的图与虹软识别的图不是同一张图
4. 填: 由于openCV获取的是frame对象,需要使用`Java2DFrameConvert`对象来转换为`BufferedImage`.问题就出在这里,如果不是每次转换都是一个新的`Java2DFrameConvert`对象,那么转换出来的图片就会在一次转换的时候发生改变.简单的说就是一个`Java2DFrameConvert`对应的一个`BufferedImage`对象,并且这个对象是共享的,不管发生多少次的convert都不会变,变的只是图片的数据,.解决办法,使用图片的时候使用本次convert的copy版本.防止被下一次convert改变.
5. 坑: 开始网络情况很好,后面网络很差,使用`grabber.grab()`方法会被阻塞2秒,甚至更长.
6. 填: 查了一些资料,解决办法是,[参见GITHUB](https://github.com/bytedeco/javacv/blob/master/samples/FFmpegStreamingTimeout.java).

## windows看门狗的挖与填

1. 坑: session 0 隔离之后无法使用`openFileMapping`进行内存共享.
2. 填: 首先共享内存名加前缀`Global\\`,并使用`DACL`,详情见[Stack Overflow](https://stackoverflow.com/questions/898683/how-to-share-memory-between-services-and-user-processes)



# 三、总结

总会遇到一些自己解决不了的问题,但现在是个好时代,通过google 你就可以找到答案.正如鸟哥说的一样,在QQ群里问问题是极其低效的.
