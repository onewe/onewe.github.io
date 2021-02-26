---
title: 暴力破解aspose.excel.19.7
date: 2019/9/04 9:14:25
tags:
- java
- aspose
- aspose crack
categories: java
cover: https://gitee.com/oneww/onew_image/raw/master/java_aspose_cover.png
author: 
  nick: onew
  link: https://onew.me
subtitle: 9行代码搞定java版本aspose.word.19.7 license验证
---



# 一、前言

之前发布了一篇破解aspose.word破解文章,其实是生活所迫买不起授权,不得已才会去破解.emmm,在写一篇破解aspose.excel的文章吧,平衡一下.



# 二、分析

由于aspose产品系列是没有做联网校验的,所以破解起来比较容易,只要找到核心逻辑,用javassist重新生成一下类即可.

```java
//以下为忽略其他代码核心代码
public class License {
    private String[] b;
    private int c;
    private String d;
    private String e;
    private String f;
    private String g;
    static License a = null;
    private static final String h;
    private static final String i;
    private static final String j;

    public License() {
    }

    public static boolean isLicenseSet() {
        return a != null;
    }

    public static Date getSubscriptionExpireDate() {
        return a == null ? null : a.a();
    }

    public void setLicense(InputStream stream) {
        Document var2 = null;
        if (stream != null) {
            try {
                DocumentBuilderFactory var3 = DocumentBuilderFactory.newInstance();
                DocumentBuilder var4 = var3.newDocumentBuilder();
                var2 = var4.parse(stream);
            } catch (Exception var5) {
                throw new CellsException(9, zd.a(new byte[]{124, 115, -70, -126, 106, 43, -66, 83, 56, 75, -22, -73, 44, 49, -40, 90, -47, -73, -69, 27, -69, -6, -73, 28, -30, -71, -72, -97, 26, 108, -93, -68, -102, 13, -101, -97, 26, 76, -128, -55, 19, -102, 90, 45, -102}), var5);
            }
        }

        this.a(var2);
    }



    private void a(Document var1) {
        if (var1 != null) {
            zcev.a(var1);
            var1.getDocumentElement().normalize();
            Element var2 = var1.getDocumentElement();
            Node var3 = var2.getElementsByTagName(zd.a(new byte[]{-52, 93, -104, -53, -86, -121, 91, 74, -102})).item(0);
            Node var4 = var2.getElementsByTagName(zd.a(new byte[]{92, -4, -120, -14, -82, 78, 106, -116, -53, 41, 59, 19, 110, 26})).item(0);
            if (var3 != null && var4 != null && a(zcev.a(var3), var4.getLastChild().getNodeValue())) {
                int var7;
                try {
                    Node var5 = zcev.a(var3.getChildNodes(), zd.a(new byte[]{-67, -111, -128, -97, -103, -11, 17, -62, 0, -80, -126, -117, -92, 62, 51, 83, -126, -102}));
                    NodeList var6 = var3.getChildNodes();

                    for(var7 = var6.getLength() - 1; var7 > -1; --var7) {
                        Node var8 = var6.item(var7);
                        String var9 = var8.getNodeName();
                        if (var9.equals(zd.a(new byte[]{42, 40, -81, -43, 48, -59, 75, -54, 90, 19, 111, -65, -44, -46, 90}))) {
                            NodeList var18 = var5.getChildNodes();
                            this.b = new String[var18.getLength()];

                            for(int var11 = var18.getLength() - 1; var11 > -1; --var11) {
                                Node var12 = var18.item(var11).getLastChild();
                                this.b[var11] = b(var12 == null ? zd.a(new byte[]{-64, -102, -102, -102}) : var12.getNodeValue());
                            }
                        } else {
                            Node var10;
                            if (var9.equals(zd.a(new byte[]{-38, 105, 45, -73, 11, -33, 90, -28, -47, 126, 48, 9, 93, -1, 50, 42, -102}))) {
                                var10 = var8.getLastChild();
                                this.c = k(var10 == null ? zd.a(new byte[]{58, -116, 96, 39, 88, 45, 105, 3, 26, -102, -102}) : var10.getNodeValue());
                            } else if (var9.equals(zd.a(new byte[]{49, -103, 60, -104, -127, 75, 24, -88, 7, 16, 38, 23, 60, 106, -119, 36, 56, 104, -102}))) {
                                var10 = var8.getLastChild();
                                this.d = var10 == null ? zd.a(new byte[]{-79, 118, -52, 23, -5, 75, 19, -102, -102, -102}) : var10.getNodeValue();
                            } else if (var9.equals(zd.a(new byte[]{23, -24, -91, 57, -80, -76, -20, -108, 70, 111, 40, -51, -26, 15, -56, -100, -17, 83, -12, 26}))) {
                                var10 = var8.getLastChild();
                                this.e = var10 == null ? zd.a(new byte[]{-84, -104, 89, 23, -28, 72, 122, -102, -102}) : var10.getNodeValue();
                            } else if (var9.equals(zd.a(new byte[]{88, 108, 51, 119, -9, -115, -124, -35, 58, 60, 114, -102, 84, 35, -73, 74, -102}))) {
                                var10 = var8.getLastChild();
                                this.f = var10 == null ? zd.a(new byte[]{-22, -11, 6, -13, 36, 3, 26, -102, -102}) : var10.getNodeValue();
                            } else if (var9.equals(zd.a(new byte[]{126, -92, -32, 77, -41, 115, 3, 64, 104, -82, 38, -36, 56, -116, 63, 123, -29, 26, -128, 34, 3, -70, -16, -86, -102}))) {
                                var10 = var8.getLastChild();
                                this.g = var10 == null ? zd.a(new byte[]{56, -68, 65, -91, 31, -13, 83, 29, -102, -102, -102}) : var10.getNodeValue();
                            }
                        }
                    }
                } catch (CellsException var13) {
                    throw var13;
                } catch (Exception var14) {
                    throw new CellsException(9, zd.a(), var14);
                }

                if (i(this.d)) {
                    a(this.b);
                    String var15 = za.d;
                    if (var15 != null && this.e != null) {
                        boolean var16 = true;
                        var7 = Integer.parseInt(this.e.substring(0, 4));
                        int var17 = Integer.parseInt(var15.substring(0, 4));
                        if (var7 < var17) {
                            var16 = false;
                        } else if (var7 == var17) {
                            var7 = Integer.parseInt(this.e.substring(4, 6));
                            var17 = Integer.parseInt(var15.substring(5, 7));
                            if (var7 < var17) {
                                var16 = false;
                            } else if (var7 == var17 && Integer.parseInt(this.e.substring(6)) < Integer.parseInt(var15.substring(8))) {
                                var16 = false;
                            }
                        }

                        if (!var16) {
                            throw new CellsException().toString());
                        }
                    }

                    if (this.f != null && (new Date()).after(j(this.f))) {
                        throw new CellsException();
                    }

                    a = this;
                    zbfo.a();
                    return;
                }
            }
        }

        a = null;
        zyn.a();
    }

    Date a() {
        return j(this.e);
    }

    Date b() {
        return j(this.f);
    }


    private static Date j(String var0) {
        if (var0 != null && var0.length() >= 8) {
            SimpleDateFormat var1 = new SimpleDateFormat(zd.a(new byte[]{-45, 76, 65, 94, 38, 26, -102, -48, -10, -102, -60, 122}));

            try {
                return var1.parse(var0);
            } catch (ParseException var3) {
                throw new IllegalArgumentException(zd.a(new byte[]{118, -23, 102, -26, -97, 62, -97, -46, 110, 6, -109, -9, -8, -94, -127, -119, -100, -100, -15, 43, -55, -98, -39, -103, 32, -35, -15, -105, -33, 90, 84, 35, -73, 74, -74, -98, 42, 89, -98, 82, -102}));
            }
        } else {
            return null;
        }
    }

}

```

通过以上代码可以分析出,通过`setLicense`方法,设置许可证,然后经过一顿看不懂的操作,完成许可的验证.但核心逻辑只有几行代码

```java
a = this; //设置对象为this,为了给其他对象调用,改属性是static的,但只有包权限
zbfo.a(); //设置flag为false,具体啥用不晓得
private static Date j(String var0) //验证许可的过期时间
```

于是思路就是,重写掉`setLicense`方法,在方法体里面保留以下代码

```java
this.a = new com.aspose.cells.License();
com.aspose.cells.zbfo.a();
```

重写`private static Date j(String var0)`方法,使得返回的date为最大值

```java
return new java.util.Date(java.lang.Long.MAX_VALUE);
```

最后用javassist进行修改,代码如下:

```java
 ClassPool aDefault = ClassPool.getDefault();
 CtClass ctClass = aDefault.get("com.aspose.cells.License");
 CtMethod ctMethod = ctClass.getMethod("setLicense", "(Ljava/io/InputStream;)V");
 ctMethod.setBody("{ this.a = new com.aspose.cells.License();com.aspose.cells.zbfo.a();}");
 CtMethod jMethod = ctClass.getDeclaredMethod("j");
 Method.setBody("{return new java.util.Date(java.lang.Long.MAX_VALUE);}");
 ctClass.writeFile("/Users/doge/test");
```

把生成好的class文件覆盖到jar包里面就ok啦.
