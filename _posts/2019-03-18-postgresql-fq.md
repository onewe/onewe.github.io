---
title: 使用postgresql HASH分区随笔
date: 2019/3/18 17:30:29
tags: postgresql HASH
categories: postgresql
cover: https://gitee.com/oneww/onew_image/raw/master/postgresql-cover.png
author: 
  nick: onew
  link: https://onew.me
subtitle: 记录一下postgresql分区操作
---

# 一、前言

在这个数据时代,对数据库的要求是越来越高了,百万级的数据毫秒响应,对于mysql来说有很多种的优化方案.但postgresql却用的比较自然



## 二、hash分区

> 首先要安装postgresql,安装教程可以百度.很简单.

在postgresql11之前是不支持hash分区的,支持list和range分区的方式,当然也可以巧妙的利用list实现hash分区的功能.

- 创建主表:

  ```sql
  CREATE TABLE "public"."SysOperateLog" (
    "id" varchar(64) NOT NULL,
    "account" varchar(100) NOT NULL,
    "operate" int2 NOT NULL,
    "tableName" varchar(100) NOT NULL,
    "sql" varchar(255) NOT NULL,
    "args" text NOT NULL,
    "createTime" timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(0)
  )PARTITION BY HASH(operate)
  
  
  COMMENT ON COLUMN "public"."SysOperateLog"."id" IS 'uuid不能为null';
  
  COMMENT ON COLUMN "public"."SysOperateLog"."account" IS '用户名不能为null';
  
  COMMENT ON COLUMN "public"."SysOperateLog"."operate" IS '0是增加 1是修改 2删除 不能为null';
  
  COMMENT ON COLUMN "public"."SysOperateLog"."tableName" IS '表名不能为null';
  
  COMMENT ON COLUMN "public"."SysOperateLog"."sql" IS 'sql语句,不能为null';
  
  COMMENT ON COLUMN "public"."SysOperateLog"."args" IS '参数,默认是 json数组';
  
  COMMENT ON COLUMN "public"."SysOperateLog"."createTime" IS '创建时间不能为null';
  ```

- 创建分区表

  ```sql
  CREATE TABLE "SysOperateLog0" PARTITION OF "public"."SysOperateLog" FOR VALUES WITH(MODULUS 3, REMAINDER 0);
  
  CREATE TABLE "SysOperateLog1" PARTITION OF "public"."SysOperateLog" FOR VALUES WITH(MODULUS 3, REMAINDER 1);
  
  CREATE TABLE "SysOperateLog2" PARTITION OF "public"."SysOperateLog" FOR VALUES WITH(MODULUS 3, REMAINDER 2);
  ```

以上就把分成3张分表,根据operate字段进行hash分区.但有个问题是,在主表上是不能创建主键或外键约束的.但可以在分区表上加约束

- 创建主键约束

  ```sql
  ALTER TABLE "public"."SysOperateLog0" ADD PRIMARY KEY ("id");
  ALTER TABLE "public"."SysOperateLog1" ADD PRIMARY KEY ("id");
  ALTER TABLE "public"."SysOperateLog2" ADD PRIMARY KEY ("id");
  ```

但这里还有一个问题,如果在`SysOperateLog0`中的id和其他表中的id是不冲突的,也就是说是没有全局主键约束的.为了id不重复,可以采用uuid序列来自动生成.

- 设置id字段默认值

  ```sql
  lter table "SysOperateLog0" alter column "id" set default replace(cast(uuid_generate_v4() as VARCHAR), '-', '');
  alter table "SysOperateLog1" alter column "id" set default replace(cast(uuid_generate_v4() as VARCHAR), '-', '');
  alter table "SysOperateLog2" alter column "id" set default replace(cast(uuid_generate_v4() as VARCHAR), '-', '');
  ```

如果不放心可以创建数据进行测试

- 插入测试数据100W

  ```sql
  INSERT INTO "SysOperateLog"("account","operate","tableName","sql",args) SELECT  n || '_username',mod(cast(extract(epoch from now()) as bigint),3),'table','sql','args' FROM generate_series(1,1000000) n;
  ```

经测试,是保证了id的唯一性的.



# 三、结束

