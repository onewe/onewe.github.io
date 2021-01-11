---
title:  spring的那点事-yml环境变量随笔
date: 2018/3/13 11:25:25
comments: true
tags: spring
categories: java
cover: http://upload-images.jianshu.io/upload_images/8958298-a8eea1592699dd38..jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240
author: 
  nick: onew
  link: https://onew.me
subtitle: 原来还有这个小技巧.原谅我没在官网看到相关文档.
---
# 前言
> 前几天遇到一个需求,那就是mq队列的名称要跟本机的ip地址相关,由于用的是spring的stream模块来进行连接mq的,所以不能通过代码来指定队列的名称(只是我不知道怎么通过代码指定而已...逃),这可把我急坏了,因为队列名称是通过yml配置文件来的,于是我就想能不能再配置文件上面做点文章.

# 查资料
通过查询spring的yml相关资料,找到了生成随机数和uuid的办法(虽然之前我都知道了,无奈),显然是不符合我们需求的,在看spring官方文档的过程中,发现yml是可以读取环境变量的.这感觉不错,但是服务器上面有关于本机ip地址的环境变量吗??有没有我是不知道的.于是产生了手动设置环境变量的想法.

# 实现思路
只要在spring读取配置文件之前,把环境变量设置好就可以了.

# 实现思路
代码如下:
```java
public static void main(String[] args) {
	    //获取本地ip地址
        InetAddress address = getAddress();
        if (address == null) {
            //设置环境变量
            System.setProperty("local.ip","127.0.0.1");
        }else{
            //设置环境变量
            System.setProperty("local.ip",address.getHostAddress());
        }

        SpringApplication.run(StreamApplication.class, args);
	}
//获取本机ip地址	
private static InetAddress getAddress() {
        try {
            for (Enumeration<NetworkInterface> interfaces = NetworkInterface.getNetworkInterfaces(); interfaces.hasMoreElements();) {
                NetworkInterface networkInterface = interfaces.nextElement();
                if (networkInterface.isLoopback() || networkInterface.isVirtual() || !networkInterface.isUp()) {
                    continue;
                }
                Enumeration<InetAddress> addresses = networkInterface.getInetAddresses();
                if (addresses.hasMoreElements()) {
                    return addresses.nextElement();
                }
            }
        } catch (SocketException e) {
            e.printStackTrace();
        }
        return null;
    }	
	
```
yml配置如下
```yml
spring:
  application:
    name: zzwtec-stream
  cloud:
    stream:
      bindings:
        log_data_channel:
          destination: mq_sys_log_data
          contentType: application/json
          group: sysLogData
        log_status_channel:
          destination: mq_sys_log_data
          contentType: application/json
          group: ${local.ip} #获取名称为local.ip的环境变量
        data_into_redis_channel:
          destination: mq_stream_data
          contentType: application/json
          group: streamIntoRedis
        data_into_database_channel:
          destination: mq_stream_data
          contentType: application/json
          group: streamIntoDatabase

```

# 总结
通过以上的方式yml就可以获取本地ip地址了,哎,还是对spring这个框架不太熟悉呀,之前我居然不知道还可以读取环境变量.emmmmmmm还要多学学,不然跟不上历史的进程.
