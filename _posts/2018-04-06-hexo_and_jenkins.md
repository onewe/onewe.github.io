---
title: hexo与jenkins简单的集成
date: 2018/4/06 18:20:25
tags: hexo
categories: jenkins
cover: https://upload-images.jianshu.io/upload_images/8958298-a88d35bfee5d3b43.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240
author: 
  nick: onew
  link: https://onew.me
subtitle: 杀鸡焉用牛刀的整上了Jenkins来进行自动部署,感觉美滋滋.O(∩_∩)O
---

# hexo与jenkins简单的集成
> 由于hexo是静态的内容,导致每次写博客都要把md文件上传到服务器,然后再用hexo命令生成静态文件.这样实在太麻烦了.于是杀鸡焉用牛刀的整上了Jenkins来进行自动部署.O(∩_∩)O哈哈~.

## 安装Jenkins

- 环境
	- 服务器系统: CentOS7
	- jdk 版本: openJDK 1.8
- 配置环境(这里主要是安装JDK,如果已经安装请跳过此步骤)
	- 使用命令`yum install java-1.8.0-openjdk* -y`安装jdk.
	- 验证jdk是否安装成功,使用命令`java 或者 javac` ,看是否能否执行该命令
- 安装jenkins(采用yum的安装方式)
	- 添加jenkins源
		- `wget -O /etc/yum.repos.d/jenkins.repo http://jenkins-ci.org/redhat/jenkins.repo`
		- `rpm --import http://pkg.jenkins-ci.org/redhat/jenkins-ci.org.key`
	- 安装
		- `yum install jenkins`
- 启动jenkins
	- `systemctl start jenkins` 
- 验证是否安装成功
	- `systemctl status jenkins` ![2LaFvP](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/2LaFvP.jpg)
	- jenkis默认的端口是8080,请打开浏览器http://服务器ip:8080,验证是否能够访问(如果不能访问,请确认一下防火墙是否是防火墙的问题)
	- 第一次访问的时候会要求输入密码,密码会默认生成一个,密码保存在`/var/lib/jenkins/secrets/initialAdminPassword`这个文件里面,如果没有请看提示,jenkins会提示密码保存在哪个文件里面.搞定后就出现可以看见jenkins的主页了![U665Lv](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/U665Lv.jpg)
- 修改登陆密码
	- 点击主页的系统管理![Zcpa9i](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/Zcpa9i.jpg) 
	- 点击管理页面的管理用户![R3du3t](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/R3du3t.jpg)
	- 点修齿轮这个按钮![VFEFi1](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/VFEFi1.jpg)
	- 修改密码![JDNnzC](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/JDNnzC.jpg)
- 安装git插件
	- 进入插件管理 ![fd3EVu](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/fd3EVu.jpg) 
	- 在插件管理里面的可选插件选项卡中搜索`GIT server Plugin` 这个插件,再点击获取.
- 创建第一个集成任务
	- 进入jenkins主页点击新建任务
	- 输入任务名称,即可完成任务的创建![RbaMyv](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/RbaMyv.jpg)
	- 配置任务中的源码管理![wIIUkk](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/wIIUkk.jpg)
	- 配置触发器,这里悬着poll SCM的方式,这种方式是周期性的pull源码下来看有没有变化,如果有变化就进行构建.还有很多种触发方式,后面会再写一篇来进行讲解![31dz5A](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/31dz5A.jpg)
	- 配置构建脚本,这里我们选择`Execute shell`的方式进行构建,这里的意思是触发器触发后发现git上面的源码有变化就会执行我们的构建脚本,如果git上面没有变化是不会执行构建脚本的.![DoSvEU](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/DoSvEU.jpg)
	- 点击保存,任务就配置好了.可以回到主页看得到我们才创建好的任务.如果要立即执行任务可以点击立即执行的按钮.![EwbUHp](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/EwbUHp.jpg)
- 查看任务执行日志(如果构建出现问题,可以通过查看日志来排查问题)
	- 点击主页的构建历史按钮![XoHxOV](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/XoHxOV.jpg)
	- 点击进去后会看到历史的构建记录,红色的图表是代表构建失败.点击最后面的图标可以查看日志![Xhfacd](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/Xhfacd.jpg)
	- 可以通过控制台输出的消息来排查问题所在![qYGpcR](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/qYGpcR.jpg)

## 总结
ok 通过以上的步骤就简单的把hexo和jenkins结合在一起了,写博客也方便了不少.不得不说jenkins是个强大的工具,用来杀鸡也无妨.哈哈哈哈哈.  
