---
title: BufferedInputStream与InputStream的区别
date: 2019/10/24 15:30:22
comments: true
tags: 
- java
- io
- InputSream
- bufferedInputStream
categories: java
cover: https://gitee.com/oneww/onew_image/raw/master/java_io.jpg
author: 
  nick: onew
  link: https://onew.me
subtitle: BufferedInputStream与InputStream的区别在哪?为啥会快啊?石锤?
---



# 一、前言

最近在项目遇到一个BufferedInputStream和InputStream混用的问题,导致InputStream阻塞线程,于是为了解决问题,打算剥开BufferedInputStream的buffer观察内在的本质,凭啥都说BufferedInputStream比InputStream快?



# 二、事故线程

事故是发生在,抄袭的jsch下载文件的demo里,为了偷懒开发人员直接把demo里面的代码扒了下了,不过好在一点是开发人员觉得InputStream比较慢,换成了BufferedInputStream.这点还是比较好的,至少有点点常识.以下为部分代码.

- 读取文件代码

```java
   			ChannelExec channel = null;
        OutputStream outputStream;
        InputStream inputStream;
        BufferedOutputStream bufferedOutputStream = null;
        BufferedInputStream bufferedInputStream = null;
        BufferedOutputStream bufferedFileOutputStream = null;
        try {
            channel = (ChannelExec) session.openChannel("exec");
            channel.setCommand(command);
            outputStream = channel.getOutputStream();
            inputStream = channel.getInputStream();
            channel.connect(4000);
          	//buffer 数组
            byte[] buf = new byte[1024 * 1000];
            bufferedOutputStream = new BufferedOutputStream(outputStream);
            buf[0] = 0;
            bufferedOutputStream.write(buf,0,1);
            bufferedOutputStream.flush();
            bufferedInputStream = new BufferedInputStream(inputStream);
            while (true){
              	//检查数据流
                CommandStatus commandStatus = checkAck(inputStream);
                if(commandStatus.code != 'C'){
                    break;
                }
                bufferedInputStream.read(buf,0,5);

                long count = 0;
                int foo;
                while (true){
                    if(buf.length < fileSize){
                        foo = buf.length;
                    }else{
                        foo = (int) fileSize;
                    }

                    foo = bufferedInputStream.read(buf,0,foo);
                    count += foo;
                    message.setValue(String.format(messageStrFormat, (count / (double) finalFileSzie) * 100,count,finalFileSzie));
                    if(foo < 0){
                        break;
                    }
                    bufferedFileOutputStream.write(buf,0,foo);
                    bufferedFileOutputStream.flush();
                    fileSize -=foo;
                    if(fileSize == 0L){
                        break;
                    }
                }
              //检查数据流
                commandStatus = checkAck(inputStream);
                if(!commandStatus.isOk){
                    message.setValue(commandStatus.getMessage());
                    return false;
                }
                buf[0]=0;
                bufferedOutputStream.write(buf,0,1);
                bufferedOutputStream.flush();
            }
```

- 检查流代码

```java
 private static CommandStatus checkAck(InputStream input){
        CommandStatus commandStatus = new CommandStatus();
        try {
            int b = input.read();
            commandStatus.setCode(b);
            if(b == 0 || b == -1){
                commandStatus.setOk(true);
                return commandStatus;
            }
            if(b == 1 || b == 2){
                commandStatus.setOk(false);
                StringBuilder sb = new StringBuilder();
                BufferedReader reader = new BufferedReader(new InputStreamReader(new BufferedInputStream(input)));
                reader.lines().forEach(s -> sb.append(s).append("\n"));
                System.out.println(sb.toString());
                commandStatus.setMessage(sb.toString());
            }
        } catch (Exception e) {
            e.printStackTrace();
            commandStatus.setMessage(e.getMessage());
            commandStatus.setOk(false);
        }

        return commandStatus;
    }
```

事故发生在读取文件代码中的,第二次检查流的时候出现了线程阻塞.

1. 为什么会发生阻塞?

   一般来说发生阻塞会有两种情况:

   1: 底层buffer未被填满

   2: 没有任何可以读取的数据,等待发送数据

   后面开发人员发现了这个阻塞的bug,经过抢救把原先使用inputStream 来检测流的代码换成了BufferedInputStream,神奇的是,问题就被解决了.但却不知道为啥被解决了,就是这么莫名其妙.

​	要想分析出原因,那么就要扒开buffer的外衣,观察本质.



# 三、代码分析

1. BufferedInputStream,以下为省略部分代码

   ```java
   public
   class BufferedInputStream extends FilterInputStream {
   
       private static int DEFAULT_BUFFER_SIZE = 8192;
   
       /**
        * The maximum size of array to allocate.
        * Some VMs reserve some header words in an array.
        * Attempts to allocate larger arrays may result in
        * OutOfMemoryError: Requested array size exceeds VM limit
        */
       private static int MAX_BUFFER_SIZE = Integer.MAX_VALUE - 8;
   
       /**
        * The internal buffer array where the data is stored. When necessary,
        * it may be replaced by another array of
        * a different size.
        */
       protected volatile byte buf[];
     
       /**
        * Check to make sure that underlying input stream has not been
        * nulled out due to close; if not return it;
        */
       private InputStream getInIfOpen() throws IOException {
           InputStream input = in;
           if (input == null)
               throw new IOException("Stream closed");
           return input;
       }
   
       /**
        * Check to make sure that buffer has not been nulled out due to
        * close; if not return it;
        */
       private byte[] getBufIfOpen() throws IOException {
           byte[] buffer = buf;
           if (buffer == null)
               throw new IOException("Stream closed");
           return buffer;
       }
     
      private void fill() throws IOException {
           byte[] buffer = getBufIfOpen();
           if (markpos < 0)
               pos = 0;            /* no mark: throw away the buffer */
           else if (pos >= buffer.length)  /* no room left in buffer */
               if (markpos > 0) {  /* can throw away early part of the buffer */
                   int sz = pos - markpos;
                   System.arraycopy(buffer, markpos, buffer, 0, sz);
                   pos = sz;
                   markpos = 0;
               } else if (buffer.length >= marklimit) {
                   markpos = -1;   /* buffer got too big, invalidate mark */
                   pos = 0;        /* drop buffer contents */
               } else if (buffer.length >= MAX_BUFFER_SIZE) {
                   throw new OutOfMemoryError("Required array size too large");
               } else {            /* grow buffer */
                   int nsz = (pos <= MAX_BUFFER_SIZE - pos) ?
                           pos * 2 : MAX_BUFFER_SIZE;
                   if (nsz > marklimit)
                       nsz = marklimit;
                   byte nbuf[] = new byte[nsz];
                   System.arraycopy(buffer, 0, nbuf, 0, pos);
                   if (!bufUpdater.compareAndSet(this, buffer, nbuf)) {
                       // Can't replace buf if there was an async close.
                       // Note: This would need to be changed if fill()
                       // is ever made accessible to multiple threads.
                       // But for now, the only way CAS can fail is via close.
                       // assert buf == null;
                       throw new IOException("Stream closed");
                   }
                   buffer = nbuf;
               }
           count = pos;
           int n = getInIfOpen().read(buffer, pos, buffer.length - pos);
           if (n > 0)
               count = n + pos;
       }
     
      /**
        * Read characters into a portion of an array, reading from the underlying
        * stream at most once if necessary.
        */
       private int read1(byte[] b, int off, int len) throws IOException {
           int avail = count - pos;
           if (avail <= 0) {
               /* If the requested length is at least as large as the buffer, and
                  if there is no mark/reset activity, do not bother to copy the
                  bytes into the local buffer.  In this way buffered streams will
                  cascade harmlessly. */
               if (len >= getBufIfOpen().length && markpos < 0) {
                   return getInIfOpen().read(b, off, len);
               }
               fill();
               avail = count - pos;
               if (avail <= 0) return -1;
           }
           int cnt = (avail < len) ? avail : len;
           System.arraycopy(getBufIfOpen(), pos, b, off, cnt);
           pos += cnt;
           return cnt;
       }
     
     
      public synchronized int read(byte b[], int off, int len)
           throws IOException
       {
           getBufIfOpen(); // Check for closed stream
           if ((off | len | (off + len) | (b.length - (off + len))) < 0) {
               throw new IndexOutOfBoundsException();
           } else if (len == 0) {
               return 0;
           }
   
           int n = 0;
           for (;;) {
               int nread = read1(b, off + n, len - n);
               if (nread <= 0)
                   return (n == 0) ? nread : n;
               n += nread;
               if (n >= len)
                   return n;
               // if not closed but no bytes available, return
               InputStream input = in;
               if (input != null && input.available() <= 0)
                   return n;
           }
       }
   }
   ```

      一般情况下都会使用` public synchronized int read(byte b[], int off, int len)`这个方法去读取数据,`read`方法本质上是使用了`private int read1(byte[] b, int off, int len) throws IOException `

   读取数据.那么核心逻辑就在`read1`方法中.

     聚焦一下`read1`方法:

   ```java
      private int read1(byte[] b, int off, int len) throws IOException {
           int avail = count - pos;
           if (avail <= 0) {
               /* If the requested length is at least as large as the buffer, and
                  if there is no mark/reset activity, do not bother to copy the
                  bytes into the local buffer.  In this way buffered streams will
                  cascade harmlessly. */
               if (len >= getBufIfOpen().length && markpos < 0) {
                   return getInIfOpen().read(b, off, len);
               }
               fill();
               avail = count - pos;
               if (avail <= 0) return -1;
           }
           int cnt = (avail < len) ? avail : len;
           System.arraycopy(getBufIfOpen(), pos, b, off, cnt);
           pos += cnt;
           return cnt;
       }
     
   ```

   1. 检测是否具有可用的数据可供读取
   2. 如果没有则判断读取的长度是否大于`BufferedInputStream`内置的buffer的长度,并且设置标记.
   3. 如果大于则调用`InputStream`的`read`方法读取,并返回整个数组
   4. 如果小于,则填充内置`buffer`
   5. 把内置buffer的数据填充到参数中的byte 数组中去

   以上为整体逻辑.

   ​	感觉好像没做什么加速的操作,为啥都说`BufferedInputStream`快呢?其实在你读取的数据长度小于`BufferedInputStream`内置buffe的时候才会有"快"这个说法.但也不快,本质上还是用`InputStream`去读取的数据,那么从网络中读取速度就是一样的,只是在你需要读取的数据长度小于`BufferedInputSteam`内置Buffer长度的时候,它会一次性读取填满到buffer,在下次读取的时候就不会从网络中读取了,而是在buffer中读取,直接从内存中读取,减少了一次网络的IO开销,或许这就是"快"的原因?

   那么,这个阻塞是怎么来的?

   ​	知道`BufferedInputStream`的本质之后,就好分析了.回到业务代码和流检测代码中来,可以发现在流检测代码中,只读取了一个字节.

   ```java
   int b = input.read();//发生阻塞
   ```

      `read`方法的具体实现

   ```java
   public synchronized int read()  throws IOException {
           if (!connected) {
               throw new IOException("Pipe not connected");
           } else if (closedByReader) {
               throw new IOException("Pipe closed");
           } else if (writeSide != null && !writeSide.isAlive()
                      && !closedByWriter && (in < 0)) {
               throw new IOException("Write end dead");
           }
   
           readSide = Thread.currentThread();
           int trials = 2;
           while (in < 0) {
               if (closedByWriter) {
                   /* closed by writer, return EOF */
                   return -1;
               }
               if ((writeSide != null) && (!writeSide.isAlive()) && (--trials < 0)) {
                   throw new IOException("Pipe broken");
               }
               /* might be a writer waiting */
               notifyAll();
               try {
                   wait(1000);
               } catch (InterruptedException ex) {
                   throw new java.io.InterruptedIOException();
               }
           }
           int ret = buffer[out++] & 0xFF;
           if (out >= buffer.length) {
               out = 0;
           }
           if (in == out) {
               /* now empty */
               in = -1;
           }
   
           return ret;
       }
   ```

   ​	可以看到代码里面会有一个while循环在检查是否具有可读取的数据,如果没有可读取的数据,while将会一直执行下去,只带有可读取的数据位置.阻塞就是因为while在空转.

   ​    结案: 因为前面使用`BufferedInputStream`读取数据,`BufferedInputStream`会一次性,把整个buffer全部填满,默认buffer大小是`private static int DEFAULT_BUFFER_SIZE = 8192;`.

     也就是说`BufferedInputStream`先把数据 读完了,读到buffer中了,后面代码使用`InputStream`的时候当然读取不到数据了,就会在while那里空转,直到有数据为止,可`InputStream`哪里知道,数据早就没读取完了,哎,不说了真傻!

   

