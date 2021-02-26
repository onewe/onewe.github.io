---
title: java调用c# webservice
date: 2019/11/23 11:14:25
tags:
- java
- c#
- webservice
categories: java
cover: https://gitee.com/oneww/onew_image/raw/master/webservice-cover.png
author: 
  nick: onew
  link: https://onew.me
subtitle: java调用c# webservice,解决c#中的序列化问题
---

# 一、前言

​	最近落在手上一个对接任务,对方平台采用的是webservice,用.net写的.刚开始看文档的时候,感觉挺简单的,就几个xml发过去发过来的(之前没搞过webservice,全是个人愚见.).

​	但后面出现一个问题,接口上注明的参数类型是binarybase64,按照文档示例,不管怎么序列化都不对,一直在提示参数不对,不能序列化.后面才发现,这个二进制序列化格式是用的c#独有的序列化方式,是不跨平台的.emmm



# 二、BinaryFormatter

​	在c#里面常用的序列化方式是`BinaryFormatter`,这种序列化方式,是二进制形式,跟protocbuf差不多,但性能上要比protocbuf要好点.对比json就更不用说了.但为了提升性能,必将在其他地方作出让步,比如在跨语言上,这个就行不通了,其他语言不认识这个.为了完成这个对接任务,没有办法只能硬着头皮上了,在java中构造出`BinaryFormatter`的数据结构.



# 三、采用string对象示例

​	在翻遍c#官方文档都没有翻到关于`BinaryFormatter`的数据结构的情况下,只能在c#中序列化出来进行肉眼观察.

 1. string对象的数据头

    ```java
     private static final byte[] FRONT_BYTES  = new byte[]{
                (byte)0x00,(byte)0x01,(byte)0x00,(byte)0x00,(byte)0x00,(byte)0xFF,
                (byte)0xFF,(byte)0xFF,(byte)0xFF,(byte)0x01,(byte)0x00,(byte)0x00,
                (byte)0x00,(byte)0x00,(byte)0x00,(byte)0x00,(byte)0x00,(byte)0x06,
                (byte)0x01,(byte)0x00,(byte)0x00,(byte)0x00
        };
    ```

    前面22个字节是固定的,个人猜测是类型的信息.

	2. string对象的结束符

    ```java
        private static final byte END_BYTE = 0x0B;
    ```

    这个也是固定的,个人猜测为结束符.

 

​	头和尾头猜测出来,那么中间的肯定是数据的内容,经过多次测试,果不其然,中间的为字符串的内容.但在测试的过程发现有几个字节转不出字符串.这几个字节刚好在数据头的后面.

​	那么,可以肯定一点的是,这几个转不出来的字节是数据的长度.但是这个长度是怎么算出来的呢,所实话还还是猜了一段时间,在小于128字节的内容中,长度为128以内的数字.但一旦查过128字节就开始出现负数了.

​	经过一段时间的测试,发现长度是才用128进制的,至于为什么🤔️会出现负数,可能是一种标记吧,标记后面还有数据长度的数据,直到最后一个为正为止.

 3. 长度计算方法

    ``` java
    		private static byte[] lenToByte(int len) {
            if( len ==0 ){
                return new byte[]{0x00};
            }
            byte[] bytes = new byte[10];
            int count = 0;
            while (len != 0) {
                bytes[count] = (byte) (len % 128);
                len /= 128;
                if (len != 0) {
                    bytes[count] += 0x80;
                }
                count++;
            }
            return Arrays.copyOfRange(bytes,0, count);
        }
    ```
    
 4. 完整的字符串序列化方法

    ```java
    private static final byte[] FRONT_BYTES  = new byte[]{
      (byte)0x00,(byte)0x01,(byte)0x00,(byte)0x00,(byte)0x00,(byte)0xFF,
      (byte)0xFF,(byte)0xFF,(byte)0xFF,(byte)0x01,(byte)0x00,(byte)0x00,
      (byte)0x00,(byte)0x00,(byte)0x00,(byte)0x00,(byte)0x00,(byte)0x06,
      (byte)0x01,(byte)0x00,(byte)0x00,(byte)0x00
    };
    private static final byte END_BYTE = 0x0B; 
    private static byte[] stringToBytes(String value)  {
            try {
                final byte[] contentBytes = value.getBytes();
                final byte[] lenBytes = lenToByte(contentBytes.length);
                ByteArrayOutputStream byteArrayOutputStream = new ByteArrayOutputStream(64);
                byteArrayOutputStream.write(FRONT_BYTES);
                byteArrayOutputStream.write(lenBytes);
                byteArrayOutputStream.write(contentBytes);
                byteArrayOutputStream.write(END_BYTE);
                return byteArrayOutputStream.toByteArray();
            } catch (IOException e) {
                e.printStackTrace();
                return new byte[]{};
            }
        }
    
    
        private static byte[] lenToByte(int len) {
            if( len ==0 ){
                return new byte[]{0x00};
            }
            byte[] b = new byte[10];
            int i = 0;
            while (len != 0) {
                b[i] = (byte) (len % 128);
                len /= 128;
                if (len != 0) {
                    b[i] += 0x80;
                }
                i++;
            }
            return Arrays.copyOfRange(b, 0, i);
        }
    ```



# 五、总结

能不能不要玩webservice了,好累呀,好复杂呀,不想搞呀.
