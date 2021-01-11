---
title: mac下配置v2ray开机自启动
date: 2018/3/29 16:39:25
tags: v2ray
categories: mac
cover: https://gitee.com/oneww/onew_image/raw/master/mac_vim_cover.png
author: 
  nick: onew
  link: https://onew.me
subtitle: 手动启动?不纯在的,开机就跑起来.让你忘记代理的存在.
---
# mac开机启动v2ray
> 由于系统的问题,开不了机,所以重装了系统.记录下倒腾v2ray开启启动的过程

mac os的开机启动项有很多种,再次记录一下利用LaunchAgents来达到启动程序的目的


## 第一步,先编写plist文件
```
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
        <key>KeepAlive</key> //保持后台运行
        <true/>
        <key>Label</key>
        <string>com.doge.v2ray</string> //名称,这里的名称最好与文件名一致
        <key>Program</key>
        <string>/Users/doge/v2ray/v2ray-v3.14-macos/v2ray</string>//执行文件的路径
        <key>RunAtLoad</key>
        <true/>
        <key>UserName</key>//用户名
        <string>doge</string>
</dict>
</plist>
```

## 第二步,复制文件
- 检查  
    在复制文件之前,使用命令检查一下,文件是否正确`plutil com.doge.v2ray.plist`  
- 复制  
    把刚才编写好的plist文件复制到`~/Library/LaunchAgents/` 目录中去,使用命令`cp com.doge.v2ray.plist ~/Library/LaunchAgents/`  
- 加载  
    加载plist文件`launchctl load ~/Library/LaunchAgents/com.doge.v2ray.plist `
- 确认  
    确认文件是否被加载,命令`launchctl list | grep com.doge`

## 第三步,重启确认
重启系统查看是否生效.这里推荐Chrome浏览器的一个插件SwitchyOmega,配置代理十分方便.done
