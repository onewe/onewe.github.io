---
title: jenkins与docker的简单使用
date: 2018/4/26 20:16:25
tags:
- jenkins
- docker
categories: jenkins
cover: https://gitee.com/oneww/onew_image/raw/master/jenkins_docker_cover.png
author: 
  nick: onew
  link: https://onew.me
subtitle: 本来jenkins安装就简单,使用docker的话岂不是更加easy??
---

# 一、pull jenkins 镜像

jenkins 镜像可以在docker厂库里面找到,选择靠谱的官方docker镜像,然后pull下来,为后面做准备.`docker pull jenkins` ,emmmmm好像这个镜像有点大,在国内的用户还是老老实实的用阿里的加速吧.不然下到绝望呀.



# 二、运行jenkins

镜像下载后,后面就简单了.只需要一条命令就可以让jenkins跑起来.`docker run -d  --name myjenkins -p 8080:8080 -p 50000:50000 -v /root/jenkins:/var/jenkins_home -u root jenkins`

解释一下这条命令的含义.

- \-d的意思的后台运行
- —name的意思给这个jenkins起个名称
- \-p的意思进行端口映射,把容器内部的8080端口和50000端口映射到宿主机上面去.
- \-v的意思是把容器的/var/jenkins_home目录映射到宿主机的/root/jenkins目录中去
- \-u的意思是以root的身份运行这个容器,避免遇到没有权限的问题

运行起来后就可以访问jenkins主页了,第一次访问jenkins的时候需要输入一个jenkins生产的临时密码.这个密码可以用`docker logs myjenkins`命令来查看容器运行的日志.  

![gOgFiJ](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/gOgFiJ.jpg)

ok.



# 三、配置nginx

如果需要方向代理的话,会有点麻烦.但是也有现场的配置抄.嘿嘿.注意的一点是,如果要配置域名的话,需要在jenkins中的系统配置里面修改jenkins URL 为域名.

下面的配置文件是配置http的.

```nginx
server {
    listen 80;
    server_name jenkins.domain.tld;
    return 301 https://$host$request_uri;
}
 
server {
 
    listen 80;
    server_name jenkins.domain.tld;
     
    location / {
 
      proxy_set_header        Host $host:$server_port;
      proxy_set_header        X-Real-IP $remote_addr;
      proxy_set_header        X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_set_header        X-Forwarded-Proto $scheme;
 
      # Fix the "It appears that your reverse proxy set up is broken" error.
      proxy_pass          http://127.0.0.1:8080;
      proxy_read_timeout  90;
 
      proxy_redirect      http://127.0.0.1:8080 https://jenkins.domain.tld;
  
      # Required for new HTTP-based CLI
      proxy_http_version 1.1;
      proxy_request_buffering off;
      # workaround for https://issues.jenkins-ci.org/browse/JENKINS-45651
      add_header 'X-SSH-Endpoint' 'jenkins.domain.tld:50022' always;
 
    }
  }
```

在贴一段https的ng配置文件

```nginx
upstream jenkins {
  server 127.0.0.1:8080 fail_timeout=0;
}
 
server {
  listen 80;
  server_name jenkins.domain.tld;
  return 301 https://$host$request_uri;
}
 
server {
  listen 443 ssl;
  server_name jenkins.domain.tld;
 
  ssl_certificate /etc/nginx/ssl/server.crt;
  ssl_certificate_key /etc/nginx/ssl/server.key;
 
  location / {
    proxy_set_header        Host $host:$server_port;
    proxy_set_header        X-Real-IP $remote_addr;
    proxy_set_header        X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header        X-Forwarded-Proto $scheme;
    proxy_redirect http:// https://;
    proxy_pass              http://jenkins;
    # Required for new HTTP-based CLI
    proxy_http_version 1.1;
    proxy_request_buffering off;
    proxy_buffering off; # Required for HTTP-based CLI to work over SSL
    # workaround for https://issues.jenkins-ci.org/browse/JENKINS-45651
    add_header 'X-SSH-Endpoint' 'jenkins.domain.tld:50022' always;
  }
}
```

只要对应的修改一下就ok了.



# 四、总结

配置nginx这个可算是把我给坑到了,因为我这个nginx前面还有个cdn,cdn能够过于掉一些无效的请求头,但jenkins又自定义了请求头.刚开始还不知道,捣腾了很久才发现,可谓是个坑了.
