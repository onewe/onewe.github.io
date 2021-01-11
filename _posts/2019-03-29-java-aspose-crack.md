---
title: 暴力破解aspose.word.19.3
date: 2019/3/29 14:14:25
tags:
- java
- aspose
- aspose crack
categories: java
cover: https://gitee.com/oneww/onew_image/raw/master/java_aspose_cover.png
author: 
  nick: onew
  link: https://onew.me
subtitle: 9行代码搞定java版本aspose.word.19.3 license验证
---



# 一、前言

最近遇到一个需求根据word模板导出word文档,调研了一圈发现aspose比较好用,但缺点就是aspose需要收费.如果不付费就会出现水印.于是按照免费即是最好的,最好有破解的想法,尝试了一下如果绕过aspose的license验证.



# 二、分析

```java
 				License aposeLic = new License();
        FileInputStream stream = new FileInputStream("license.xml");//许可xml
        aposeLic.setLicense(stream);
        boolean licensed = aposeLic.isLicensed();
        System.out.println(licensed);
```

根据以上的代码就可以根据`aposeLic.setLicense(stream);`这句话追踪进去.

```java
//反编译出
//License.class
public void setLicense(InputStream stream) throws Exception {
        if (stream == null) {
            throw new NullPointerException("stream");
        } else {
            (new zzZLD()).zzW(stream);
        }
}

//进入new zzZLD()).zzW(stream) 这个方法
//反编译出
//zzZLD.class final void zzW(InputStream var1)
final void zzW(InputStream var1) throws Exception {
        if (var1 == null) {
            throw new NullPointerException("stream");
        } else {
              .......
                } else {
                    } else if ((new Date()).after(this.zzYPO)) {
                        throw new IllegalStateException("The license has expired.");
                    } else {
                        this.zzYPN = 1;
                        zzYPM = this;
                    }
                }
            } else {
                throw new IllegalStateException("This license is disabled, please contact Aspose to obtain a new license.");
            }
        }
    }


```

可以从zzW方法中看出,有部分的验证逻辑在里面,如果最终通过验证会修改`zzYPN`和`zzYPM`这两个变量,先把这个几下,看看这两变量有啥用.

在`zzZLD.class`中可以看到这两个变量在`zzZoR`方法和`zzZoQ`方法中参与运算.

```java
//反编译出 
//zzZLD.class
static int zzZoR() {
        boolean var0 = zzYPM == null || zzYPM.zzYPN == 0 || (new Date()).after(zzYPM.zzYPO) || zzYRK.zzYEL() == 4096;
        boolean var1 = zzZGS.zzZg4() == 0;
        return var0 && var1 ? 0 : 1;
    }

    static int zzZoQ() {
        boolean var0 = zzYPM == null || zzYPM.zzYPN == 0 || (new Date()).after(zzYPM.zzYPO) || zzYRK.zzYEL() == 4096;
        boolean var1 = zzZGS.zzZg4() == 0;
        return var0 && var1 ? 0 : 1;
    }
```

从以上两个方法返回值可以看出是验证license是否有效的方法.

```java
//反编译出
//License.class 
public boolean isLicensed() {
        return zzZLD.zzZoQ() == 1;
    }
```

看到`isLicensed`这个方法我就更加确定了,但是这两个方法,看起来逻辑完全一模一样.emmmmmm.那么怎么破解呢?



# 三、破解

破解思路是利用`javassist`修改掉`zzZLD`类中的`zzW`方法的验证逻辑.

```java
CtClass zzZLDClass = ClassPool.getDefault().getCtClass("com.aspose.words.zzZLD");
CtMethod zzW = zzZLDClass.getDeclaredMethod("zzW");
zzW.setBody("{this.zzYPO = new java.util.Date(Long.MAX_VALUE);this.zzYPN = 1;zzYPM = this;}");
zzZLDClass.writeFile("~/project/aspose");
```

这里设置`Date(Long.MAX_VALUE)`是有原因的,因为在`zzZoR`方法和`zzZoQ`方法中会进行一个after的一个判断,只要`var0`变量为false那么就会返回1,这样验证就通过了.

emmmm,但是仅仅是这样还不够,因为在验证的条件中还有一个`zzYRK.zzYEL() == 4096`条件,如果不直接改`zzZoR`方法和`zzZoQ`方法的话就需要修改`zzYEL()`方法的返回值为256即可.

```java
CtClass zzYRKClass = ClassPool.getDefault().getCtClass("com.aspose.words.zzYRK");
CtMethod zzYELMethod = zzYRKClass.getDeclaredMethod("zzYEL");
zzYELMethod.setBody("{return 256;}");
zzYRKClass.writeFile("~/project/aspose");
```

Ok.以上就搞定了,把修改好的class覆盖掉jar中的class就行了.

对了,还要删除jar中的META-INF文件夹,因为aspose会进行一个文件指纹验证.
