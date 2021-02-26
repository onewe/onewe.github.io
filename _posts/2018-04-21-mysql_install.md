---
title: 尝鲜 Mysql 8.0的初体验
date: 2018/4/21 23:30:29
tags: mysql 8.x
categories: mysql
cover: https://gitee.com/oneww/onew_image/raw/master/mysql_cover.jpg
author: 
  nick: onew
  link: https://onew.me
subtitle: 踩坑,尝试一下mysql8.x,不知道安装的时候有何不同.
---

# 尝鲜 Mysql 8.0的初体验



## 一、Mysql 8.x的新特性

近期mysql更新了一个新版本8.x,主要更新了哪些特性呢?

- 对Unicode 9.0的开箱即用的完整支持
- 支持窗口函数和递归SQL语法，这在以往是不可能或者很难才能编写这样的查询语句
- 对原生JSON数据和文档存储功能的增强支持MySQL 8.0的发布.由于6.0修改和7.0是用来保留做MySQL的集群版本，因此采用了8.0的版本号。
- 在锁定行方面增加了更多选项，如SKIP LOCKED和NOWAIT两个选项。其中，
  SKIP LOCKED允许在操作中不锁定那些需要忽略的行；NOWAIT则在遇到行的锁定的时候马上抛出错误。
- MySQL能根据可用内存的总量去伸缩扩展，以更好利用虚拟机的部署。
- 新增“隐藏索引”的特性，这样索引可以在查询优化器中变为不可见。索引在标记为不可用后，和表的数据更改同步，但是优化器不会使用它们。对于使用隐藏索引的建议，是当不决定某个索引是否需要保留的时候，可以使用。



## 二、下载Mysql 8.x

1. 打开官网https://www.mysql.com/downloads 选择MySQL Community Edition 版
2. 选择操作系统,这里选择Redhat 7.x的全家桶版本!![ulVdl6](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/ulVdl6.jpg)



## 三、安装Mysql

1. 上传安装包到服务器.  ![xGifcX](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/xGifcX.jpg)

2. 解压压缩包`mkdir mysql && tar -xvf mysql-8.0.11-1.el7.x86_64.rpm-bundle.tar -C ./mysql`该命令会把压缩包解压到当前目录下的mysql目录下.  ![uyCC1b](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/uyCC1b.jpg)  

   ![kB90jp](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/kB90jp.jpg)  

3. 安装mysql

   1. 为了保险起见先关闭防火墙`systemctl stop firewalld`
   2. 关闭SE linux`setenforce 0`
   3. 卸载mariadb-libs`yum remove mariadb* -y && yum clean all`
   4. 安装openssl `yum install openssl-*`
   5. 安装net-tools `yum install net-tools`
   6. 安装common模块`rpm -ivh mysql-community-common-8.0.11-1.el7.x86_64.rpm`
   7. 安装libs模块`rpm -ivh mysql-community-libs-8.0.11-1.el7.x86_64.rpm`
   8. 安装libs-compat模块 `rpm -ivh mysql-community-libs-compat-8.0.11-1.el7.x86_64.rpm`
   9. 安装devel 模块`rpm -ivh mysql-community-devel-8.0.11-1.el7.x86_64.rpm`
   10. 安装client模块`rpm -ivh mysql-community-client-8.0.11-1.el7.x86_64.rpm`
   11. 安装server模块 `rpm -ivh mysql-community-server-8.0.11-1.el7.x86_64.rpm`

4. 启动mysql服务

   1. 启动服务`systemctl start mysqld`

   2. 检查服务是否启动成功`systemc status mysqld.`  ![JuJhW4](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/JuJhW4.jpg)  

   3. 启动成功后,mysql会默认生成root密码,可以在启动日志中查看`cat /var/log/mysqld.log.`  ![img](https://gitee.com/oneww/onew_image/raw/master/mysql_password.png)  

   4. 尝试登陆`mysql -uroot -p`输入刚才生成密码.  ![FxqonP](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/FxqonP.jpg)

   5. 由于刚才生成的密码只是mysql的临时密码,所以需要重新设置root密码,不然操作mysql会出错误提示,并拒绝操作. ![VMimrI](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/VMimrI.jpg)`ERROR 1820 (HY000): You must reset your password using ALTER USER statement before executing this statement.`提示必须重置用户密码.  

   6. 重置密码

      `ALTER USER 'root'@'localhost' IDENTIFIED BY 'test110119';`使用这句语句来重置密码,但可能会收到一个安全策略引起的错误提示`Your password does not satisfy the current policy requirements`该错误的意思,密码太简单了.![Ai3LWR](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/Ai3LWR.jpg)  ![images](https://gitee.com/oneww/onew_image/raw/master/mysql_week_password.png)

      密码设置复杂点就ok了.也可以修改安全策略(validate_password_policy),validate_password_policy有以下几个值可以参考. 

      | Policy          | Tests Performed                                              | comment                                        |
      | --------------- | ------------------------------------------------------------ | ---------------------------------------------- |
      | `0` or `LOW`    | Length                                                       | 必须符合长度                                   |
      | `1` or `MEDIUM` | Length; numeric, lowercase/uppercase, and special characters | 必须符合长度,包含数字,大小写,特殊字符          |
      | `1` or `MEDIUM` | Length; numeric, lowercase/uppercase, and special characters; dictionary file | 必须符合长度,包含数字,大小写,特殊字符,字典文件 |

      validate_password_policy 默认值为1,如果要重置可以使用`set global validate_password_policy=0`,改为0,密码就只校验长度了.笔者这里不选择修改策略的方式,而是采用复杂的密码.  ![u2adMY](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/u2adMY.jpg)

      

## 四、远程登录

安装好mysql之后发现能够在本地登录,不能远程登录.这是因为mysql限制了root用户的远程登录的权限,稍作修改就好.远程访问一般有两种方法,一种是改表法,另外一种是授权法.改表法,比较简单,只要把mysql中的user表root用户的host改为%就ok了

1. 切换数据库`use mysql;`
2. 修改user表`update user set host = '%' where user='root';`
3. 重启mysql`systemctl restart mysqld`
4. Ok 搞定

# 总结

linux安装mysql的时候,依赖比较复杂安装的时候一定要注意.如果使用客户端连接不上并提示`Authentication plugin 'caching_sha2_password' cannot be loaded: dlopen(/usr/local/mysql/lib/plugin/caching_sha2_password.so, 2): image not found `的话,重新修改密码的加密方式就可以,或者客户端支持`sha2`的加密方式.修改密码加密方式:`ALTER USER 'root'@'%' IDENTIFIED WITH mysql_native_password BY 'root'; `