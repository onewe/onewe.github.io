---
title: javaFX 打包与调用虹软库的坑
date: 2018/7/12 16:56:25
tags:
- java
- javaFX
- arcsoft
categories: java
cover: https://gitee.com/oneww/onew_image/raw/master/java_fx_arcsoft_cover.jpg
author: 
  nick: onew
  link: https://onew.me
subtitle: 虹软很多坑,javaFX打包之后也很多坑,项目不止,踩坑不断.在此把踩的坑全部记录下来.
---



# 一、前言

由于公司要求需要提供一个人脸检测的桌面软件打包出去用,目前虹软在这块儿算是做的比较的好的,并且人脸识别也是免费,于是首当其冲的选择了虹软的产品.没相当用javaFX打包之后遇到了各种坑,心累呀.



#  二、踩坑锦集

1. 多线程使用虹软库的时候,必须每个线程一个虹软的引擎,不然会报错.如果想使用线程池,首先继承thread,在对象中封装虹软的引擎对象(这里java使用的是JNA),然后创建线程池的时候,new的thread对象一定是自己创建的那个对象,这样就保证了一个线程一个虹软的对象.详情看一下代码:

   ```java
   
   /**
   封装FD
   */
   public class Detection {
       private static final int FD_WORK_BUF_SIZE = 20 * 1024 * 1024;// 20 MB
       private static final int nScale = 16; // 有效值范围[2,50]
       private static final int MAX_FACE_NUM = 16; // 有效值范围[1,50]
       private Pointer hFDEngine;
       private Pointer pFDWorkMem;
       private boolean doing = false;
   	//在构造方法中,初始化虹软引擎
       public Detection(){
           String APPID = null;
           String FD_SDKKEY = null;
           if(OSUtils.getCurrentOSType() == OSUtils.OSType.Windows){
               APPID = ArcFace.appid_Windows_x64;
               FD_SDKKEY = ArcFace.sdkkey_FD_Windows_x64;
           } else if(OSUtils.getCurrentOSType() == OSUtils.OSType.Linux){
               APPID = ArcFace.appid_Linux_x64;
               FD_SDKKEY = ArcFace.sdkkey_FD_Linux_x64;
           }
           pFDWorkMem = CLibrary.INSTANCE.malloc(FD_WORK_BUF_SIZE);
           PointerByReference phFDEngine = new PointerByReference();
           NativeLong ret = AFD_FSDKEngine.INSTANCE.AFD_FSDK_InitialFaceEngine(
                   APPID,
                   FD_SDKKEY,
                   pFDWorkMem,
                   FD_WORK_BUF_SIZE,
                   phFDEngine,
                   FSDK_OrientPriority.FSDK_OPF_0_HIGHER_EXT,
                   nScale,
                   MAX_FACE_NUM);
           if (ret.longValue() != 0) {
               CLibrary.INSTANCE.free(pFDWorkMem);
               System.err.println(String.format("AFD_FSDK_InitialFaceEngine ret 0x%x %s", ret.longValue(), Error.getErrorMsg(ret.longValue())));
           }
           hFDEngine = phFDEngine.getValue();
       }
   
       public FaceInfo[] faceDetection(ASVLOFFSCREEN inputImg) {
           FaceInfo[] faceInfo = new FaceInfo[0];
           PointerByReference ppFaceRes = new PointerByReference();
           doing = true;
           NativeLong ret = AFD_FSDKEngine.INSTANCE.AFD_FSDK_StillImageFaceDetection(
                   hFDEngine,
                   inputImg,
                   ppFaceRes);
           doing = false;
           if (ret.longValue() != 0) {
               System.out.println(String.format("AFD_FSDK_StillImageFaceDetection ret 0x%x %s", ret.longValue(), Error.getErrorMsg(ret.longValue())));
               return faceInfo;
           }
   
           AFD_FSDK_FACERES faceRes = new AFD_FSDK_FACERES(ppFaceRes.getValue());
           if (faceRes.nFace > 0) {
               faceInfo = new FaceInfo[faceRes.nFace];
               for (int i = 0; i < faceRes.nFace; i++) {
                   MRECT rect = new MRECT(new Pointer(Pointer.nativeValue(faceRes.rcFace.getPointer()) + faceRes.rcFace.size() * i));
                   int orient = faceRes.lfaceOrient.getPointer().getInt(i * 4);
                   faceInfo[i] = new FaceInfo();
                   faceInfo[i].left = rect.left;
                   faceInfo[i].top = rect.top;
                   faceInfo[i].right = rect.right;
                   faceInfo[i].bottom = rect.bottom;
                   faceInfo[i].orient = orient;
               }
           }
           return faceInfo;
       }
   
       public FaceInfo[] faceDetection(BufferedImage img){
           return faceDetection(ArcFaceUtil.getASVLOFFSCREEN(img));
       }
   
       public void close(){
           try {
               while (doing){
                   Thread.sleep(200);
               }
               AFD_FSDKEngine.INSTANCE.AFD_FSDK_UninitialFaceEngine(hFDEngine);
               CLibrary.INSTANCE.free(pFDWorkMem);
           }catch (Exception e){
               e.printStackTrace();
           }
       }
   }
   
   
   //继承线程对象
   public class FaceThread extends Thread {
   
   
       private final Detection detection;
     
       public FaceThread(Runnable runnable){
           super(runnable);
           detection = new Detection();
       }
   
   
   
       public Detection getDetection() {
           return detection;
       }
   }
   
   //创建线程池
    public static final ListeningExecutorService FACE_THREAD_POOL = MoreExecutors.listeningDecorator(Executors.newFixedThreadPool(4,new ThreadFactoryBuilder().setThreadFactory(FaceThread::new).setNameFormat("face-%d-Thread").setUncaughtExceptionHandler((t, e) -> e.printStackTrace(System.err)).setDaemon(true).build()));
   ```

   使用的时候,只需要拿到当前线程对象,就可以了,因为当前线程对象里面有虹软的识别引擎对象.

2. 某些电脑加载不了虹软的dll文件

   这个首先排查自己代码中的dll路径有没有错,如果没有错,就看库的版本与jvm的版本是否一致,必须两个都为32或者64才能跑.妈的如果这时候版本也是一致的,就看电脑上是否安装了[vc++ 2013](https://www.microsoft.com/zh-CN/download/details.aspx?id=40784)的运行库,如果没有就下载一个进行安装.如果还是没办法,问官方吧.

3. 打包成jar加载不了dll文件

   这个的确是个问题,对于一个有强迫症的人来说.因为dll文件被打包进jar中了,所以dll就不存在文件系统中了,这个时候需要从jar中释放出dll文件来,在进行加载dll.代码如下:

   ```java
   /**
    * @author
    * */
   public class LoadUtils {
   	public static <T> T loadOSLibrary(String libName, Class<T> interfaceClass) {
           try {
               String filePath = "";
               URI uri = LoadUtils.class.getProtectionDomain().getCodeSource().getLocation().toURI();
               if (Platform.isWindows()) {
                   filePath = "arcsoft/windows_x64/" + libName + ".dll";
                   uri = uri.resolve(filePath);
               } else if (Platform.isLinux()) {
                   filePath = "arcsoft/linux_x64/" + libName + ".so";
                   uri = uri.resolve(filePath);
               } else {
                   System.out.println("unsupported platform");
                   System.exit(0);
               }
               Path path = Paths.get(uri);
               //尝试释放资源
               if(!Files.exists(path) && filePath.length() > 0){
                   Path parent = Paths.get(uri.resolve("./"));
                   System.out.println(parent);
                   //父目录不存在,创建目录
                   if(!Files.exists(parent)){
                       Files.createDirectories(parent);
                   }
                   Files.copy(LoadUtils.class.getResourceAsStream("/" + filePath),path);
               }
               System.out.println(path.toString());
               return loadLibrary(path.toString(), interfaceClass);
           } catch (URISyntaxException | IOException e) {
               e.printStackTrace();
           }
   
           return null;
   	}
   
   	private static <T> T loadLibrary(String filePath, Class<T> interfaceClass) {
   		return Native.loadLibrary(filePath, interfaceClass);
   	}
   
   }
   ```

4. 使用虹软的ft(libarcsoft_fsdk_face_tracking.dll)和fd(libarcsoft_fsdk_face_detection.dll)的效果是不一样的.

   最开始使用的ft进行的人脸检测,发现有时候能检测出人脸而有时候却检测不出人脸,坑啊.最后换了fd之后这种情况就没了.



# 三、总结

项目不止,踩坑不断,后面踩到新坑,会补充上来.心累......
