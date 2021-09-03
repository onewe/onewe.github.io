---
title: Docker Machine 在 Big Sur下的各种问题
date: 2021/09/03 17:29:12
tags:
- Mac Os
- Big Sur
- Docker
- Docker Machine
categories: Docker
author: 
  nick: onew
  link: https://onew.me
subtitle: Docker Machine 在 Big Sur下的各种问题,以及折腾后的解决方案.
---



# 一、前言

​	最近需要模拟 2 套环境来做 redis 双活测试,由于涉及到不同的网段通信,但受制于 docker 在 macOS 系统下的实现方式,没办法做呀.就想到了用虚拟机来搞,既然都用到了虚拟机为何不用 Docker Machine 来搞呢? 反正都是跑在虚拟机上的,在怎么比在虚拟机上装个 Ubuntu 来的快吧.

​	于是,...我还是低估了难度,噩梦开始了.



# 二、Docker Machine VS virtualbox

​	Docker Machine 这个从官方的文档来看还是挺简单的,并且命令也很简单.官方推荐用的 driver 是 virtualbox,按照官方的文档一步一步的做来下,发现使用 virtualbox 无法成功的创建 machine,就算创建了,后面的操作也会报错.

## 2.1 **virtualbox**

创建 名称为 t 的machine

`docker-machine create -d=virtualbox t`

![j0b2bK](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/j0b2bK.png)

这里会卡住,卡 60s 左右

那么这个虚拟机到底有没有创建成功呢? 可以使用 `docker-machine ls` 命令查看

![XIxj9d](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/XIxj9d.png)

可以看到这个名称为 t 的 machine 是创建成功了,但是这个状态却是 stop.

打开 virtualbox 查看虚拟机

![J6cnpi](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/J6cnpi.png)

这个虚拟机居然退出了,异常退出也不知道是啥原因.没关系,说不定重启就好了.

使用命令 `docker-machine start t` 重启虚拟机

![gBUz7W](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/gBUz7W.png)

​	在控制台可以看到,这个虚拟机是启动成功了.可是命令 `docker-machine start t` 却没有反应,好想被卡住了一样.
![Zy13CG](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/Zy13CG.png)

​	在控制台里面的虚拟机都启动成功了,这个命令居然还没有反应,有点奇怪了.大概等了 60s ,命令报错了.

![HwU5E6](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/HwU5E6.png)

​	进入到虚拟机,好像是在报错.

![aLgysF](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/aLgysF.png)

​	并且虚拟机中的 docker 也没有启动.

![StIBL8](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/StIBL8.png)

​	只能从错误信息来分析了.看到一个 `Segmentation fault` 错误,这个错误搞 c 的估计很眼熟吧,在仔细分析了一下错误日志的上下文,发现是生成证书报的错.这个错误因为是系统启动的时候,调用 shell 脚本的时候报的.找了一下系统的可能存放开机启动的脚步的地方结果没找到.一下就失去了方向了.😭.

​	但仔细一想,这个虚拟机的系统镜像叫做 `boot2docker`, 干脆去 google 一下,发现这个玩意儿是放在 github 上的,那这个事情就简单了,在 github 上翻了一下启动脚本,找到了以下这段代码.

![ZNiE9M](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/ZNiE9M.png)

​	于是就猜测是 openssl 这个命令报错的,带着疑惑到虚拟机里面执行一下看下,果然是这个问题.

![wlzi6w](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/wlzi6w.png)

​	这下错误信息就对应上了.那么解决这个问题的思路也就清晰了,按道理,只要把这个 openssl 错误解决,那么之前的卡住命令的情况也就迎刃而解了.

​	可惜,并没有在网上找到相关讨论.不是吧,这个问题就这样了?不如最后挣扎一下,装个 ubuntu 试一试.

​	装 ubuntu 的过程就不描述了,结论是 virtualbox 装不上 😂😂😂😂😂😂😂😂.怀疑人生了,瞬间感觉是自己太菜了不配使用 docker machine.

​	emmm,会不会是 virtualbox 的问题??肯定不是我人的问题.下载一个 `vmware`试一试,看看是不是我人的问题.



## 2.2 VMware fusion

​	在官网上下载一个最新的版本安装上,安装 ubuntu.这个过程就写了.结论是安装上了,但是还得验证 openssl 是否能够正常运行. 

​	验证 openssl

![FQ8lQj](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/FQ8lQj.png)

​	运行成功了,是不是就代表 docker machine 没问题了？

​	测试一把,`docker-machine create --driver=vmwarefusion test`

![6fQgvX](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/6fQgvX.png)

还是报错了...

![lzXlTe](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/lzXlTe.png)

错误信息大意是没有返回ip,但是虚拟机是运行正常的,也没有报错.

继续 google 大法,发现是 macOS 里 dhcp 分配ip 的问题,并且在 github 上找到了一个 pr https://github.com/machine-drivers/docker-machine-driver-vmware/pull/34

按照 pr 里面的提示的操作一波.

先安装 `docker-machine-driver-vmware`,使用 brew 命令安装 `brew install docker-machine-driver-vmware`

再使用 `docker-machine-driver-vmware` 驱动创建一个 machine. `docker-machine create -d=vmware vm-test`.

![yn8sVJ](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/yn8sVJ.png)

搞定～



# 三、总结

​	要不被逼无赖,估计我也不会去折腾这个玩意儿,希望后面搞 redis 双活能够顺利点吧
