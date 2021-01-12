---
title: python学习笔记-list
date: 2018/3/26 17:55:34
key: python-list-2018-03-26
comments: true
tags: python-list
categories: python
cover: http://upload-images.jianshu.io/upload_images/8958298-af9844d5869bd35e..jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240
author: 
  nick: onew
  link: https://onew.me
subtitle: 列表常用的数据结构,在python中可以很轻松的使用它.人生苦短,我用python.
---

# 列表
> emmmmm列表吧,跟java中的list是差不多的,只不过python中的列表写法更简洁,下面记录一下学习的笔记

代码
```python
#创建一个列表
name = [1,2,3,4,5,6,7]
#取小标为1的元素
print(name[1])
#从下标1开始取到下标为3(不包括3)
print(name[1:3])
#从下标1开始取到最后一个,不包括最后一个
print(name[1:-1])
#从下标1开始取到最后一个,包括最后一个
print(name[1:])
#删除下标为1的元素
del name[1]
print(name)
#追加元素到末尾
name.append(8)
print(name)
#统计列表中元素的个数
name.append(3)
count = name.count(3)
print(count)
#把一个列表合并到另外一个列表中
name.extend([99,88])
print(name)
#在列表中查找元素为3的索引
index = name.index(3)
print(index)
#在指定列表范围(索引4到最后)中查找元素为3的索引
index1 = name.index(3, 4, -1)
print(index1)
#反转列表
name.reverse()
print(name)
#排序,默认自然排序
name.sort()
print(name)
#copy一份列表
name_copy = name.copy()
print(name_copy)
#指定位置插入指定的元素
name.insert(2,76)
print(name)
print(name_copy)
#取出一个元素并从列表中弹出
pop = name.pop(2)
print(pop)
print(name)
pop_end = name.pop()
print(pop_end)
print(name)
#移除指定元素
name.remove(88)
print(name)
#清空列表
name.clear()
print(name)

```

运行结果
```
2  
[2, 3]
[2, 3, 4, 5, 6]
[2, 3, 4, 5, 6, 7]
[1, 3, 4, 5, 6, 7]
[1, 3, 4, 5, 6, 7, 8]
2
[1, 3, 4, 5, 6, 7, 8, 3, 99, 88]
1
7
[88, 99, 3, 8, 7, 6, 5, 4, 3, 1]
[1, 3, 3, 4, 5, 6, 7, 8, 88, 99]
[1, 3, 3, 4, 5, 6, 7, 8, 88, 99]
[1, 3, 76, 3, 4, 5, 6, 7, 8, 88, 99]
[1, 3, 3, 4, 5, 6, 7, 8, 88, 99]
76
[1, 3, 3, 4, 5, 6, 7, 8, 88, 99]
99
[1, 3, 3, 4, 5, 6, 7, 8, 88]
[1, 3, 3, 4, 5, 6, 7, 8]
[]

```

- 创建列表也可以这样写`name = list([1,2,3,4,5,6])`,毕竟他们的api都是一样的

---

迭代列表
```python
name = list([1,0,3,4,5,6])
print(name)


print("\n**********直接迭代**********\n")
for i in name:
    print(i, end=",")
print("\n**********下标迭代**********\n")
for i in range(name.__len__()):
    print(name[i], end=",")
print("\n**********下标与值一起迭代*****\n")
for i,v in enumerate(name):
    print('index:%s,value:%s'%(i,v))


```

运行结果
```
[1, 0, 3, 4, 5, 6]
**********直接迭代**********
1,0,3,4,5,6,
**********下标迭代**********
1,0,3,4,5,6,
**********下标与值一起迭代*****
index:0,value:1
index:1,value:0
index:2,value:3
index:3,value:4
index:4,value:5
index:5,value:6

```
