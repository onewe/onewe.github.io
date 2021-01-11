---
title: javaFX 开发总结
date: 2018/7/06 16:56:25
tags:
- java
- javaFX
categories: java
cover: https://gitee.com/oneww/onew_image/raw/master/java_fx_one.png
author: 
  nick: onew
  link: https://onew.me
subtitle: 一个夕阳下的桌面开发技术javaFX.
---



# 一、前言

由于最近公司需要开发桌面软件,进行人脸识别的相关业务操作,结果很不幸的是这个任务就到我的头上来了.对于一个桌面软件开发的萌新来说,你让我c#做??js做??不可能的,擅长的只有java,没办法硬着头皮上上了,顺便学习一下javaFX的相关技术.javaFX是由[甲骨文公司](https://zh.wikipedia.org/wiki/%E7%94%B2%E9%AA%A8%E6%96%87%E5%85%AC%E5%8F%B8)推出的一系列的产品和技术，该产品于2007年5月在JavaOne大会上首次对外公布。JavaFX技术主要应用于创建Rich Internet application（[RIAs](https://zh.wikipedia.org/wiki/RIA)）。当前的JavaFX包括JavaFX脚本和JavaFX Mobile（一种运营于移动设备的操作系统），今后JavaFX将包括更多的产品。JavaFX脚本的前身是一个由Chris Oliver开发的一个叫做F3的项目,JavaFX期望能够在桌面应用的开发领域与Adobe公司的AIR、[OpenLaszlo](https://zh.wikipedia.org/w/index.php?title=OpenLaszlo&action=edit&redlink=1)以及[微软](https://zh.wikipedia.org/wiki/%E5%BE%AE%E8%BD%AF)公司的[Silverlight](https://zh.wikipedia.org/wiki/Silverlight)相竞争，它也可应用于Blu-Ray的交互平台[BD-J](https://zh.wikipedia.org/wiki/BD-J)，但目前尚未宣布对Blu-Ray的支持计划。很遗憾的是用得人不多就是了.感觉比起swing,awt这些javaFX写起来更方便,学习成本较低,界面也比swing,awt这些好看,并且能够使用css来控制样式.这就比较灵活了.



# 二、遇到的坑

1. 多线程的问题

   这个问题在刚开始接触的时候困扰我很久,为什么不能在子线程中的刷新UI界面呢?javaFX 为什么不是线程安全的呢.苦于上面这两个问题,思考了一下,不能再子线程中刷新UI这件事貌似是业界的共识,android也只能在主线程中刷线UI,这样做的好处是,UI绘制的时候比较好好控制,如果出现场多线程刷新UI,不知道要出现什么毛病.

   解决办法:

    	1. 使用Platform的runLater方法,把刷新UI的操作放在runLater方法中去,这样你刷新UI的操作就会在主线程中进行.是个非常方便的方法.
    	2. 使用javafx.concurrent中的Task类,这个类是线程安全的,用这个来刷新UI 也是个不错的选择,注意这个必须单独的使用一个thread对象来跑.
    	3. 使用javafx.concurrent中的Service类,这个是对Task的一种封装,使用起来比较方便.

   一般场景:

   ​	一般情况下,当javaFX 主线程启动的之后,如果需要做非UI操作,请使用异步的方式,把耗时的操作全部给其他线程去做,不要在主线程中去,不然会出现应用卡顿的问题,在其他线程中完成任务之后在切回主线程进行UI操作.

2. 多控制器的问题

   在大多数的javaFX教程或者网上的demo里面基本都是一个xml对应一个controller,这其实没毛病,但是如果这个界面有点复杂,所有的页面逻辑全部堆在一个controller中这未免有点牵强.如果拆分为多个子页面就会遇到多个controller通信传值的问题.

   解决办法:

    	1. 使用fx:include标签把复杂的页面拆分为多个子页面
    	2. 使用在主controller中注入其他controller,在子controller获得主controller的引用,从而获得其他controller的引用,这种办法不乏是一种解决办法,但是这种方式与主controller的耦合性太强了,不太推荐.另外一个办法是使用EventBus进行消息广播,每个controller初始化的时候都注册上EventBus,消息传递的时候处理响应的事件就好了,这个办法看似很优雅,单也有个问题,使用EventBus会使得事件满天飞,不知道哪里处理了哪里的事件,导致代码阅读性变差,并且事件不控制好,稍不注意会引起事件广播风暴.两个办法都可以酌情使用.

3. 多窗口切换的问题

   这里的情况是这样的,在我这个项目中,我总共需要4个窗口,一个用于初始化程序的窗口(装逼界面),一个程序的主界面,另外两个分别是设置界面和摄像头预览界面.最开始我想的是用FX的dialog来做,有的同学会问,dialog能做吗?? 买毛病的老铁是可以的做的,但是界面及其难以控制.于是我就放弃了.并且窗口传值也是个问题.

   解决办法:

    	1. 给每个窗口创建一个对象的xml文件,在需要的时候加载显示就可以了,推荐做成单例,减少加载xml文件的次数.
    	2. 窗口传值的时候只要使用使用Stage对象的setUserData方法放入值,取值的时候使用getUserData方法即可获取值,只要能够保证你窗口对象是单利的,传值一般没啥问题.

# 三、总结

通过这几天的折腾,也学到了不少新东西,至少搞了两个装逼的特效,嘿嘿,美滋滋.对了,javaFX双向绑定天下第一.
