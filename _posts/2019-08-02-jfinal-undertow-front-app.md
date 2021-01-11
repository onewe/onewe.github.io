---
title: jfinal undertow前后端分离配置
date: 2019/08/02 10:10:34
comments: true
tags: 
- java
- jfinal
categories: java
cover: https://www.jfinal.com/assets/img/jfinallogo.png
author: 
  nick: onew
  link: https://onew.me
subtitle: 在有些情况下,需要使用到前后端分离,但是..部署的环境又不给使用nginx
---

# 一、前言

在做项目的时候,本公司这边是使用的前后端分离.部署的时候使用nginx代理前端.但遇到一个比较特殊情况,改服务器上只能装java 和 数据库.哦豁..于是就想着怎么在jfinal 这边搞个前后端分离来解决当前的问题.

# 二、jfinal解决方案

- 增加前端路由

  ```java
  public class FrontController extends Controller {
  
      public void index(){
  
          render("index.html");
      }
  }
  ```

  这个代码很简单,只要返回index.html就可以了.

- 增加Handler

  ```java
  public class ApiHandler extends Handler {
  
      private static final Pattern PATTERN = Pattern.compile("^/api/.*");
      private static final Pattern STATIC_PATTERN = Pattern.compile(".*\\.(gif|jpg|png|js|css|pdf|doc|docx|zip|lrm|lrmx|hzb|xls)$");
  
  
      @Override
      public void handle(String target, HttpServletRequest request, HttpServletResponse response, boolean[] isHandled) {
  
          if(PATTERN.matcher(target).matches()){
              target = target.replaceFirst("/api/","/");
              if(STATIC_PATTERN.matcher(target).matches()){
                  try {
                      response.sendRedirect(target);
                  } catch (IOException e) {
                      e.printStackTrace();
                      LogKit.error("转发异常!",e);
                  }
                  return;
              }
              next.handle(target, request, response, isHandled);
          }else if(STATIC_PATTERN.matcher(target).matches()){
              return;
          }else{
              target = "/";
              next.handle(target, request, response, isHandled);
          }
  
      }
  }
  ```

  这个apihandler的意思是如果请求地址带了`api`前缀则重写target 地址,把target中的`api`前缀给替换掉,这样就可以去映射到jfinal中的action.

  如果请求是的静态资源,并且还带了`api`前缀则,重定向到没有`api`前缀的url地址上去.

  以上条件都不满足的话,则到前端路由上去.

# 三、undertow解决方案

如果使用了undertow版本的jfinal,那么还有一招可以解决.

- 继承`UndertowServer`类,并重写`configHandler`方法

  ```java
  public class UndertowExtServer extends UndertowServer {
  
      protected UndertowExtServer(UndertowConfig undertowConfig) {
          super(undertowConfig);
      }
  
      @Override
      protected HttpHandler configHandler(HttpHandler next) {
          return Handlers.predicates(PredicatedHandlersParser.parse("regex['/api/upload/(.*)'] -> rewrite['/upload/${1}']\n regex['/api/file/(.*)'] -> rewrite['/file/${1}']",getClass().getClassLoader()),next);
      }
  
      public static UndertowExtServer create(Class<? extends JFinalConfig> jfinalConfigClass) {
          return new UndertowExtServer(new UndertowConfig(jfinalConfigClass));
      }
  
      public static UndertowExtServer create(String jfinalConfigClass) {
          return new UndertowExtServer(new UndertowConfig(jfinalConfigClass));
      }
  
      @Override
      public UndertowExtServer configWeb(Consumer<WebBuilder> webBuilder) {
          this.webBuilder = webBuilder;
          return this;
      }
  }
  ```

  关键在于`"regex['/api/upload/(.*)'] -> rewrite['/upload/${1}']\n regex['/api/file/(.*)'] -> rewrite['/file/${1}']"`这句代码,通过正则表达式的方式,去匹配url,然后rewrite url,达到前后端分离的效果,但是这种办法还是要在jfinal中增加一个前端路由.

# 四、总结

以上就是两种解决方案,结合起来使用更爽哟!如果小伙伴有其他的解决方案,请留言给我,谢谢啦.
