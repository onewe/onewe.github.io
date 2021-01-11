---
title: 使用jib打包docker镜像时区问题
date: 2019/3/26 15:41:22
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
subtitle: 最近使用jib打包java应用,发现时区出现了问题,在此记录一下
---



# 一、前言

为了方便部署,不去倒腾开发环境,采用了docker的方式.在java这边就使用maven插件jib进行打包,虽然这样是方便很多,但使用的过程中也遇到各种的坑.



# 二、起因

在一次开发任务中,后端的时区有问题,比起北京时间少了8个小时.接到反馈,一般的思路是,先检查开发环境的时区, 看是否是UTC时区,检查过后发现,服务器时区正常,数据库时区正常.那么问题就定位到jdbc上,在开发机上测试,时区是正常的.那么问题又回到了服务器时区的问题,但检查了几遍都没发现时区的问题.于是问题定位到docker上.



# 三、解决

经过一番的试探,发现只要给jvm加上一个参数就可以完美解决,jib插件配置如下:

```xml
   <plugin>
     <groupId>com.google.cloud.tools</groupId>
     <artifactId>jib-maven-plugin</artifactId>
     <version>1.0.2</version>
     <configuration>
       <container>
         <jvmFlags>
           <jvmFlag>-Xms512m</jvmFlag>
           <jvmFlag>-Xmx1024m</jvmFlag>
           <jvmFlag>-Djava.awt.headless=true</jvmFlag>
           <jvmFlag>-Duser.timezone=PRC</jvmFlag>  <!-- 这里就是重点了 -->
         </jvmFlags>
         <ports>
           <port>8080</port>
         </ports>
         <useCurrentTimestamp>true</useCurrentTimestamp>
         <mainClass>com.b1809.base.Application</mainClass>
       </container>
       <from>
         <image>openjdk:8u181-jdk-stretch</image>
       </from>
       <to>
         <image>b1809:b-dev</image>
       </to>
       <allowInsecureRegistries>true</allowInsecureRegistries>
       <extraDirectory>${project.basedir}/src/main/jib</extraDirectory>
     </configuration>
</plugin>
```

