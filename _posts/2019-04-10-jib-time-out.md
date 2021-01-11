---
title: 使用jib打包maven错误
date: 2019/4/10 9:36:22
comments: true
tags: 
- java
- jib
- docker
categories: java
cover: https://gitee.com/oneww/onew_image/raw/master/java-jib-timezone-cover.png
author: 
  nick: onew
  link: https://onew.me
subtitle: 之前使用jib打包的时候还好好,后面经常莫名其妙的遇到打包失败的问题
---



# 一、问题分析

![images](https://gitee.com/oneww/onew_image/raw/master/jib_maven_info.png)

从上面报错的信息来看,看不出啥问题,我们在maven命令后面加上-x参数看看具体的问题

![images](https://gitee.com/oneww/onew_image/raw/master/jib_maven_error.png)

看到上面的信息是连接某个地址然后超时了.emmmm,会不会是被墙了???在maven上加上代理试试看



# 二、maven配置http代理

```xml
<proxies>
   <proxy>
      <id>example-proxy</id>
      <active>true</active>
      <protocol>http</protocol>
      <host>proxy.example.com</host>
      <port>8080</port>
      <username>proxyuser</username>
      <password>somepassword</password>
      <nonProxyHosts>www.google.com|*.example.com</nonProxyHosts>
    </proxy>
  </proxies>
```

按照上面的配置在setting.xml配置一下,代理就生效了.

在试一试打包

![images](https://gitee.com/oneww/onew_image/raw/master/jib_maven_success.png)

👌,打包成功.
