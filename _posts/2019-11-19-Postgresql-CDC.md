---
title: Postgresql-CDC 方案踩坑
date: 2019/11/19 10:30:29
tags: 
 - postgresql
 - pgsql cdc
categories: postgresql
cover: https://gitee.com/oneww/onew_image/raw/master/postgresql-cover.png
author: 
  nick: onew
  link: https://onew.me
subtitle: Postgresql 监听数据变化CDC方案踩坑.
---



# 一、CDC概念

​	CDC(Changing Data Capture)意思是捕捉变化的数据,用流的方式持续捕捉.这与ETC有着本质上的区别,ETL则是定时拉取数据.

​	ETL 概念上是:抽取(E)、转换(T)、导入(L),ETL现在是比较成熟的,方案也比较多.但定时抽取就会意味着有时效性的问题,如果有一种方案,数据库数据出现更改就自动同步到OLAP引擎里面,岂不是美滋滋?那么CDC就是为此而生的,持续不断的监听数据库的变化情况,一旦变化就立马发出消息进行同步消息,但这种方案也并非完美,如遇到大事务的SQL,批量更新的这种,也会有延迟的问题,权衡一下估计两者差不多.

​	市面上常用的数据库有Mysql,PostgreSql等,Mysql的CDC方案比较多,通过监听binlog实现.而Postgresql的CDC方案则比较少,至少从百度(🐶️)上找的资料来看.



# 二、Postgresql CDC 方案

​	Postgresql 实现CDC是通过逻辑复制实现的,与Mysql 的binlog有异曲同工之处.详情请看官方[文档](http://postgres.cn/docs/11/logical-replication.html).只要在pgsql的配置文件中`wal_level`属性设置为`logical`就配置好了,再在数据库中创建订阅,以及复制槽,以上操作比较简单,不再记录,详情查看官方文档.

​	在pgsql中开启了逻辑复制,但还差一个逻辑解码输出插件.市面上解码插件有3款,当然也可以自己写[解码插件](http://postgres.cn/docs/11/logicaldecoding-output-plugin.html).

- 逻辑解码插件列表

  1. wal2json

     这款插件会把消息解码成json格式,方便于消费端进行消费.一个事务一条消息,github 地址:https://github.com/eulerto/wal2json.

     优点:

     ​	消息是json格式方便使用

     缺点:

     ​	对于大事务消息,比如一次性修改几十万条数据,会耗尽内存.

     ​	没有现场的插件,需要自行编译.在centos上进行编译有点点麻烦.

     java端的消费者代码可以参考迪士尼的项目:https://github.com/disneystreaming/pg2k4j

  2. decoderbufs

     消息格式为protobuf,比json省带宽.一个事务多条消息.github地址:https://github.com/xstevens/decoderbufs,现在这个插件原作者已经不维护了.可以用debezium维护的版本https://github.com/debezium/postgres-decoderbufs.

     优点:

     ​	大事务不会耗尽内存,效率比json高

     缺点:

     ​	在centos上不好编译,编译劝退.服务器不建议使用centos,免得各种编译问题.(关键是编译好了,在java端一读取消息就崩,至今没找到原因,退了,退了.)

     java端的消费者代码可以参考debezium项目中的connector-postgresql:https://github.com/debezium/debezium

  3. pgoutput

     该插件是官方的,只能适用于10+的版本,如果是10以下的版本还是劝退吧.该插件用起来目前感觉比以上两款都要爽,不用编译,官方自带,没有内存耗尽的问题.

     java端的消费者代码可以参考debezium项目中的connector-postgresql:https://github.com/debezium/debezium

    

    
  
  以上3款插件,笔者都试过,最终选择了官方的方案,用起来还是挺爽的.只不过该消息有单独的格式,要自己去解析.具体格式可以参考官方文档,http://postgres.cn/docs/11/protocol-logicalrep-message-formats.html.



# 三、JAVA 示例

要使用官方的插件分以下几个步骤:

1. 创建订阅

   ```sql
   CREATE PUBLICATION test FOR TABLE ONLY "user_info" 
    WITH (publish = 'insert,update,delete');
    -- 为表user_info创建名称为test的订阅,发布insert,update,delete消息
   ```

   

2. 创建复制槽

   ```sql
   CREATE_REPLICATION_SLOT test TEMPORARY LOGICAL pgoutput;
   -- 创建名称为test的复制槽
   ```

3. Java demo

   ```java
    		String url = "jdbc:postgresql://localhost:5432/test";
       Properties props = new Properties();
       PGProperty.USER.set(props, "postgres");
       PGProperty.PASSWORD.set(props, "postgres");
       PGProperty.ASSUME_MIN_SERVER_VERSION.set(props, "9.4");
       PGProperty.REPLICATION.set(props, "database");
       PGProperty.PREFER_QUERY_MODE.set(props, "simple");
   
       Connection con = DriverManager.getConnection(url, props);
       PGConnection replConnection = con.unwrap(PGConnection.class);
   
       //some changes after create replication slot to demonstrate receive it
       sqlConnection.setAutoCommit(true);
       Statement st = sqlConnection.createStatement();
       st.execute("insert into test_logic_table(name) values('first tx changes')");
       st.close();
   
       st = sqlConnection.createStatement();
       st.execute("update test_logic_table set name = 'second tx change' where pk = 1");
       st.close();
   
       st = sqlConnection.createStatement();
       st.execute("delete from test_logic_table where pk = 1");
       st.close();
   
       PGReplicationStream stream =
           pgConnection.getReplicationAPI()
                       .replicationStream()
                       .logical()
                       .withSlotName("test")
                       .withSlotOption("proto_version", 1)
                       .withSlotOption("publication_names", "test")
                       .withStartPosition(lastLsn)
                       .withStatusInterval(Math.toIntExact(Duration.ofSeconds(10).toMillis()), TimeUnit.MILLISECONDS)
                       .start();
   
       while (true) {
         //non blocking receive message
         ByteBuffer msg = stream.readPending();
         if (msg == null) {
           TimeUnit.MILLISECONDS.sleep(10L);
           continue;
         }
         int offset = msg.arrayOffset();
         byte[] source = msg.array();
         int length = source.length - offset;
         System.out.println(new String(source, offset, length));
   
         //feedback
         stream.setAppliedLSN(stream.getLastReceiveLSN());
         stream.setFlushedLSN(stream.getLastReceiveLSN());
       }
   ```

关于java示例中的用法,可以查看jdbc的文档:https://jdbc.postgresql.org/documentation/head/replication.html
