---
title: 使用postgresql 中文分词
date: 2019/3/19 10:15:29
tags: postgresql zhparser
categories: postgresql
cover: https://gitee.com/oneww/onew_image/raw/master/postgresql-cover.png
author: 
  nick: onew
  link: https://onew.me
subtitle: 记录一下postgresql中文分词操作
---

# 一、前言

在postgresql中有个比较骚的功能全文索引,这个功能虽然比不上搜索引擎,但简单的需求还是能够满足的.由于国内大多都需要进行中文进行检索,所以需要给postgresql安装一个中文分词的插件.目前中文分词的插件有jieba、zhparser,推荐使用zhparser,安装比较简单.



# 二、开始

- 环境:
  - 系统: centos7
  - postgresql: 11

安装gcc:

`yum install -y gcc`

安装g++:

`yum install -y gcc-c++`

安装wget:

`yum install -y wget`

安装clang:

```sh
yum install -y centos-release-scl
yum install -y llvm-toolset-7
yum install -y devtoolset-7
#启用llvm-toolset-7
scl enable llvm-toolset-7 bash
```

安装postgresql依赖:

```shell
 yum install -y postgresql11-libs 
 yum install -y postgresql11-devel
```

 安装SCWS:

```shell
wget -q -O - http://www.xunsearch.com/scws/down/scws-1.2.3.tar.bz2 | tar xf -
cd scws-1.2.3 ; ./configure ; make install
```

下载zhparser源码:

```shell
git clone https://github.com/amutu/zhparser.git
```

编译和安装zhparser:

```shell
make PG_CONFIG=/usr/pgsql-11/bin/pg_config && make install
#PG_CONFIG 为pgsql的安装路径
```

以上zhpraser就安装完毕了,可能会遇到llvm的环境问题,只需要按照报错信息建立软链接就好.

下面开始测试

```sql
//创建扩展,如果遇到权限不足请换postgresql用户操作,如果无法打开文件权限不足,请把对应的目录的用户用户组改为postgresql
CREATE EXTENSION zhparser;
//创建conf
CREATE TEXT SEARCH CONFIGURATION testzhcfg (PARSER = zhparser);
//添加token映射
ALTER TEXT SEARCH CONFIGURATION testzhcfg ADD MAPPING FOR n,v,a,i,e,l WITH simple;
//测试分词效果
SELECT * FROM ts_parse('zhparser', 'hello world! 2010年保障房建设在全国范围内获全面启动，从中央到地方纷纷加大 了保障房的建设和投入力度 。2011年，保障房进入了更大规模的建设阶段。住房城乡建设部党组书记、部长姜伟新去年底在全国住房城乡建设工作会议上表示，要继续推进保障性安居工程建设。');
SELECT to_tsvector('testzhcfg','“今年保障房新开工数量虽然有所下调，但实际的年度在建规模以及竣工规模会超以往年份，相对应的对资金的需求也会创历>史纪录。”陈国强说。在他看来，与2011年相比，2012年的保障房建设在资金配套上的压力将更为严峻。');
SELECT to_tsquery('testzhcfg', '保障房资金压力');

//如果短词效果不理想,可以开启以下选项
alter role all set zhparser.multi_short=on;
//如果需要忽略标点分好,可以开启以下选项
alter role all set zhparser.punctuation_ignore=on;
```

经过测试,在少量数据的情况下,效果没有like稳定,据说在大量数据的情况下,会表现的很不错



# 三、结束

