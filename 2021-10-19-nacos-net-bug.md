---
title: nacos 客户端 bug 导致服务批量下线
date: 2021/10/19 09:29:12
tags:
- java
- nacos
categories: java
author: 
  nick: onew
  link: https://onew.me
subtitle: 大约是在凌晨,一个机房的服务全部下线.
---



# 一、前言

​	在某个凌晨,本来打算睡觉的时候.发现工作群里边的变得热闹了起来."服务挂了",“一个机房的服务全部挂了”,“网络问题吧.”好不热闹.心想反正不关我事,睡觉吧,猝死了可不好.

​	好巧不巧,第二天上班的时候,这个问题居然安排我去调查.倒霉了.

​	生产环境:

| Nacos-server | Nacos-client |      |
| ------------ | ------------ | ---- |
| 1.3.1        | 1.4.1        |      |

​	去案发现场看了一下,服务并没有挂,但在 nacos 控制里看服务却下线了.下线原因是没有发送心跳,超过15秒后,server 端就把这个服务给踢了.那么排查的方向就确定了,查一查 nacos 客户端为啥没有发送心跳.

​	简单的看了一下日志,发现没有心跳相关的错误.看来这个问题还得看看客户端的源码才能解决.



# 二、源码分析-发送心跳

![uaB3AZ](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/uaB3AZ.png)

​	发送心跳的核心代码就在 `BeatReactor` 类里,使用了一个 `ScheduledThreadPoolExecutor`  来定时发送心跳.如果没有发送心跳,也就意味着 `ScheduledThreadPoolExecutor`  没有任务运行.

​	![wbNy8c](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/wbNy8c.png)

​	这块代码是发送心跳的核心代码,如果说不继续发送心跳,那么只能是出现了未捕获的异常(非`NacosException`),导致没有走到 `executorService.schedule` 这句代码来.

​	翻来覆去找了一下,发现可能是解析 ip 地址判断是否是 ipv4 的时候报错.这个错误,nacos 是没有捕获到的,满足上面的推测.

![7ZyS3Z](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/7ZyS3Z.png)

![AxjD4j](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/AxjD4j.png)



# 三、问题复现

 	先来快速的搭建个环境吧. Nacos 官方提供了 nacos-server 构建 docker 镜像的教程. `https://nacos.io/zh-cn/docs/quick-start-docker.html` 根据官方的指南构建一个 1.3.1 的 nacos-server 镜像.

​	构建 nacos 1.4.1 和 1.42 版本的客户端,得整个 java 程序.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <groupId>org.example</groupId>
    <artifactId>nacos-naming-test</artifactId>
    <version>1.0-SNAPSHOT</version>

    <properties>
        <maven.compiler.source>8</maven.compiler.source>
        <maven.compiler.target>8</maven.compiler.target>
    </properties>

    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>2.2.5.RELEASE</version>
        <relativePath/>
    </parent>

    <dependencyManagement>
        <dependencies>
            <dependency>
                <groupId>com.alibaba.cloud</groupId>
                <artifactId>spring-cloud-alibaba-dependencies</artifactId>
                <!--      2.2.5使用的是 1.4.1          -->
                <!--      2.2.6使用的是 1.4.2          -->
                <version>2.2.6.RELEASE</version>
                <type>pom</type>
                <scope>import</scope>
            </dependency>
        </dependencies>
    </dependencyManagement>

    <dependencies>
        <dependency>
            <groupId>com.alibaba.cloud</groupId>
            <artifactId>spring-cloud-starter-alibaba-nacos-discovery</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>
    </dependencies>

    <build>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
            </plugin>
        </plugins>
    </build>

</project>
```

​	java 代码

```java
package org.example;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cloud.client.discovery.EnableDiscoveryClient;

@SpringBootApplication
@EnableDiscoveryClient
public class Application {

    public static void main(String[] args) {
        SpringApplication application = new SpringApplication(Application.class);
        application.run(args);
    }


}

```

​	Dockerfile

```dockerfile
FROM openjdk:8u302-jdk
ADD nacos-naming-testjar .
CMD ["java","-jar","nacos-naming-test.jar"]
```

​	构建 2 个版本,一个版本使用的是 1.4.1 另一个版本是 1.4.2

​	编写 docker-compose.yaml

```yaml
version: '3.3'

services:
  nacos-server:
    image: nacos/nacos:${NACOS_SERVER_VERSION}
    container_name: nacos
    env_file:
      - ./env/nacos-standlone-mysql.env
    ports:
      - "8848:8848"
      - "9848:9848"
      - "9555:9555"
    depends_on: 
      - mysql
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8848/nacos/"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
  mysql:
    container_name: mysql
    image: nacos/nacos-mysql:5.7
    env_file:
      - ./env/mysql.env
    ports:
      - "3306:3306"
  nacos-naming-test:
    image: nacos-naming-test:v1.1.0
    deploy:
      mode: replicated
      replicas: 3
    depends_on:
      nacos-server:
        condition: service_healthy
```

​	模拟网络的波动,可以通过启停 nacos-server 来达到预期的效果.通过验证 1.4.2 版本的客户端是没有问题的,在 nacos-server 重启之后能够重新注册上服务,但 1.4.1 版本的客户端却不可以.


