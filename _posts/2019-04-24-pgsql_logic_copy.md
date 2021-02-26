---
title: pgsql 数据库消息同步
date: 2019/4/24 17:30:29
tags: postgresql java 
categories: postgresql
cover: https://gitee.com/oneww/onew_image/raw/master/postgresql-cover.png
author: 
  nick: onew
  link: https://onew.me
subtitle: 利用pgsql逻辑复制,实现消息同步
---

# 一、前言

最近遇到一个需求,当数据库中的数据发生改变时,要进行业务同步到统计表中去,最开始是想用触发器进行实现,奈何没有数据库大牛,触发器写起来有点麻烦.调研了一下发现pgsql有类似mysql的binlog的消息机制.那么就可以嘿嘿嘿了.



# 二、配置

要实现消息同步需要使用pgsql的replication slots机制,在`postgresql.conf`配置文件中设置

```properties
wal_level = logical
max_wal_senders=1
max_replication_slots=1
```

这样就打开了pgsql的逻辑复制机制.还需要配置一个wal插件,把wal日志转成json字符串,方便程序解析.这里使用的插件是wal2json.

-  wal2json 配置

  ```shell
   git clone https://github.com/eulerto/wal2json.git
   cd wal2json
   USE_PGXS=1 make
   USE_PGXS=1 make install
  ```

  以上就是编译wal2json的步骤,可能会遇到环境的问题导致编译失败,最简单的解决办法是修改wal2json源码中的Makefile 文件中的`PG_CONFIG`这个变量的值,改为本地`pg_config`命令的路径.注意在编译的时候要实现安装好g++ 这些依赖.

- pgsql配置

  修改pgsql配置文件`postgresql.conf`,使其wal2json插件生效

  ```properties
  shared_preload_libraries = 'wal2json'
  ```

  重启数据库

- wal2json测试

  ```shell
  #创建slot -d数据库 --slot名称 -P 插件名称
  pg_recvlogical -d postgres --slot test_slot --create-slot -P wal2json
  #接受slot的数据 并打印到console上 -o 插件参数,参数说明可以参考https://github.com/eulerto/wal2json
  pg_recvlogical -d postgres --slot test_slot --start -o pretty-print=1 -f -
  ```

  一切顺利的话,只要在指定的数据库上进行crud就会看到控制台输出的json

  ```json
  {
  	"change": [
  	]
  }
  {
  	"change": [
  	]
  }
  {
  	"change": [
  		{
  			"kind": "insert",
  			"schema": "public",
  			"table": "table_with_pk",
  			"columnnames": ["a", "b", "c"],
  			"columntypes": ["integer", "character varying(30)", "timestamp without time zone"],
  			"columnvalues": [1, "Backup and Restore", "2018-03-27 11:58:28.988414"]
  		}
  		,{
  			"kind": "insert",
  			"schema": "public",
  			"table": "table_with_pk",
  			"columnnames": ["a", "b", "c"],
  			"columntypes": ["integer", "character varying(30)", "timestamp without time zone"],
  			"columnvalues": [2, "Tuning", "2018-03-27 11:58:28.988414"]
  		}
  		,{
  			"kind": "insert",
  			"schema": "public",
  			"table": "table_with_pk",
  			"columnnames": ["a", "b", "c"],
  			"columntypes": ["integer", "character varying(30)", "timestamp without time zone"],
  			"columnvalues": [3, "Replication", "2018-03-27 11:58:28.988414"]
  		}
  		,{
  			"kind": "delete",
  			"schema": "public",
  			"table": "table_with_pk",
  			"oldkeys": {
  				"keynames": ["a", "c"],
  				"keytypes": ["integer", "timestamp without time zone"],
  				"keyvalues": [1, "2018-03-27 11:58:28.988414"]
  			}
  		}
  		,{
  			"kind": "delete",
  			"schema": "public",
  			"table": "table_with_pk",
  			"oldkeys": {
  				"keynames": ["a", "c"],
  				"keytypes": ["integer", "timestamp without time zone"],
  				"keyvalues": [2, "2018-03-27 11:58:28.988414"]
  			}
  		}
  		,{
  			"kind": "insert",
  			"schema": "public",
  			"table": "table_without_pk",
  			"columnnames": ["a", "b", "c"],
  			"columntypes": ["integer", "numeric(5,2)", "text"],
  			"columnvalues": [1, 2.34, "Tapir"]
  		}
  	]
  }
  ```

- 删除slot

  ```shell
  pg_recvlogical -d postgres --slot test_slot --drop-slot
  ```

验证slot是否创建成功以及slot里面有没有消息,可以使用一下的sql语句

```sql
--查询数据库中的slot
select * from pg_replication_slots;
--查询slot中的消息
SELECT data FROM pg_logical_slot_get_changes('test_slot', NULL, NULL, 'pretty-print', '1');
```



# 三、解析消息

其实解析还算是比较简单的,在pgsql中的jdbc中提供了slot读取消息的api,直接调用即可.

```java
    //以下实例代码来自官方demo https://jdbc.postgresql.org/documentation/head/replication.html
		String url = "jdbc:postgresql://localhost:5432/test";
    Properties props = new Properties();
    PGProperty.USER.set(props, "postgres");
    PGProperty.PASSWORD.set(props, "postgres");
    PGProperty.ASSUME_MIN_SERVER_VERSION.set(props, "9.4");
    PGProperty.REPLICATION.set(props, "database");
    PGProperty.PREFER_QUERY_MODE.set(props, "simple");

    Connection con = DriverManager.getConnection(url, props);
    PGConnection replConnection = con.unwrap(PGConnection.class);

    replConnection.getReplicationAPI()
        .createReplicationSlot()
        .logical()
        .withSlotName("demo_logical_slot")
        .withOutputPlugin("test_decoding")
        .make();

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
        replConnection.getReplicationAPI()
            .replicationStream()
            .logical()
            .withSlotName("demo_logical_slot")
            .withSlotOption("include-xids", false)
            .withSlotOption("skip-empty-xacts", true)
            .withStatusInterval(20, TimeUnit.SECONDS)
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



当然也可以直接抄迪士尼开源的库[pg2k4j](https://github.com/disneystreaming/pg2k4j),开源的东西怎么能说抄呢.



# NOTE

有个问题需要注意一下,开启逻辑复制,可能造成wal日志积压,导致服务器磁盘占用量大,这个问题虽然还没遇到,先占个坑.
