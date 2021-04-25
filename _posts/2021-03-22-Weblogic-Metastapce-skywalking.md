---
title: WebLogic Metaspace OOM 解决案例（后续之SkyWalking）
key: web logic-classloader-leak-2021-03-22
date: 2021/03/22 17:01:25
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

# WebLogic Metaspace OOM 解决案例（后续之SkykWalking）

## 一、前言

​	之前解决了因为 `nacos` 未能关闭线程,导致 weblogic 中的 ChangeAwareClassloader 被 nacos 的线程长期持有的问题。虽然是解决了，但是还是大意了。由于当时复现的环境跟线上的环境并不是完全一致，所以还是没能根本性的解决。没办法只能把复现环境尽量调整到跟线上一致，再来分析一波。

​	先预告一下，这次的罪魁祸首是 SkyWalking 。emmm，标题已经剧透了，😅。



## 二、SkyWalking

​	SkyWalking 是业内流行度很高的 apm ，目前在 apache 旗下。skyWalking 在 java 端可以使用 agent 的方式来进行监控，由于是无侵入性的，所以在初期选型的时候直接就采用了 agent 的方式。但世事难料呀，由于 skywalking 并没有宣布支持 weblogic ，加上调研不仔细，就直接莽了上去。

​	用，是能用的，只不过会有一些小问题，前期的小毛病都已经解决了，只是这次的问题比较严重而已。来，直接分析一波 heap 看看是什么东西导致了 classLoader 没又被回收掉。有了上一次的经验，基本可以确定是 classLoader 没有被释放。

## 三、Heap 分析

​	这次分析的主角还是 Mat 。先在 weblogic 中启动项目，然后停止项目，并删除项目。这样的目的是模拟项目更新的操作，然后我们再使用 `jamp`  命令 `dump` 一份儿内存看看。命令: `jmap -dump:file=/tmp/PID.dump PID`。

​	使用 Mat 加载刚才 dump 出来的文件。

![aRRVhQ](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/aRRVhQ.png)

可以看到，果然还是 ChangeAwareClassLoader 没有被释放掉的问题，点开详情看看，到底是谁那么讨厌，拿着 classLoader 不放。

![XLlfmo](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/XLlfmo.png)

从这个图可以看出，ChangeAwareClassLoader 没有被释放掉是被 skywalking 中的一个Map 给持有了。这个 Map 到底有啥用，这点需要去源码看一看。

![未命名](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/未命名.jpg)

根据 ClassLoader 卸载原则，要清空 `INSTANCE_CACHE`  和 `EXTEND_PLUGIN_CLASSLOADERS` 这两个 map。 由于这两个都是私有变量不能直接访问，这里需要反射一波。

## 四、如何释放 SkyWalking 缓存？

​	由于 weblogic 的特殊性，这里需要考虑到以下几点：

- 要准确清理应用的 classLoader，不能出现应用部署多次，只清理一个的情况。
- 只能清理当前应用的 classLoader，不能出现别的应用不需要清理的情况下，误清理。



​	基于以上2点，有点不好操作，因为这个 ChangeAwareClassLoader 的生命周期和 ServletContext 的生命周期是不一致的。在整个应用的生命周期中，ChangeAwareClassLoader 只会创建一次(除非重新部署)。但 ServletContext 则会创建多次，应用启动一次创建一次。

​	如果跟着 ServletContext 的生命周期走，在应用重复启动多次情况下，会把本不应该清理的 ClassLoader 给清理掉。因为我们需要在应用卸载的时候卸载 ClassLoader 而不是在应用停止的时候清理。

​	看了一下 weblogic 的官网文档，得知有个 `ApplicationLifecycleListener`。但这个东西是 weblogic 独有的，不是属于j2e规范。要使用这个东西就必须把 war 改成 ear。这就有点尴尬了。

![gdXIkU](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/gdXIkU.png)

​	既然要解决这个问题，本就是逆天改命之举。那也怪不得我使用奇淫巧技了。

## 五、SkyWalking 里的花招

​	虽然不能直接使用`ApplicationLifecycleListener`，那么能不能换个方式使用呢？了解过 skyWalking 的人都知道，skyWalking 可以通过 agent 的方式实现无侵入式的增强。幸好 skyWalking 留了一个口子，让我们自行扩展。我深信 skyWalking 留个口子不是拿来给我搞骚操作的。但没办法，还是要利用一下。那么呼之欲出的插件就来了。

​	skyWalking 是有一个插件功能的，这个插件可以理解为一个拦截器。至于插件要怎么写，这里就不详细介绍了，可以去看看 skyWalking 的官方文档。 可以简单看看官方项目自带的tomcat插件。

![interceptor](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/interceptor.jpg)



这里分为3个部分：

- 拦截器的定义
- 拦截器的具体逻辑
- 描述信息

下面代码为定义代码

```java
// org.apache.skywalking.apm.plugin.tomcat78x.define.ApplicationDispatcherInstrumentation

public class ApplicationDispatcherInstrumentation extends ClassInstanceMethodsEnhancePluginDefine {

    private static final String ENHANCE_CLASS = "org.apache.catalina.core.ApplicationDispatcher";
    private static final String ENHANCE_METHOD = "forward";
    public static final String INTERCEPTOR_CLASS = "org.apache.skywalking.apm.plugin.tomcat78x.ForwardInterceptor";

    /***
     * 构造器拦截器
     * */
    @Override
    public ConstructorInterceptPoint[] getConstructorsInterceptPoints() {
        return new ConstructorInterceptPoint[] {
            new ConstructorInterceptPoint() {
                /***
                 * 描述如何匹配构造器
                 * */
                @Override
                public ElementMatcher<MethodDescription> getConstructorMatcher() {
                    return any();
                }
                /***
                 * 使用哪个拦截器
                 * */
                @Override
                public String getConstructorInterceptor() {
                    return INTERCEPTOR_CLASS;
                }
            }
        };
    }
    
    /***
     * 方法拦截器
     * **/
    @Override
    public InstanceMethodsInterceptPoint[] getInstanceMethodsInterceptPoints() {
        return new InstanceMethodsInterceptPoint[] {
            new InstanceMethodsInterceptPoint() {
                /***
                 * 描述如何匹配方法
                 * */
                @Override
                public ElementMatcher<MethodDescription> getMethodsMatcher() {
                    return named(ENHANCE_METHOD);
                }
                /***
                 * 使用哪个拦截器
                 * */
                @Override
                public String getMethodsInterceptor() {
                    return INTERCEPTOR_CLASS;
                }
                /***
                 * 是否覆盖参数
                 * */
                @Override
                public boolean isOverrideArgs() {
                    return false;
                }
            }
        };
    }

    @Override
    protected ClassMatch enhanceClass() {
        return byName(ENHANCE_CLASS);
    }
}

```

下面代码为拦截器代码

```java
// org.apache.skywalking.apm.plugin.tomcat78x.ForwardInterceptor
public class ForwardInterceptor implements InstanceMethodsAroundInterceptor, InstanceConstructorInterceptor {
    
    /***
     * 目标方法执行前
     * @param objInst 执行方法的目标对象
     * @param method 目标方法
     * @param allArguments 方法参数
     * @param argumentsTypes 参数类型
     * @param result 返回值
     * */
    @Override
    public void beforeMethod(EnhancedInstance objInst, Method method, Object[] allArguments, Class<?>[] argumentsTypes,
        MethodInterceptResult result) throws Throwable {
        if (ContextManager.isActive()) {
            AbstractSpan abstractTracingSpan = ContextManager.activeSpan();
            Map<String, String> eventMap = new HashMap<String, String>();
            eventMap.put("forward-url", objInst.getSkyWalkingDynamicField() == null ? "" : String.valueOf(objInst.getSkyWalkingDynamicField()));
            abstractTracingSpan.log(System.currentTimeMillis(), eventMap);
            ContextManager.getRuntimeContext().put(Constants.FORWARD_REQUEST_FLAG, true);
        }
    }
    
    /**
     * 目标方法执行后
     * @param objInst 执行方法的目标对象
     * @param method 目标方法
     * @param allArguments 方法参数
     * @param argumentsTypes 参数类型
     * @param ret 返回值
     * **/
    @Override
    public Object afterMethod(EnhancedInstance objInst, Method method, Object[] allArguments, Class<?>[] argumentsTypes,
        Object ret) throws Throwable {
        ContextManager.getRuntimeContext().remove(Constants.FORWARD_REQUEST_FLAG);
        return ret;
    }

    /***
     * 处理异常
     * @param objInst 执行方法的目标对象
     * @param method 目标方法
     * @param allArguments 方法参数
     * @param argumentsTypes 参数类型
     * @param t 异常
     * */
    @Override
    public void handleMethodException(EnhancedInstance objInst, Method method, Object[] allArguments,
        Class<?>[] argumentsTypes, Throwable t) {

    }
    /**
     * 构造方法执行后
     * @param objInst 目标对象
     * @param allArguments 构造器参数
     * */
    @Override
    public void onConstruct(EnhancedInstance objInst, Object[] allArguments) {
        objInst.setSkyWalkingDynamicField(allArguments[1]);
    }
}

```

下面代码是描述

```properties
tomcat-7.x/8.x=org.apache.skywalking.apm.plugin.tomcat78x.define.TomcatInstrumentation
tomcat-7.x/8.x=org.apache.skywalking.apm.plugin.tomcat78x.define.ApplicationDispatcherInstrumentation
```

好了，现在你已经能够熟练的编写一个插件了。



## 六、清理 ClassLoader 的插件

​	根据 webLogic 的特性，需要增强 WebAppModule 这个类，这个类安装应用只会创建一次。这是个很好的人选。那么生命周期监听器在那里添加呢？

​	WebAppModule 这个类提供了获取 WebApplicationContext 对象的方法，只需要在 WebAppModule 初始化方法 `init` 调用完毕之后，就直接把 listener 添加到 WebApplicationContext 中去。

​	listener 的具体逻辑是，在 postStart 方法里持有 ChangeAwareClassLoader 引用，然后在 postStop 方法里进行清理。清理不用说了，反射直接莽。

定义：

![c7pfyg](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/c7pfyg.png)

插件：

![UaqMVw](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/UaqMVw.png)

描述：

![UCAu2D](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/UCAu2D.png)

一切准备就绪，只需要打成 jar 包，丢到 skywalking 到 plugin 目录即可。



## 七、事成之后

​	加入插件之后，可以用 jdk 自带的调试工具来欣赏一下期待已久的 Metaspace 内存使用图。

![SCOQzK](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/SCOQzK.png)

​	weblogic 还是太坑了，主要不是 weblogic 的问题，是使用新技术与不敢去老技术栈的矛盾问题。其实呢，全部用老技术，遵循 weblogic 这一套，也不会出幺蛾子。但现在要推新技术，老的技术栈不去，只能天天填坑。

