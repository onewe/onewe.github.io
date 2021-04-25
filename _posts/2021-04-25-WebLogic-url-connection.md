---
title: WebLogic 第三弹,代码都去哪了,绕过https证书验证失效？
key: weblogic-url-connection-2021-01-19
date: 2021/03/22 17:01:25
tags:
- java
- Weblogic
- urlOpenConnection
categories: java
author:
  nick: onew
  link: https://onew.me
subtitle: 奇怪了,为什么代码未生效呢?是不是代码不见了？
---

# WebLogic 第三弹,代码都去哪了？



# 一、前言

​	在开发过程中,总能遇到奇奇怪怪的问题。这次这个问题比较好玩,故记录下来。整个事情是这样的，前段时间上线了一个新的需求，结果发现调用三方接口报错了。报错的信息是对方 `https` 的证书有问题，不能通过证书校验。

​	这个问题其实很好解决，让接口方检查一下证书就好了。奈何这里比较弱势，做了甲方却是乙方的地位。于是开发的同学就提出，可以绕过https的证书的校验，由于不是我负责的需求，我也不能插话不是。

​	很快啊，代码就改造完了(增加了跳过的代码)。我简单的贴一下代码。

![TpUADz](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/TpUADz.png)

​	乍一看没啥问题，开发环境里也运行的很好，测试环境里也运行的很好。嗯。冲吧，上线吧！

​	不幸的是，上线后，这块儿跳过的代码并没有生效，依旧的报错了。开发的小伙伴一看懵了，发来报错日志的图片来找我求助。

![3zBYfh](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/3zBYfh.jpg)

​	很想吐槽，为啥不截图给我，而且也该换手机了吧。就这图能看出啥？？正想骂人的时候，等等！我破案了。对，我知道为啥线上为啥不能跳过 `https` 证书校验了。



# 二、Spring中的http请求工具,RestTemplate。

​	相信很多小伙伴都用过这个工具，今天的主题是绕过 `https`  的证书验证。恰好就是用 `RestTemplate` 发送的请求。那就来抽丝剥茧的看看，`RestTemplate` 这个工具是怎么发送的请求。

​	先来看看是怎么发送 `GET` 请求的:

![ZysRbe](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/ZysRbe.png)

​	这个方法的核心逻辑是调用了 `execute` 方法。接着往下看。

![Qa5o7W](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/Qa5o7W.png)

​	这里的逻辑是，解析请求的 `url` 拼装为`URI` 对象。接着往下看

![截屏2021-04-25上午10.14.57](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/截屏2021-04-25 上午10.14.57.png)

​	这里有两个核心的逻辑，一个创建请求，一个是执行请求。这里就只看创建请求。

 - 创建请求

    - ![gbn5AK](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/gbn5AK.png)

      ​	这里使用了一个工厂进行创建，如果没有设置工厂的话，默认是 `SimpleClientHttpRequestFactory` 为了能跳过 `https` 证书校验，创建了一个工厂对象，并设置到了 restTemplate 里。主要是为了重写工厂对象中的 `prepareConnection` 方法。

      ​	 `prepareConnection` 能够在连接创建完毕之后进行预处理，这里的预处理就包括跳过 `https` 证书校验等.

    - ![nzPfGT](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/nzPfGT.png)

      ​	从 `createRequest` 方法可以看出，连接在使用前必须要进行预处理。

   - ![Bn31aj](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/Bn31aj.png)

     ​	打开连接这里就简单直白了，只是就是用 `jdk` 自带的方法创建的连接。既然都看到这里了，索性再看一下 `url` 是怎样创建连接的吧。

   - ![gyfFYK](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/gyfFYK.png)

     ​	？？就这？其实这里的一句话，还是要依赖前面的初始化，毕竟`handler` 一开始是为空，需要进行初始化。当创建 `URL` 被创建的时候，`handler` 就会在构造函数被初始化。

     ```java
     public URL(String protocol, String host, int port, String file,
                    URLStreamHandler handler) throws MalformedURLException {
     				// 省略很多无关的代码
       			// 当 handler 为空的时候，初始化一个 handler 并复制给当前对象
             if (handler == null &&
                 (handler = getURLStreamHandler(protocol)) == null) {
                 throw new MalformedURLException("unknown protocol: " + protocol);
             }
             this.handler = handler;
           
         }
     ```

     `getURLStreamHandler` 这个方法才是核心。

     ```java
     static URLStreamHandler getURLStreamHandler(String protocol) {
     				// 先从缓存中根据协议获取 handler 如果缓存命中则直接返回
             URLStreamHandler handler = handlers.get(protocol);
             if (handler != null) {
                 return handler;
             }
     				
       
             URLStreamHandlerFactory fac;
             boolean checkedWithFactory = false;
             boolean overrideableProtocol = isOverrideable(protocol);
       
     				// 判断是否是 jat 和 file 协议 并且 JVM 已经启动完成
             if (overrideableProtocol && VM.isBooted()) {
                 // Use the factory (if any). Volatile read makes
                 // URLStreamHandlerFactory appear fully initialized to current thread.
                 fac = factory;
                 if (fac != null) {
                     handler = fac.createURLStreamHandler(protocol);
                     checkedWithFactory = true;
                 }
     						// factory 为空 使用lookupViaProviders创建handler
                 if (handler == null && !protocol.equalsIgnoreCase("jar")) {
                   	// 使用 SPI 创建 handler
                     handler = lookupViaProviders(protocol);
                 }
     
                 if (handler == null) {
                   	// 通过环境变量创建 handler
                     handler = lookupViaProperty(protocol);
                 }
             }
     				// 如果还没创建好 handler 则使用默认的 factory 进行创建
             if (handler == null) {
                 // Try the built-in protocol handler
                 handler = defaultFactory.createURLStreamHandler(protocol);
             }
     
             synchronized (streamHandlerLock) {
                 URLStreamHandler handler2 = null;
     
                 // Check again with hashtable just in case another
                 // thread created a handler since we last checked
                 handler2 = handlers.get(protocol);
     
                 if (handler2 != null) {
                     return handler2;
                 }
     
                 // Check with factory if another thread set a
                 // factory since our last check
                 if (overrideableProtocol && !checkedWithFactory &&
                     (fac = factory) != null) {
                     handler2 = fac.createURLStreamHandler(protocol);
                 }
     
                 if (handler2 != null) {
                     // The handler from the factory must be given more
                     // importance. Discard the default handler that
                     // this thread created.
                     handler = handler2;
                 }
     
                 // Insert this handler into the hashtable
                 if (handler != null) {
                   	// 放入缓存
                     handlers.put(protocol, handler);
                 }
             }
             return handler;
         }
     ```

     ​	通过`SPI` 创建的过程就不多说了,主要看看通过环境变量创建的环节.

     ```java
     private static URLStreamHandler lookupViaProperty(String protocol) {
       		
       			//private static final String protocolPathProp = "java.protocol.handler.pkgs";
      			  // 获取环境变量为 java.protocol.handler.pkgs 的值
             String packagePrefixList =
                     GetPropertyAction.privilegedGetProperty(protocolPathProp);
             if (packagePrefixList == null) {
                 // not set
                 return null;
             }
     				// 按照 ｜ 切割
             String[] packagePrefixes = packagePrefixList.split("\\|");
             URLStreamHandler handler = null;
             for (int i=0; handler == null && i<packagePrefixes.length; i++) {
                 String packagePrefix = packagePrefixes[i].trim();
                 try {
                   // 拼接 Handler 的名称
                     String clsName = packagePrefix + "." + protocol + ".Handler";
                     Class<?> cls = null;
                     try {
                       	// 加载类
                         cls = Class.forName(clsName);
                     } catch (ClassNotFoundException e) {
                         ClassLoader cl = ClassLoader.getSystemClassLoader();
                         if (cl != null) {
                             cls = cl.loadClass(clsName);
                         }
                     }
                     if (cls != null) {
                         @SuppressWarnings("deprecation")
                         Object tmp = cls.newInstance();
                         handler = (URLStreamHandler)tmp;
                     }
                 } catch (Exception e) {
                     // any number of exceptions can get thrown here
                 }
             }
             return handler;
         }`
     ```



# 三、破案

​	说了这么多，还是没看出为啥代码没生效，有啥用？静下心来，你就会发现是有用的，如果是 `https` 协议，这里的默认 `handler` 是啥呢？如果没有人为的指定应该是`sun.net.www.protocol.https.Handler`,也就是说，通过 `sun` 包下面的 `handler` 创建出来的 `connection` 也会是 `sun` 包下的。

​	那么，破案了。通过异常的日志可以看出，报错的栈信息是来自 `weblogic`的，特别是`weblogic.net.http.HttpsUrlConnection`这句话。这就说明了，使用的 `handler` 是来 `weblogic` 包里面的而不是 `sun`包里面的。

​	回到跳过`https`证书的这块代码里：

![截屏2021-04-25上午11.02.57](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/截屏2021-04-25 上午11.02.57.png)

​	这里就是罪魁祸首,为了证明这点，我特地找到了 `weblogic`下的jar里面去看了一下。

![NhpFHk](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/NhpFHk.png)

![f78XP3](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/f78XP3.png)



# 四、总结

​	遇到不能复现的问题，不要慌张，慌张是解决不了问题的。话说这个问题解决也好解决，要么改代码，要么加上启动参数`-DUseSunHttpHandler=true`

