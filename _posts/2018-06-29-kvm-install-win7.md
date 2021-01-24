---
title: kvm上安装win7
date: 2018/6/29 22:10:34
comments: true
tags: 
- kvm
- linux
categories: linux
cover: https://gitee.com/oneww/onew_image/raw/master/kvm-install-win7.jpg
author: 
  nick: onew
  link: https://onew.me
subtitle: linux上用win,体验如何??来试一试
---



# 一、前言

最近由于公司业务需求,只能在win上进行编译c库,这就郁闷了,鄙人可是中毒linux用户呀,这样不是要搞死我嘛.于是想到了在kvm上安装一个win来满足开发的需求.kvm相比openVZ 和 VM 等虚拟化技术还算是性能较高的.



# 二、安装前准备

1. 安装好kvm
2. 提前下载好win的镜像
3. 提前下载好virtio驱动包,推荐在fedora的网站下载,鄙人选用的是0.1.126版本 ,[下载地址](https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-virtio/virtio-win-0.1.126-2/)



# 三、安装

1. 把之前下载好的win镜像和virtio驱动包上传到kvm主机上去

2. 创建一个虚拟主机

   ```shell
   virt-install \
   --name win7 \ # 主机名称
   --memory 2048 \ #主机内存
   --vcpus sockets=1,cores=1,threads=2 \ #主机cpu 1个cpu 1核 2线程
   --cdrom=/ios/cn_windows_7_ultimate_with_sp1_x64_dvd_u_677408.iso \ #安装镜像
   --os-variant=win7 \ #系统类型
   --disk /vhost/win7.qcow2,bus=virtio,size=40 \ #创建磁盘
   --disk /ios/virtio-win-0.1.126_amd64.vfd,device=floppy \ #挂载软盘
   --network bridge=br0,model=virtio \ #指定网卡
   --graphics vnc,password=Passw0rd,port=5910 \ #启用vnc
   --hvm \
   --virt-type kvm
   ```

3. 运行以上命令之后就开始创建虚拟机了.![lIfLKf](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/lIfLKf.jpg)

   以上的错误信息请忽略,不会产生太大的影响.

4. 接下来连接vnc进行图形化安装,当然可以使用webVritMgr进行图形化安装.进行vnc连接的话要使用隧道映射到本地的端口,因为5910顿口只能在宿主机上访问`ssh -L 5910:127.0.0.1:5910 root@192.168.3.110`把端口映射到本地.

5. 连接vnc进行安装![yQUuJM](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/yQUuJM.jpg)

   点击浏览按钮,加载刚才我们下载好的virtio驱动包![img](https://gitee.com/oneww/onew_image/raw/master/kvm-diver-GUI.png)

   安装驱动![安装驱动](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/kvm-install-driver.png)

   安装好以后就是我们喜闻乐见的下一步下一步的安装了.值得注意是,在安装过程中,虚拟机会重启多次,如果虚拟没有自己启动,请手动重启一下.附上安装好的截图![kvm-install-finish](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/kvm-install-finish.png)





# 四、总结

安装过程还算是顺利,使用起来呢,感觉有点卡顿,不知道是不是哪里没配置好.
