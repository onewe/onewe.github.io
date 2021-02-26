---
title: Let's Encrypt申请通配符域名  
date: 2018/3/29 16:39:25  
tags: Let's Encrypt  
categories: https  
cover: https://upload-images.jianshu.io/upload_images/8958298-8a3f7dc049e8061d.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240
author: 
  nick: onew
  link: https://onew.me
subtitle: 这年头没个https,谷歌火狐都不认你了.
---
# Let's Encrypt 子域名统配证书申请
> 终于等来了Let's Encrypt通配符证书了,看到这里泪流满面o(*￣︶￣*)o,那我们来尝尝鲜吧.

## 申请
- 下载certbot-auto  
	- `wget https://dl.eff.org/certbot-auto`
- 赋予可执行的权限
	- `chmod +x certbot-auto`
- 申请证书
	- ` ./certbot-auto certonly  -d *.onew.me --manual --preferred-challenges dns --server https://acme-v02.api.letsencrypt.org/directory`
	- tip: -d 参数后面更上域名 这里我们加上通配符,这里我们采用的验证方式是dns验证方式.
- 接下来跟着提示往下走就可以了,最后一步记住证书的位置就可以了.

## 配置nginx
有了证书我们需要配置一下nginx,才能使证书生效.  

```
	
	server {
	    	  	  server_name onew.me;
	    		  location / {
	                        root /root/web/public;
	                        index index.html;
	      			  }
	            listen 443 ssl; # managed by Certbot
	            ssl_certificate /etc/letsencrypt/live/onew.me-0001/fullchain.pem;
	            ssl_certificate_key /etc/letsencrypt/live/onew.me-0001/privkey.pem;
	            ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; 
	            include /etc/letsencrypt/options-ssl-nginx.conf;        
         }
        
```
重启nginx 就行了

## 刷新证书
Let's Encrypt 的证书是会过期的,一般是3个月,到期了我们就要重新申请,这里我们写个定时任务来重新申请就好了.
- 添加定时任务 `crontab -e`
- 添加执行脚本 `* * * */3 *  root  /root/certbot-auto renew --quiet`



## 总结

申请过程还是挺简单的,使用nginx的话,可以使用certbot的nginx 插件进行自动配置,使用起来也很简单.只不过要预先下载好这个插件.`yum install certbot-nginx -y`  安装好以后使用`certbot --nginx`进行自动配置,每一步都有提示的.

