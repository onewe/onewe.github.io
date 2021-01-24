---
title: hexo图床与简单自动化
date: 2018/4/09 20:16:25
tags: hexo
categories: jenkins
cover: https://gitee.com/oneww/onew_image/raw/master/hexo_image_cover.jpeg
author: 
  nick: onew
  link: https://onew.me
subtitle: 中国图床哪家强?emmmmm 码云很强!
---

# hexo图床与简单自动化
> 其实标题是自动化而已,起内容只是把hexo的md文件中的图片链接批量替换掉而已,没有啥技术含量.


## 为什么需要图床?
这只是个人需求而已,并不是每个人都需要图床.那么图床有啥好处呢?第一,可以减轻服务器的存储压力;第二,减轻应为图片带来的额外的流量消耗;第三,图床一般都是具有cdn加速的,可以让你的网页变得更快.我主要是看中了cdn加速这点,因为我的服务器和域名都是国外的,适当还是要加速的,不然就太慢了.

## 国内有哪些图床呢?
国内的图床有一下几个,当然我列出的只是我知道的几个而已.  

- 七牛,要钱,收费,备案.
- 拍云,要钱,收费,备案.
- 阿里云oss,要钱,收费,备案.
- v2ex,要钱,只向会员开放,至于要不要备案这个就不知道了.
- Imgur,免费的,国外的,国内速度不行.
- SM.MS,免费的,国内速度不行
- 新浪微博,不要钱,速度快,由于怕以后图片死在新浪里面了.不考虑(毕竟新浪只是微博而已)
- github,国内速度不行(可以利用issue上传图片,当图床用)

综合以上图床,都没找到心目中的那种 免费 速度快 https  不备案 的图床,其实我们忽略了一点,码云是可以当图床用的,哈哈.就算新建一个项目,把图片传上去.就可以当图床使用了(就是有点不方便),目前本博客的图片就打算全部换成码云的了,之前是放在简书上面的,发现简书还要不方便,传图的方式不geek.用了几天没有发现码云对这种使用方式有啥明显的限制.

## 码云图床
在码云上新建一个项目,把图片全部上传到码云上去,注意建的项目要是公开的,如果是私有的会出现访问不了的情况.

## 简单自动化
目前我想达到的目的是,在写博客的时候,图片文件放在本地,这样可以边预览编写.当写好后提交到码云上面的时候,自动把图片换成码云的链接,从而达到图床的效果.  

- 目录结构如下,hexo的md文件和图片文件夹在同一个目录,这样写博客的使用就可以使用相对路径来引用图片了
![Mkj3MR](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/Mkj3MR.jpg) 
- 把img目录跟码云挂钩,这样新加入的图片直接提交到码云上去,达到图床的效果
![cW8utS](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/cW8utS.jpg)
- 使用脚本提交md文件,并且修md文件中的图片的链接.脚本很简单,如下

	```shell
		#!/bin/bash
		sed -i '' 's/!\[cover\](.\/img/https:\/\/gitee.com\/zuonima\/onew_image\/raw\/master/g' $1
		sed -i '' 's/!\[image\](.\/img/!\[images\](https:\/\/gitee.com\/zuonima\/onew_image\/raw\/master/g' $1
		git add $1
		git commit -m "$2"
		git push origin master
		cd ./img
		git add .
		git commit -m "$2"
		git push origin master
		exit 0
	```
- ok 经过以上的步骤,愉快的写博客吧.

## 总结
为什么说是简单的自动化呢??因为步骤的确很简单呀哈哈哈,结合jenkins的话 感觉还是勉强凑合吧(水了,水了,水了).
