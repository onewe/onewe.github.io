---
title: 关于JFinal与kisso集成使用心得
date: 2018/4/24 22:10:34
comments: true
tags: 
- java
- jfinal
categories: java
cover: https://gitee.com/oneww/onew_image/raw/master/jfinal_kisso_cover.png
author: 
  nick: onew
  link: https://onew.me
subtitle: 关于JFinal与kisso集成使用心得,这篇文章原来是在csdn的,还是迁移过来吧!
---



# 关于JFinal与kisso集成使用心得

 

## 一. JFinal简介

	 什么是JFinal?这里引用官方的介绍。
	 JFinal 是基于 Java 语言的极速 WEB + ORM 框架，其核心设计目标是开发迅速、代码量少、学习简单、功能强大、轻量级、易扩展、Restful。在拥有Java语言所有优势的同时再拥有ruby、python、php等动态语言的开发效率！为您节约更多时间，去陪恋人、家人和朋友 :)

## 二、 kisso简介

	 说道kisso，我们先来看看什么是sso，SSO英文全称Single Sign On，单点登录。SSO是在多个应用系统中，用户只需要登录一次就可以访问所有相互信任的应用系统。它包括可以将这次主要的登录映射到其他应用中用于同一个用户的登录的机制。它是目前比较流行的企业业务整合的解决方案之一。那么sso实现原理又是什么呢?(盗用一张图,嘿嘿)  
	 ![images](https://gitee.com/oneww/onew_image/raw/master/jfinal_kisso_sso.gif)
	 上图一个系统中集成了3个应用系统，为了用户的使用方便我们就要达到一种，用户登陆系统一次就可以不用在登陆其他子系统的效果。这样做有哪些好处呢？第一，为了方便，提高效率；第二，增强安全性，避免用户出现多个系统的账号密码丢失问题。
	 传统的sso的缺点，从上图我们看出，每次登陆请求验证都在集中在一个系统上，这样做的缺点就是给认证系统服务器带来很大的压力。如果换做是kisso的话，就不必集中在一个认证系统上进行校验了，这样就解决了上述的问题(kisso在跨域的时候还是集中的。嘿嘿)。

## 三. kisso实现原理

	在web应用中，我们相互通信的协议都是http协议的，http协议是一种无状态的协议。那么怎样做才能知道用户的状态呢？？由于http协议是无状态协议的，所以单凭http协议是无法办到的。这里我们就要借助cookie机制，cookie可以保存用户的一些信息，这样用户每次发送请求过来我们就可以知道用户是否登陆了。如果就单纯的用cookie的话，又会面临着cookie被盗用的风险。但这个问题都不是问题，在保存cookie的时候，把cookie与用户的ip登陆的ip地址进行绑定，在与用户登陆的时候使用的浏览器信息进行绑定等等，再把这些信息进行加密，我想安全性就不用多做考虑了吧。

## 四、 kisso与jfianl整合

	  先下载jar，附上POM
	  

```xml
  <!--jfianl核心jar-->
        <!-- https://mvnrepository.com/artifact/com.jfinal/jfinal -->
        <dependency>
            <groupId>com.jfinal</groupId>
            <artifactId>jfinal</artifactId>
            <version>2.2</version>
        </dependency>
 <!--单点登陆-->
        <dependency>
            <groupId>com.baomidou</groupId>
            <artifactId>kisso</artifactId>
            <version>3.6.13</version>
        </dependency>

```
使用kisso一共有三种方法，这里我们就使用jfianl插件的方式，其余的方式请参考官方文档。jfinal插件代码

```Java
package com.withub.demo.plugin;

import com.baomidou.kisso.web.WebKissoConfigurer;
import com.jfinal.plugin.IPlugin;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Created by Administrator on 2016/12/26 0026.
 */
public class KissoJFinalPlugin implements IPlugin{
    private static final Logger logger = LoggerFactory.getLogger(KissoJFinalPlugin.class);
    //开始
    @Override
    public boolean start() {
        /*进行初始化*/
        WebKissoConfigurer webKissoConfigurer = new WebKissoConfigurer("sso.properties");
        webKissoConfigurer.setRunMode("test_mode");
        webKissoConfigurer.initKisso();
        logger.info("插件初始化完成!");
        return true;

    }
    //结束
    @Override
    public boolean stop() {
        logger.info("插件销毁!");
        return true;
    }


}

```

上面的代码很简单，大致的意思就是使用sso.properties进行初始化。sso.properties配置如下。

```properties
sso.production.mode 模式配置，默认不带后缀为线上模式，
模式设置：dev_mode 开发 ，_test_mode 测试 ，online_mode 生产

sso.encoding 编码格式： 默认 UTF-8

sso.secretkey 加密密钥

------ cookie 设置部分 ------
sso.cookie.secure 是否只能HTTPS访问，默认 false
sso.cookie.httponly 是否设置 httponly脚本无法访问，默认 true
sso.cookie.maxage 过期时间，默认 -1 关闭浏览器失效
sso.cookie.name 名称，默认 uid
sso.cookie.domain 所在域，请设置根域，如 .baomidou.com
sso.cookie.path 路径，默认 /
sso.cookie.browser 是否检查浏览器，默认 true
sso.cookie.checkip 是否检查登录IP，默认 false
sso.encrypt.class 自定义对称加密类，默认AES，自定义例如：com.testdemo.DES
sso.token.class 自定义票据，默认SSOTokwn，自定义例如：com.testdemo.LoginToken

------ Token 缓存部分 ------
sso.tokencache.class 自定义缓存实现：com.testdemo.RedisCache
sso.tokencache.expires 单位s秒，设置 -1永不失效，大于 0 失效时间

------ SSO 请求地址设置 ------
sso.login.url_online_mode 线上模式，登录地址：http://sso.testdemo.com/login.html
sso.login.url_dev_mode 开发模式，登录地址：http://localhost:8080/login.html

sso.logout.url_online_mode 线上模式，退出地址：http://sso.testdemo.com/logout.html
sso.logout.url_dev_mode 开发模式，退出地址：http://localhost:8080/logout.html

sso.param.returl 重定向地址参数配置，默认：ReturnURL

------ 跨域 cookie 设置部分 ------
sso.crossdomain.cookie.name 名称pid，请不要与登录 cookie 名称一致
sso.crossdomain.cookie.maxage 过期时间，默认 -1 关闭浏览器失效
```
这里我们简单配置一下即可

```properties
################ SSOConfig file #################
sso.secretkey=h2wmABdfM7i3K801my
sso.cookie.name=uid
sso.cookie.domain=.test.com
# Default RC4 , You can choose [ DES , AES , BLOWFISH , RC2 , RC4 ]
#sso.encrypt.algorithm=BLOWFISH
sso.login.url=http://sso.test.com:8080/login


```
注意这里我们domain写的是.test.com，相应的我们要更改host文件(windows条件下)。
编写jfinal拦截器，用于拦截请求，并验证用户是否登陆。代码如下

```Java
package com.withub.demo.interceptor;

import com.baomidou.kisso.SSOConfig;
import com.baomidou.kisso.SSOHelper;
import com.baomidou.kisso.Token;
import com.baomidou.kisso.web.interceptor.KissoAbstractInterceptor;
import com.jfinal.aop.Interceptor;
import com.jfinal.aop.Invocation;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;

/**
 * Created by Administrator on 2016/12/26 0026.
 */
public class SSOJFinalInterceptor extends KissoAbstractInterceptor implements Interceptor{
    private static final Logger log = LoggerFactory.getLogger(SSOJFinalInterceptor.class);

    @Override
    public void intercept(Invocation invocation) {
        log.info("开始拦截!验证登陆.");
        HttpServletRequest request = invocation.getController().getRequest();
        HttpServletResponse response = invocation.getController().getResponse();
        Token token = SSOHelper.getToken(request);

        if(token == null){
            if("XMLHttpRequest".equals(request.getHeader("X-Requested-With"))){
                //处理ajax请求
                //如果未认证返回401
                getHandlerInterceptor().preTokenIsNullAjax(request,response);
                log.info("拦截ajax请求.处理中.....");
            }else if("APP".equals(request.getHeader("PLATFORM"))){
                //采用ajax处理方式
                getHandlerInterceptor().preTokenIsNullAjax(request,response);
                log.info("处理APP请求!");
            }else{
                //普通请求
                try {
                    log.info("拒绝请求:"+request.getRequestURI());
                    SSOHelper.clearRedirectLogin(request,response);
                } catch (IOException e) {
                    e.printStackTrace();
                }
            }

        }else{
            /*
			 * 正常请求，request 设置 token 减少二次解密
			 */
            request.setAttribute(SSOConfig.SSO_TOKEN_ATTR,token);
            invocation.invoke();
        }
    }


}


```

上面对于是ajax请求和app发过来的请求采用统一的处理策略。上面的意思是，如果用户发过来的请求中能拿到token那么就代表用户登陆过，就放行请求，并把token放入到request域中去。如果拿不到token就代表用户没用登陆过，对于不同的请求类型有不同的处理方式，这里为了简单ajax和app发过来的请求统一采用ajax策略进行处理。如果就是普通的请求的话，就跳转到登陆页面去。我们来看看登陆页面的控制器。

```Java
package com.withub.demo.controller;

import com.baomidou.kisso.SSOHelper;
import com.baomidou.kisso.SSOToken;
import com.baomidou.kisso.Token;
import com.baomidou.kisso.common.IpHelper;
import com.baomidou.kisso.common.util.HttpUtil;
import com.baomidou.kisso.web.waf.request.WafRequestWrapper;
import com.jfinal.core.Controller;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.UUID;

/**
 * Created by Administrator on 2016/12/26 0026.
 */
//登陆不用拦截
public class LoginController extends Controller {

    private static final Logger log = LoggerFactory.getLogger(LoginController.class);

    public void index(){
        Token token = SSOHelper.getToken(getRequest());

        //令牌不为空,让用户直接访问主页,免登陆.
       if(token != null){
           redirect("/");
           return;
       }
        //判断是否是POST提交
        if(HttpUtil.isPost(getRequest())){
           //包装request请求
            WafRequestWrapper wafRequestWrapper = new WafRequestWrapper(getRequest());
            String name = wafRequestWrapper.getParameter("name");
            String password = wafRequestWrapper.getParameter("password");
            //验证账号密码,此处暂时不用去数据库校验
            if("test".equals(name) && "test".equals(password)){
               token = new SSOToken();
               token.setUid(UUID.randomUUID().toString());
               token.setIp(IpHelper.getIpAddr(getRequest()));
               token.setId(UUID.randomUUID().toString());
               //保存token立即销毁信任的JSESSIONID
               SSOHelper.setSSOCookie(getRequest(),getResponse(),token,true);
               redirect("/index.html");
               return;
            }


        }

        render("/login.html");

    }



}

```
首先我们先尝试获取token看能不能拿到token,如果能拿到token就说明登陆了，就可以直接调到主页去，这样就免登陆了。如果没有拿到token的话，就代表用户没有进行登陆，用户需要进行登陆才能继续访问。首先先判断请求是否是post请求，因为一般登陆都是post请求。让后校验账号密码，这里就没有连接数据库进行校验。校验通过生产一个新的token，并保存为cookie，再跳转页面。
	需要拦截的控制器，代码如下，
	

```Java
package com.withub.demo.controller;

import com.baomidou.kisso.SSOHelper;
import com.baomidou.kisso.Token;
import com.jfinal.aop.Before;
import com.jfinal.core.Controller;
import com.withub.demo.interceptor.SSOJFinalInterceptor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Created by Administrator on 2016/12/24 0024.
 */

@Before(SSOJFinalInterceptor.class)
public class IndexController extends Controller {
    private static final Logger log = LoggerFactory.getLogger(IndexController.class);
    public void index(){
        log.info("进入主页!");
        //从request中拿到token
        Token token = SSOHelper.attrToken(getRequest());
        if(token != null){
            log.info("登陆令牌UID"+token.getUid());
            log.info("登陆令牌IP地址"+token.getIp());
            render("index.html");
            return;
        }
        render("login.html");
    }


}

```
这里使用了jfinal的注解表示拦截这个controller，在controller执行之前进行拦截。这里的拦截器就是我们前面写的拦截器。
	完成以上步奏我们就可以打开浏览器验证了。
	![images](https://gitee.com/oneww/onew_image/raw/master/jfinal_kisso_validation.png)
	
进行登陆。
![images](https://gitee.com/oneww/onew_image/raw/master/jfinal_kisso_success.png)
登陆成功以后就出现了cookie，后面在访问就不需要登陆了！
以上就完成了简单的整合



