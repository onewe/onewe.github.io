---
title: docker 模拟双机房多网段通信
date: 2021/09/06 07:53:25
tags: 
- docker
categories: docker
author: 
  nick: onew
  link: https://onew.me
subtitle: 使用 docker 模拟多机房不同网段测试环境
---



# 一、前言

​	最近在搞 redis 双活,在折腾 redis 双活的模拟环境,考虑到生产环境是不同的机房,就萌生了使用 docker 来模拟多机房不同网段的理想环境.

​	docker 网络是采用桥接完成,会有一张 docker0 的网卡,每个容器都是在 docker0 这张网卡下.我记得网上有张描述 docker 网络通信的图,这里就不放出来,随便百度一下就有的东西.总之,明白网络通信的原理是很重要的.



# 二、干活

​	由于是在 mac 系统下干活,想要模拟还得使用 docker-machine 来搞.以下会涉及到 docker-machine 命令,但核心部分还是在设置网络上,设置网络的命令是没有任何差异的.



## 2.1 使用 docker-machine 创建一个跑 docker 的虚拟机

创建一个名称为: network-lab 的虚拟机

`docker-machine create -d=vmware network-lab`

![qGaruh](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/qGaruh.png)

创建成功.



## 2.2 创建 2 个不同的网段的网络

创建一个名称为北京的网络: bj-net

`docker network create -d bridge --subnet 192.168.9.0/24 --gateway 192.168.9.1 bj-net`

创建一个名称为上海的网络: sh-net

`docker network create -d bridge --subnet 192.168.10.0/24 --gateway 192.168.10.1 sh-net`

查看网络是否创建成功:

`docker network ls`

![dE9bo5](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/dE9bo5.png)

创建2个容器测试网络

使用北京网络运行容器: `docker run --rm -it --network bj-net busybox:latest`

![Vv0oGQ](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/Vv0oGQ.png)

使用北京网络的容器网络情况:

网关: 192.168.9.1

ip地址: 192.168.9.2



使用上海网络运行容器: `docker run --rm -it --network bj-net busybox:latest`

![X08BC9](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/X08BC9.png)

使用上海网络的容器网络情况:

网关: 192.168.10.1

ip地址: 192.168.10.2



现在这种网络情况是无法 ping 通的

北京 ping 上海

![SUQLzz](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/SUQLzz.png)

上海 ping 北京

![UXh6Wx](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/UXh6Wx.png)

​	那么这种情况怎么解决呢?按照 docker 网络通信的原理,宿主机上必定是有 2 张网卡的,所以只要开启转发,就能把不同网段发过来的数据包转到对应的网卡,这样就能实现互通了.



## 2.3 互通有无

​	在宿主机上使用 ifconfig 可以看到北京和上海的2张网卡

![4CvTmh](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/4CvTmh.png)

先查看一下 route 信息,看看有没有进行默认的配置

![V3zYqu](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/V3zYqu.png)

通过 route 命令可以看到 9段和10段的包会到9段和10段的网卡上去,这里路由的配置是没有问题.

查看一下主机是否开启转发,默认情况下应该是开启了的,这里确认一下

`cat /proc/sys/net/ipv4/ip_forward`

![EFcpDh](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/EFcpDh.png)

删除 docker 针对于我们自定义的2个网卡的默认的 iptables 规则.

查看 iptables 中 filter 表中的所有规则: `sudo iptables -t filter -nvL`

![vMqoI4](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/vMqoI4.png)

可以看到在 INPUT链 和 OUTPUT链中是没有规则配置的,那么这里只需要更改 FORWARD 链的规则即可,由于虚拟的原因,这里截图不能截全.

通过查看 docker 的自定义链,发现是在 DOCKER-ISOLATION-STAGE-2 里定义了 北京和上海 2张网卡的规则.

![Wt3MQP](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/Wt3MQP.png)

这里只要删除这2条规则,不同网段的通信就通了.

```
sudo iptables -t filter -D DOCKER-ISOLATION-STAGE-2 -o br-7703ed4f8946 -j DROP
sudo iptables -t filter -D DOCKER-ISOLATION-STAGE-2 -o br-109ff1ea9a3d -j DROP
```

![mLMQ2n](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/mLMQ2n.png)

ok~已经删干净了,试一试看看能不能成功.



上海 ping 北京

![Ryycc2](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/Ryycc2.png)

北京 ping 上海

![zB60DX](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/zB60DX.png)

搞定



# 四、总结

​	总体来说不是很复杂,只要了解 docker 网络通信原理和 iptables 的使用,问题不大.吃饭了～

​	



