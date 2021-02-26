---
title: 使用fastjson打印日志的坑
date: 2018/08/08 9:20:25
tags:
- fastjson
- springmvc
- java
categories: java
cover: https://gitee.com/oneww/onew_image/raw/master/fastjson_springmvc_cover.jpg
author: 
  nick: onew
  link: https://onew.me
subtitle: 在springmvc中使用aop打印日志,莫名其妙的遇到一个fastjson的序列化异常,在此记录下来,以免下次遇到.
---



# 一、前言

项目打印日志是使用AOP实现的,把controller方法上的参数和返回值全部使用fastjson转换为json字符串打印出来,方便观察方法调用情况.最近同事遇到了一个在打印日志的时候,fastjson 序列化的异常,这个异常不影响业务逻辑,作为一个有强迫症的人,始终是觉得有问题的,于是跟着错误信息就找了下去.



# 二、症状

看看异常信息吧!

![1CfMpX](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/1CfMpX.jpg)

从异常的信息可以看出,在fastjson把对象转json字符串的时候遇到了问题,貌似从这个图片中看不出啥问题,该图片下面还有一段异常信息,如下:

```
java.lang.IllegalStateException: It is illegal to call this method if the current request is not in asynchronous mode (i.e. isAsyncStarted() returns false)
at org.apache.catalina.connector.Request.getAsyncContext(Request.java:1740)
at org.apache.catalina.connector.RequestFacade.getAsyncContext(RequestFacade.java:1047)
at com.alibaba.fastjson.serializer.ASMSerializer_1_RequestFacade.write(Unknown Source)
at com.alibaba.fastjson.serializer.JSONSerializer.write(JSONSerializer.java:280)
at com.alibaba.fastjson.JSON.toJSONString(JSON.java:673)
at com.alibaba.fastjson.JSON.toJSONString(JSON.java:611)
at com.alibaba.fastjson.JSON.toJSONString(JSON.java:576)
at com.me.Aspect.LoggerAspect.After(LoggerAspect.java:36)
at sun.reflect.NativeMethodAccessorImpl.invoke0(Native Method)
at sun.reflect.NativeMethodAccessorImpl.invoke(NativeMethodAccessorImpl.java:62)
at sun.reflect.DelegatingMethodAccessorImpl.invoke(DelegatingMethodAccessorImpl.java:43)
at java.lang.reflect.Method.invoke(Method.java:498)
at org.springframework.aop.aspectj.AbstractAspectJAdvice.invokeAdviceMethodWithGivenArgs(AbstractAspectJAdvice.java:620)
```



# 三、分析

​	上面这段信息可以看出,调用getAsyncContext方法出现了问题.表示当前这个request对象不是异步模式的,所以不能调用`getAsyncContext`这个方法.这个request的异步模式,是servlet3中的一个新特性,可以使用注解或者配置xml的方式进行开启,一般用于异步请求,这个request的异步模式的使用场景,就不多论述了.回到问题中来,fastjson序列化出错,出错的原因是fastjson调用了`getAsyncContext`方法,由于request不是异步模式,所以报错了,那么结果就是fastjson序列化出错了.

​		再看一下异常信息,按照打印的栈信息来看,是`RequestFacade`对象中的`getAsyncContext`方法被调用了,但是工程里面并没用用到`RequestFacade`对象呀,查看`RequestFacade`类的源码过后发现`RequestFacade`其实是`HttpServletRequest`的一个具体实现.那么问题就定位到了,fastjson把`HttpServletRequest`序列化了,只要把方法上的`HttpServletRequest` 参数去掉就可以了.

![MZ7BAI](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/MZ7BAI.jpg)



# 四、总结

有时候问题很简单,可能只是你没遇到过而已,多做记录,积累经验!

