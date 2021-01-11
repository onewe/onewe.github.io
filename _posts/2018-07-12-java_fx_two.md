---
title: javaFX 打包插件使用方法
date: 2018/7/12 16:56:25
tags:
- java
- javaFX
categories: java
cover: https://gitee.com/oneww/onew_image/raw/master/java_fx_one.png
author: 
  nick: onew
  link: https://onew.me
subtitle: 使用的IDEA的打包插件有点略坑,推荐使用maven插件javafx-maven-plugin,使用比较方便
---

# 一、前言

写了几天javaFX应用,也该写完,打包成应用了.在网上查了一下,大多数都是在介绍使用IDEA的打包方式,用了一下感觉有点略坑呀.反正我是没有成功打包成exe文件.接下来就轮到我们主角来了.一个maven的打包插件,配置可能会稍微麻烦点,但效果比IDEA好多了(IDEA我没打包成功过,可能是使用的姿势不对吧,如果有正确的姿势,请给我留言,谢谢昂).



# 二、进入主题

首先要安装这个插件的依赖软件,主要是用于打包的,总共两个软件一个是[WiX Toolset v3.11.1](https://github.com/wixtoolset/wix3/releases/tag/wix3111rtm)(注意:安装好以后把bin添加在环境变量中),另外一个是[Inno Setup](http://www.jrsoftware.org/isdl.php),安装好以后就配置一下POM 文件就可以了.pom文件配置如下

```xml
<plugin>
    <groupId>com.zenjava</groupId>
    <artifactId>javafx-maven-plugin</artifactId>
    <version>8.8.3</version>
    <configuration>
        <bundleArguments>
            <!-- 是否显示文件选择器 -->
            <installdirChooser>true</installdirChooser>
        </bundleArguments>
        <!-- 主类 -->
        <mainClass>com.zzwtec.face.Main</mainClass>
        <vendor>zzwtec-face-extract-tool</vendor>
         <!-- 调试模式 -->
        <verbose>true</verbose>
         <!-- 生成exe文件 -->
        <bundler>EXE</bundler>
         <!-- 是否生成桌面快捷方式 -->
        <needShortcut>true</needShortcut>
         <!-- 公司名称 -->
        <vendor>zzwtec</vendor>
         <!-- 应用程序名称 -->
        <appName>zzwtec-face-extract-tool</appName>
    </configuration>
</plugin>
```

简单吧,这样就配置好了.如果要配置程序的icon的话还需要配置一下.icon可以在pom中进行配置,也可以使用iss进行配置,这里就介绍使用iss来配置程序的icon以及安装器中的logo.首先要使用指定的iss必须要在main/deploy/package/windows 下面建立一个iss文件,这样插件打包的时候才会读取到iss文件.

![images](https://gitee.com/oneww/onew_image/raw/master/java_fx_two_iss_dir.png)



1. 配置iss文件

   可以抄一下我的这个iss文件,只要对其中几项参数稍作修改就可以使用.

   ```inno
   ;This file will be executed next to the application bundle image
   ;I.e. current directory will contain folder zzwtec-face-extract-tool with application files
   [Setup]
   AppId={{com.zzwtec.face}}
   AppName=zzwtec-face-extract-tool
   AppVersion=1.0
   AppVerName=zzwtec-face-extract-tool 1.0
   AppPublisher=zzwtec
   AppComments=zzwtec-face-extract-tool
   AppCopyright=Copyright (C) 2018
   ;AppPublisherURL=http://java.com/
   ;AppSupportURL=http://java.com/
   ;AppUpdatesURL=http://java.com/
   DefaultDirName={localappdata}\zzwtec-face-extract-tool
   DisableStartupPrompt=Yes
   DisableDirPage=NO
   DisableProgramGroupPage=Yes
   DisableReadyPage=Yes
   DisableFinishedPage=Yes
   DisableWelcomePage=Yes
   DefaultGroupName=zzwtec
   ;Optional License
   LicenseFile=
   ;WinXP or above
   MinVersion=0,5.1 
   OutputBaseFilename=zzwtec-face-extract-tool-1.0
   Compression=lzma
   SolidCompression=yes
   PrivilegesRequired=lowest
   SetupIconFile=zzwtec-face-extract-tool\zzwtec-face-extract-tool.ico  //文件ico
   UninstallDisplayIcon={app}\zzwtec-face-extract-tool.ico
   UninstallDisplayName=zzwtec-face-extract-tool
   WizardImageStretch=No
   WizardSmallImageFile=zzwtec-face-extract-tool-setup-icon.bmp    //安装器里面显示的logo
   ArchitecturesInstallIn64BitMode=x64
   
   
   [Languages]
   Name: "english"; MessagesFile: "compiler:Default.isl"
   
   [Files]
   Source: "zzwtec-face-extract-tool\zzwtec-face-extract-tool.exe"; DestDir: "{app}"; Flags: ignoreversion
   Source: "zzwtec-face-extract-tool\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
   
   [Icons]
   Name: "{group}\zzwtec-face-extract-tool"; Filename: "{app}\zzwtec-face-extract-tool.exe"; IconFilename: "{app}\zzwtec-face-extract-tool.ico"; Check: returnTrue()
   Name: "{commondesktop}\zzwtec-face-extract-tool"; Filename: "{app}\zzwtec-face-extract-tool.exe";  IconFilename: "{app}\zzwtec-face-extract-tool.ico"; Check: returnTrue()
   
   
   [Run]
   Filename: "{app}\zzwtec-face-extract-tool.exe"; Parameters: "-Xappcds:generatecache"; Check: returnFalse()
   Filename: "{app}\zzwtec-face-extract-tool.exe"; Description: "{cm:LaunchProgram,zzwtec-face-extract-tool}"; Flags: nowait postinstall skipifsilent; Check: returnTrue()
   Filename: "{app}\zzwtec-face-extract-tool.exe"; Parameters: "-install -svcName ""zzwtec-face-extract-tool"" -svcDesc ""zzwtec-face-extract-tool"" -mainExe ""zzwtec-face-extract-tool.exe""  "; Check: returnFalse()
   
   [UninstallRun]
   Filename: "{app}\zzwtec-face-extract-tool.exe "; Parameters: "-uninstall -svcName zzwtec-face-extract-tool -stopOnUninstall"; Check: returnFalse()
   
   [Code]
   function returnTrue(): Boolean;
   begin
     Result := True;
   end;
   
   function returnFalse(): Boolean;
   begin
     Result := False;
   end;
   
   function InitializeSetup(): Boolean;
   begin
   // Possible future improvements:
   //   if version less or same => just launch app
   //   if upgrade => check if same app is running and wait for it to exit
   //   Add pack200/unpack200 support? 
     Result := True;
   end;  
   
   ```

   上面配置文件中,只要把zzwtec-face-extract-tool  这个名称批量替换掉就可以了,不是很难.



# 三、总结

打包这个文件可谓是很是折腾呀,由于打包的时候把JRE也打包进来了,所以最终的exe文件很大,需要精简掉JRE,精简JRE也是个麻烦事,下次写篇博客介绍.
