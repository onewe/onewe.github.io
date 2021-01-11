---
title: Mac OS X打包Redis Desktop Manager(RDM)
date: 2018/8/27 16:47:25
tags:
- RDM package
- qt RDM
categories: mac
cover: https://gitee.com/oneww/onew_image/raw/master/redis-desktop-manager-cover.jpg
author: 
  nick: onew
  link: https://onew.me
subtitle: 前面写了,如何编译Redis Desktop Manager和编译crashreporter,编译好了就差打包了(填前面的坑).
---



# 前言

> 编译好Redis Desktop Manager 之后,本机电脑是可以跑的,但是其他电脑就不一定能跑了,因为有些依赖在其他电脑上不一定有,或者路径不一样,这时,我们就需要把依赖打入到app中.



## 第一步,编译Redis Desktop Manager

编译好Redis Desktop Manager ,这个是大前提,如果不知道怎么编译的同学可以参考我的另一篇文章 [Mac OS X下编译Redis Desktop Manager(RDM)](https://onew.me/2018/03/29/mac-compile-RDM/).

## 第二步,分析目录结构

编译好的app,其实在mac上面是个以.app结尾的目录.其结构如下,(为了减少篇幅,省略了一些目录)

```c
/*
rdm.app
└── Contents
    ├── Frameworks #依赖
    │   └── Breakpad.framework
    │       ├── Breakpad -> Versions/Current/Breakpad
    │       ├── Breakpad.framework -> /Users/doge/project/rdm/bin/Frameworks/Breakpad.framework
    │       ├── Headers -> Versions/Current/Headers
    │       ├── Resources -> Versions/Current/Resources
    │       └── Versions
    │           └── Current -> A
    ├── Info.plist 
    ├── MacOS
    │   ├── logs # 日志
    │   │   └── myeasylog.log
    │   └── rdm #核心文件,是一个可执行文件
    ├── PkgInfo
    └── Resources # 资源
        ├── empty.lproj
        └── rdm.icns
*/
```

编译好后,这个app在本机运行是没问题的,但是要移植到其他机器去,就需要把依赖copy进来,但是单纯copy是行不通,还是需要遵循点规则.



## 第三步,依赖分析

通过前面第二步的目录分析,可以知道rdm.app 这个目录里面核心文件是rdm 这个二进制文件.在mac上可以使用otool 这个命令`otool -L rdm.app/Contents/MacOS/rdm`进行依赖分析.rdm依赖如下(精简了一下,免得太多了):

```c
/*
rdm.app/Contents/MacOS/rdm:
	/usr/lib/libz.1.dylib (compatibility version 1.0.0, current version 1.2.11)
	/usr/local/opt/openssl/lib/libssl.1.0.0.dylib (compatibility version 1.0.0, current version 1.0.0)
	/usr/local/opt/openssl/lib/libcrypto.1.0.0.dylib (compatibility version 1.0.0, current version 1.0.0)
	@executable_path/../Frameworks/Breakpad.framework/Versions/A/Breakpad (compatibility version 1.0.0, current version 1.0.0)
	/usr/lib/libc++.1.dylib (compatibility version 1.0.0, current version 400.9.0)
	/usr/lib/libSystem.B.dylib (compatibility version 1.0.0, current version 1252.50.4)

*/
```

可以看到rdm依赖了openssl这个第三方库:

```c
/*
/usr/local/opt/openssl/lib/libssl.1.0.0.dylib (compatibility version 1.0.0, current version 1.0.0)
	/usr/local/opt/openssl/lib/libcrypto.1.0.0.dylib (compatibility version 1.0.0, current version 1.0.0)
*/
```

需要把这两个dylib文件放入到rdm.app目录中.可以在rdm.app中建立一个lib文件夹,然后在把依赖的这两个文件copy到lib文件夹中.

但这样copy是不起作用的,rdm还是会去`/usr/local/opt/openssl/lib`这个目录中去找依赖,所以需要把这个目录给改掉.改路径就需要使用工具`install_name_tool`.

这里说一下`@executable_path`指的是二进制文件的目录,也就是说在rdm.app中`@executable_path`等于`rdm.app/Contents/MacOS`这个路径.借助`@executable_path`把路径改到之前建立的目录lib上,命令如下:

`install_name_tool -change "/usr/local/opt/openssl/lib/libssl.1.0.0.dylib" "@executable_path/../lib/libssl.1.0.0.dylib" rdm.app/Contents/MacOS/rdm`

用这个命令,分别把libssl.1.0.0.dylib,libcrypto.1.0.0.dylib的目录给改掉.

ok,到这里已经完成一大半,还有一个地方需要注意,如果`libssl.1.0.0.dylib,libcrypto.1.0.0.dylib`这两个文件又分别依赖其他文件,还需要手动改一下(好麻烦呀,不知道有没有什么便捷的方法).不幸的是`libssl.1.0.0.dylib`这个文件依赖`libcrypto.1.0.0.dylib`,所以还需要按照上面的步骤,在改一下.



## 第三步,打包

qt提供了`macdeployqt`这个打包工具,打包还是很方便的,命令如下:

`sudo ~/Qt5.9.6/5.9.6/clang_64/bin/macdeployqt rdm.app -qmldir=/Users/doge/project/rdm/src/qml -dmg`

该命令执行后会往ram.app目录中加入qt相关的依赖等.最后会生成一个dmg文件.ok,到此打包就完成了.



# 总结

对于一个没怎么接触过QT的人,打包还是挺蛋疼的(疼死我了).打包后最好本地测试一下,看看能不能跑,如果不能跑,就手动执行一下二进制文件,看看报的什么错,然后找google,相信你遇到的问题都会迎刃而解!
