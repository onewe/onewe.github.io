---
title: druid连接池配置刷新导致数据库被锁
date: 2021/08/27 03:29:12
tags:
- java
- spring
- druid
- spring cloud
categories: java
author: 
  nick: onew
  link: https://onew.me
subtitle: spring cloud 刷新配置导致druid无法解密,数据库被锁.
---



# 一、前言

​	说到 druid 这个连接池,个人感觉还是行的.但 github 2k 多的 issue ,还是让人喜欢不起来呀.在自己的项目里一般都不会选择 druid 这个连接池,毕竟不需要 druid 的监控功能,用 spring 自带的连接池就足够了.

​	但,其他的项目非要用这个连接池,挡都挡不住.没办法～毕竟我说了不算.后面问题就来了,项目还没上线跑着跑着数据库就被锁了,关键是不止一次的被锁.这个问题还是有点意思的,当时就去把日志取了下来分析了一下.好玩!

​	先说一下他们用 druid 连接池干了什么事情, druid 连接池有功能是可以配置数据库密码为密文的,在初始化连接池的时候由 druid 连接池的 filter 进行解密.这样做的好处是防止数据库的密码泄露,这挺好的没啥可说的,毕竟安全的问题大于天对吧～



# 二、问题分析

​	通过日志分析,发现项目跑着的时候,打印了一句 `password changed`.这个可是一个线头,直觉告诉我应该是有啥东西刷新了数据库的配置.

​	不过呢,首先的追踪一下`password changed`这个日志是在哪里打印的,翻了一下 druid 的源码.

![uquynm](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/uquynm.png)

可以看到`password changed`这句话,是在连接池初始化完毕之后才会打印.因为有个 if 判断嘛~.那么就进一步的证实了我的猜想: 数据库的配置被刷新了.

​	项目里用的是 `nacos` 作为配置中心,所有的配置都是从 `nacos` 里获取的,当配置有变化的时候会刷新配置.实验一把,改一下 `nacos` 上的数据库的连接数的配置.

​	果不其然,`password changed`这句话被打印出来了.和相关人员核对了一下,说是没有更改数据库的相关配置,这点我从历史记录里面也确认了一下,确实没改过.那这个就奇怪了.

​	难道改其他的配置文件也会引起配置刷新？实验一把,改了一下 `nacos` 的 redis 配置,😯.`password changed`这句话还是被打印了出来.

​	那么密码被刷新了,刷新成什么了呢?通过 debug 发现是一个没有解密的密文.也就是说这个问题的根本原因是:

1.  druid 配置了数据库密码加密,并在初始化数据源的时候把密文解密成明文,并设置 `password` 这个字段为明文,以提供下一次创建连接到时候使用.
2. 应用启动完成后,修改了nacos 上的配置,导致 druid 的密码被刷新为密文,并设置到 `password`这个字段,这就是`password changed`日志到出处.
3. 当有流量进入应用到时候,连接池的默认连接不够使用了,连接池会拿着错误密码去创建连接,错误的密码创建连接当然会创建失败,当创建失败的时候 druid 会不断的重试,重试次数多了,数据库就把这个账户给锁定了.

​	

# 三、问题重现

​	通过分析得出的结论,还是属于猜测状态,必须得深入源码来剖析.那么起点就是 `nacos`了.

## 3.1 nacos 的配置刷新机制

​	![CTcddI](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/CTcddI.png)

​	nacos 在`NacosContextRefresher`类里,会给每个配置文件加上一个监听器,当配置发生改变的时候,会通过 spring 上下文发送一个 refresh 的事件.

​	spring 有一个`RefreshEventListener`监听这个事件.

![未命名](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/未命名.png)

当 spring 接收到这个事件的时候,会使用 `ContextRefresher` 类进行刷新.

![refresher](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/refresher.png)

这里的刷新逻辑就比较复杂了.

![TkfTPP](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/TkfTPP.png)

核心逻辑就是在这个方法里面.

1. 提取出当前上下文中的环境配置
2. 添加配置文件到 `env`中
3. 获取变化的 `key`集合
4. 发送 `envChange`的事件

这个 `envChange` 的事件会在`ConfigurationPropertiesRebinder`中进行处理.

![TPCE9B](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/TPCE9B.png)

这里的核心逻辑是把所有带有`@ConfigurationProperties`注解类,进行重新绑定.

druid 的配置类刚好也使用了这个注解,所以不可避免的密码被重新刷新了.

![WjpmxR](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/WjpmxR.png)



## 3.2 解决方案

​	当然这种熟悉的情况 spring 也是注意到了的,所以专门留了个配置,用于指定的类不进行重新绑定.

![zZj4Cl](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/zZj4Cl.png)

看到这里,感觉 spring 真的偏心,默认给 HK 数据源配置了不刷新.





# 四、总结

​	这个问题在官方的 github 上也是有的,https://github.com/alibaba/druid/issues/2312. 有时间来提个PR过去.不知道官方有人管没得.
