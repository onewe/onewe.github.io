---
title: 关于JDBC中的Mysql 6.x驱动所遇到的坑
date: 2018/8/27 22:55:34
comments: true
tags: 
- java
- jdbc
- jdbc driver 6.x
categories: java
cover: https://gitee.com/oneww/onew_image/raw/master/JDBC-MySql-Driver-Cover.png
author: 
  nick: onew
  link: https://onew.me
subtitle: JDBC 6.x的驱动还是有点区别的,记录一下下
---



## 一、起因 ##
最近看到maven仓库里面mysql的JDBC驱动都是6.x了,所以想更新一波,本以为使用方式跟以前是差不多的,没想到还是遇到了几个坑呀。所以写点东西权当记录.
## 二、区别 ##
首先的区别就是在JDBC连接的URL上面的区别,之前的写法是这样的

```
jdbc:mysql://127.0.0.1:30002/smssvr?useUnicode=true&characterEncoding=utf8
```
如果使用原的写法,你会发现启动项目的时候会报错,说是要添加什么时区。然后就变成这样的写法

```
jdbc:mysql://127.0.0.1:30002/smssvr?serverTimezone=UTC&useUnicode=true&characterEncoding=utf8
```

这里多了个serverTimezone的参数,我google了一些貌似这个是新版驱动必须要添加的参数
然而添加了这个参数还没完,这里的时区是UTC我们要改成我们自己的时区,不然就会出现大大的时差,8个小时吧。中国的时区为Asia/Chongqing,这里重庆也好上海也罢只要是中国的时区问题就不会太大。

在一个区别就是driverClass的区别,以前我们是这样写的

```
com.mysql.jdbc.Driver
```

启动项目的时候你会发现,在控制台,会提示你这个驱动已经过时了,所以这里要换成这样的写法

```
com.mysql.cj.jdbc.Driver
```



# 总结

遇到问题,别慌,先去百度看看,百度不了,还有google,总有人比你先遇到问题,所以总会有解决方案的.该吃吃该喝喝.
