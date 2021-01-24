---
title: centos7 修改limits限制
date: 2019/11/6 22:10:34
comments: true
tags: 
- linux
categories: linux
cover: https://gitee.com/oneww/onew_image/raw/master/centos_limits_cover.jpg
author: 
  nick: onew
  link: https://onew.me
subtitle: nginx提示文件数问题,修改limits nginx重启不生效,limits 过大服务器炸了?
---

# 一、前言

​	最近在做压力测试,看看后面接口能跑到多少的qps,结果跑了一下下,接口就开始报错了,经过排查发现,后端是正常的,是nginx 打开文件数过多导致的nginx的错误,于是乎,就改呗.改着改着服务器就被改炸了.



# 二、修改limits

 - 查看当前open files数量 `ulimit -a`

   ![pT9JnZ](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/pT9JnZ.jpg)

 - 测试服务最高能到多少(当然这个数字并不是越大越好)

   ![j2bwuU](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/j2bwuU.jpg)

   图中可以看到最大值在1000000左右.**一定不要试图超过这个值,不然ssh会连接不上服务器的,哪怕物理终端都会登陆不上去,切记!**

- 修改配置使之永久生效.打开`vim /etc/security/limits.conf`,在文件末尾添加以下两行参数.

  ![5Af97a](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/5Af97a.jpg)

  上述两行参数为,任何用户的文件数都设置为1000000,保存.重启.

- 验证是否生效 `ulimit -n`

  ![cc2qvr](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/cc2qvr.jpg)



# 三、验证nginx

​	之前没改文件数,nginx报错,提示说文件最大数为1024,现在看看修改之后是否还会报错.如果nginx是通过yum安装,并通过服务启动的话,不出意外还是会提示文件最大数为1024.

​	那么为什么还是会报错呢?原来centos7与centos6不一样,仅仅修改limits.conf文件是不行的(如果是通过服务启动的话),还要在修改`/etc/systemd/system.conf`这个文件.打开`vim /etc/systemd/system.conf`文件,找到`DefaultLimitNOFILE=`这行,放开注释,并填上你需要的数字.重启服务器.

​	重启成功后,nginx就不会提示这个错误了.ok!



# 四、文件数过大导致系统登陆不上,抢救措施.

​	如果通过上面步骤修改文件数不小心改炸了,那么接下来就是你想要的抢救方案了.

1. 如果有物理机,请跑到机房去,没有物理机器,就想办法进入系统引导过程.
2. 进入linux单用户模式,网上教程很多.
3. 修改grub2 引导
   - 在正常系统入口上按下“E”，进入Edit模式， 搜索“ro”那一行
   - 把“ro”更改为“rw”
   - 把“rhgb quiet”删除
   - 在本行增加“init=／bin/sh”或者“init=／bin／bash”
   - 按下“ctrl+x” 启动系统
4. 单用户教程[单用户教程](https://www.linuxidc.com/Linux/2017-04/142475.htm)
5. 正常进入系统,把之前改的文件在改回来
6. 重启
7. 系统正常
8. done



# 五、总结

​	**系统炸了不要慌!!!!!!!!**
