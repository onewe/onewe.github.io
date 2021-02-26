---
title: python新手38行代码挑战bad apple 
date: 2018/3/12 23:48:15
comments: true
key: python-image-2018-03-12
tags: bad apple
categories: python
cover: http://upload-images.jianshu.io/upload_images/8958298-af9844d5869bd35e..jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240
author: 
  nick: onew
  link: https://onew.me
subtitle: 人生苦短,我用python.嗯,对就是这样的.
---
# 进入正题
> 最近在学习python,也才学习两天吧,可谓是零基础,但是通过这两天的接触让我明白了python真的是简单易学的语言,于是我就膨胀了.看到bad apple 字符动画挺火的就像来跃跃欲试,网上的貌似都是在网页上播放,我就想能不能做成一个视屏呢?

# 实现原理
 众所周知视屏其实就是由一副副图片组成的并按照一定的速度进行播放就形成了视频,所以可以把视频的每一帧提取出来进行修改,然后组成新的视频.首先我们先下载目标视频把目标视屏的每一帧提取成图片,然后把图片进行灰度处理形成灰度图,然后把每个像素映射成字符形成新的图片就可以了.(以上理论可能有错误,请包涵)

 # 来上代码
 ```python
# 我原视频是1400 * 1080 但是我们处理的时候要进行缩放 
import cv2
import numpy as np

#导入视频文件
cap = cv2.VideoCapture("test.mkv")
#创建字符数组
ascii_char = list("$B%8&WM#*oahkbdpqwmZO0QLCJUYXzcvunxrjft/\|()1{}[]?-_+~<>i!lI;:, ")
#指定保存视频的码率
fourcc = cv2.VideoWriter_fourcc(*'MJPG')
#创建视屏写出对象
out = cv2.VideoWriter('output.avi', fourcc, cap.get(cv2.CAP_PROP_FPS), (1440, 1080))
#循环读取源视频帧数
while True:
    ret,frame = cap.read()
    if ret is False:
        break
    #原视屏帧进行缩小
    resize = cv2.resize(frame, (int(1440 / 10), int(1080 / 10)), interpolation=cv2.INTER_CUBIC)
    #转换为灰度图
    gray = cv2.cvtColor(resize, cv2.COLOR_BGR2GRAY)
    #创建新的图片
    zeros = np.zeros((1080, 1440, 3), np.uint8)
    #使用白色填满整个图片
    zeros.fill(255)
    #遍历原视屏帧的整个像素
    for i, ivalue in enumerate(gray):
        result = ""
        for j, jvalue in enumerate(ivalue):
            #把每个像素点转换为字符串
            result += ascii_char[int(jvalue % len(ascii_char))]
        #把字符画在图片上
        cv2.putText(zeros, result, (10, i * 10), cv2.FONT_HERSHEY_PLAIN, 1, (0, 0, 0), 1, lineType=cv2.LINE_AA)
    #把图片输出到新的视频文件上
    out.write(zeros)
#释放资源
cap.release()
out.release()

 ```

 # 善后

 通过以上的步骤我们成功的生成了字符串动画,但是总感觉差点啥,是不是没声音呀??那就需要把音轨合成到视屏中去,那音轨又从哪里来呢??没关系我们可以从原视频中提取出来

 ## 提取音轨
  提取音轨可以使用ffmpeg 这个软件,在mac下可以通过brew进行安装,其他的操作系统我就不知道了.
  安装好后使用命令`ffmpeg -i 需要提取的目标视频文件 输出文件名`来提取音轨文件
## 音轨合成到原视频
    上面提取成功了音轨,这里要说说怎么把音轨合成到视频中,同样使用命令`ffmpeg -i 音轨文件 -i 需要合成的目标文件 输出文件名称`

# 效果
 视频就不展示,看一下gif图吧  

 ![image](https://upload-images.jianshu.io/upload_images/8958298-5fc487339f9d5554.gif?imageMogr2/auto-orient/strip)

