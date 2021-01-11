---
title: centos安装docker
date: 2018/5/08 9:20:25
tags:
- docker
- centos
- docker install
categories: docker
cover: https://gitee.com/oneww/onew_image/raw/master/docker_cover.png
author: 
  nick: onew
  link: https://onew.me
subtitle: 按照官方文档,进行安装.记录下来,免得每次都去官方.
---

## 一、删除旧版本的docker

```shell
sudo yum remove docker \
                  docker-client \
                  docker-client-latest \
                  docker-common \
                  docker-latest \
                  docker-latest-logrotate \
                  docker-logrotate \
                  docker-selinux \
                  docker-engine-selinux \
                  docker-engine
```

> 注意,上面的命令将会彻底的移除docker,但是不包括之前创建的容器,镜像等



## 二、yum在线安装docker

1. 安装必要的依赖

   ```shell
   sudo yum install -y yum-utils \
     device-mapper-persistent-data \
     lvm2
   ```

2. 设置yum repository

   ```shell
   yum-config-manager \
       --add-repo \
       https://download.docker.com/linux/centos/docker-ce.repo
   ```

3. [可选]启用edge和test

   ```shell
   sudo yum-config-manager --enable docker-ce-edge #启用edge
   sudo yum-config-manager --enable docker-ce-test #启用test
   sudo yum-config-manager --disable docker-ce-edge #禁用edge
   sudo yum-config-manager --disable docker-ce-test #禁用test
   ```

4. 安装docker `sudo yum install docker-ce`

5. 启动docker `sudo systemctl start docker`

6. 查看docker服务是否启动正常`sudo systemctl status docker` 看到状态为active说明是启动成功的

7. 如果要安装指定版本的docker,可以通过`yum list docker-ce --showduplicates`查看可以安装的版本号,然后通过`sudo yum install docker-ce-版本号`进行安装指定版本的docker

## 三、yun离线安装docker

1. 首先下载docker 的rpm包`https://download.docker.com/linux/centos/7/x86_64/stable/Packages/`

   > 安装的过程中可能会遇到依赖的问题,请不要着急,一个一个的看好,去网上下载需要安装的依赖就可以了.

2. 使用命令`sudo yum install /path/to/package.rpm`

3. 启动docker`sudo systemctl start docker`

4. 查看docker 服务状态`sudo systemctl status docker`,如果状态是active说明是启动成功的



## 四、使用脚本安装docker

> 如果不想手动一步一步的安装的话,docker官方提供了脚本安装的方式,但是这种方式需要root的权限

1. 下载脚本`curl -fsSL get.docker.com -o get-docker.sh`
2. 运行脚本`sudo sh get-docker.sh`,跟着脚本一步一步的执行下去就可以了.感觉还是挺简单的.启动步骤跟上面的步骤是一样的,不再重复了.

## 五、卸载docker

1. yum 卸载`sudo yum remove docker-ce`

   > 这种方式不会删除配置文件等.

2. 删除镜像,容器等`sudo rm -rf /var/lib/docker`
