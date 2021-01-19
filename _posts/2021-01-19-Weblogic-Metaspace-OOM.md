---
title: WebLogic Metaspace OOM 解决案例
key: web logic-classloader-leak-2021-01-19
date: 2021/1/19 22:01:25
tags:
- java
- Weblogic
- metaspace oom
categories: java
author:
  nick: onew
  link: https://onew.me
subtitle: weblogic 多次重复部署卡死,metaspace OOM
---



# WebLogic Metaspace OOM 解决案例

## 一、前言

​	估计也只有我这么惨了，都0202年了还在用weblogic这种上古神器。故事要从前段时间说起,至于是多久时间，我也忘记了。

​	某日，线上发布版本,在weblogic控制台更新的时候,直接卡死无响应。一打开日志一瞧，好家伙，OOM了，还是个metaspace的OOM。

​	这玩意儿就有点奇怪了，metaspace按道理是存放的类信息，字面量（Literal）、类静态变量（Class Static）、符号引用（Symbols Reference）等相关信息。类相关信息在metaspace里面又分为2块区域,**Klass MetaSpace**和**NoKlass MetaSpace**。这就不细讲了，不然扯不完。

​	也就说一般情况下这玩意儿是不会OOM掉的（除开metaspace大小设置不合理的情况）



## 二、分析

​	结合实际情况Metaspace OOM 可能的情况是，以下2种情况：

	- 大量使用反射，由于JVM的优化机制，会定义一些类出来，导致类加载数量增多。
	- JAXB BUG 导致，网上有很多文章在分析



### 2.1 情况一：

​	的确项目里面存在大量的反射，再说了使用了spring 框架，反射是避免不了的，这个没办法。但是这种情况说不通，就算类大量的增长，但从未见过有卸载类的情况。排除～！



### 2.2 情况二：

​	JAXB 这个情况的确可能存在，毕竟是老项目，但这个没有实际的证据，需要进一步的进行分析。

### 2.3 什么时候卸载类？

​	卸载类要满足3个条件，GC才会对其进行卸载，并回收空间：

	- 该类所有的实例已经被回收
	- 加载该类的CLassLoader已经被回收
	- 该类对应的CLass对象没有任何引用

看得出，卸载一个类条件比较苛刻，那就按照上述3个条件进行问题排查。



## 三、排查

### 3.1 复现

​	解决问题的前提是能够复现问题，好在这次问题比较容易复现出来。

 - 环境：
   	- weblogic 12c
    - jdk 1.8
    - metaspace 512M maxMetaspace1024M

- 步骤：
  - 在控制台中使用更新功能，重复部署多次
- 观察：
  - 使用jdk自带*Java VisualVM*，观察metaspace内存的增长，以及一个class的加载数量和卸载数量
- 现象：
  - class一直在增长，没有出现过大幅度的下跌
  - ![6I8w1m7fhSo9Grx](https://i.loli.net/2021/01/19/6I8w1m7fhSo9Grx.png)
  - 总共更新了2次载入了7W+的类，卸载却不到3K，这个结果就离谱。

### 3.2 内存分析

​	把heap dump下来，看看。到底是啥导致没有卸载。前文说了，卸载一个类要满足3个条件。那就按照3个条件进行分析。

​	但加载类是在太多，不可能一个一个的去分析。从3个条件来看，分析classloader是最靠谱的，毕竟所有类的加载都是由classloader进行加载的，而且classloader数量相对较少。

​	通过mat分析，检测出有3个问题,2个都是ChangeAwareCloader：

![Mwg4flXxK9pU5HL](https://i.loli.net/2021/01/19/Mwg4flXxK9pU5HL.png)

看来方向没错，去weblogic官方看了一下，上图中的classloader是负责更新class的。点开详情看一下，发现是nacos的线程hold住了classloader导致，嘿嘿破案了。

![wOGNxqotD6rgu18](https://i.loli.net/2021/01/19/wOGNxqotD6rgu18.png)

### 3.3 这该死的线程

​	通过上面的分析，发现是nacos在spring停止的时候并没有停止相关线程，导致该线程一直在后台活跃。由于线程没有退出，那么相应的classloader就不能被回收。

​	我TM反手一个[pr](https://github.com/alibaba/spring-cloud-alibaba/pull/1892)到nacos。

### 3.4 验证

​	问题原因找到了，就替换掉原由项目的nacos，换上一个停止spring的时候销毁nacos线程版本，验证一下是否解决。

​	由于是线程引起的，所以在验证的过程中，要格外注意，nacos线程是否被正常关闭。

![7Csbdgv84VhxZwt](https://i.loli.net/2021/01/19/7Csbdgv84VhxZwt.jpg)

上图为weblogic一个线程截图。可以看到nacos相关的线程有6个。此时停止应用，nacos线程已经被正常的销毁了。

​	线程已经被正常销毁，再来验证是否能够正常卸载class。重复部署2次，再进行观察。

![8WXGmiIpM2fdDaK](https://i.loli.net/2021/01/19/8WXGmiIpM2fdDaK.png)

​	还是离谱，依旧没有被卸载，看来问题没有被根本解决。会不会是还有啥线程没有被关闭呢。再去找找看看。先停止应用，看看哪些线程还在后台运行。

![V1Za2sfGzMFmyx7](https://i.loli.net/2021/01/19/V1Za2sfGzMFmyx7.jpg)

扒了一下，还有一个线程没有正常销毁。改改代码再试一下吧0.0.



### 3.5 还是这该死的线程

​	虽然把nacos的线程给销毁了，但还有业务线程还在跑，再测试一把，看看能不能正常的回收class。经过测试没有出现可以的线程了。感觉自己又行了。

​	继续测试，重复部署，验证是否能够正常卸载class。

![EhGkgSMz71sbZeC](https://i.loli.net/2021/01/19/EhGkgSMz71sbZeC.png)

还是离谱，加载了7W多的类，卸载才4K多点，这还是不正常。果然，这个工程的问题很多呀。



### 3.6 重新分析内存,讨厌的监控

​	线程的问题解决了，但问题依旧，只能再dump一份内存看看。

![u6wdjzoRpvADNYT](https://i.loli.net/2021/01/19/u6wdjzoRpvADNYT.png)

问题还是在classLoader上，去详情看看。

![YPCexIzNHrbq3Ud](https://i.loli.net/2021/01/19/YPCexIzNHrbq3Ud.png)

classloader被Logger给hold住了，这有点奇怪了。由上图可以看出，changeAwareClassLoader加载了LoggingHandler，在Logger中引用了LoggingHandler，这个Logger是系统类，

​	由于Logger是系统类，由jvm的`Bootstrap ClassLoader`加载，这个classloader的生命周期就很长了，只有jvm进程退出，才会被销毁掉。

​	只能翻一下LoggingHandler的代码，看下为啥要去跟Logger扯上关系。

![DNiQLXeBqAIna6K](https://i.loli.net/2021/01/19/DNiQLXeBqAIna6K.png)

这个玩意儿在启动的时候回去注册一下，获取的是系统的Logger，怪不得会扯上关系。不知道为啥没有被取消注册，取消注册的方法倒是有个。

![Erv2pmXdNyPRlGq](https://i.loli.net/2021/01/19/Erv2pmXdNyPRlGq.png)

猜测是jar包版本冲突导致出现了异常，就没有把取消注册流程给走完。问了一下同事，说这个LoggingHandler是属于一个监控，这个监控比较老，可以直接下掉。那就不去纠结为啥没有取消注册了，直接下掉看疗效。



### 3.7 重新验证

​	把监控的jar包下掉，看看能不能达到预期的效果。

![ZhkNoL9AjsxR5dn](https://i.loli.net/2021/01/19/ZhkNoL9AjsxR5dn.png)

weblogic初始状态，一片祥和。

重复部署3次：

![seum7EkIF83Qb1i](https://i.loli.net/2021/01/19/seum7EkIF83Qb1i.png)

还是没卸载，离谱，看来要翻车了。不急陪他耍耍，等他个10分钟，看他自己投降。是不是觉得是玄学😂。对，还真不是玄学，有些东西没有及时释放，是因为在finalize队列中排队呢，等一下就好。

10分钟之后，不对应该是出去吃饭过后：

![5ybVJMqUr3I1WjR](https://i.loli.net/2021/01/19/5ybVJMqUr3I1WjR.png)

metaspace的占用水平已回归到正常的水平，类卸载从4000到了28000。

反复部署后，metaspace内存也稳定到600M。ok，完美解决。









​	
