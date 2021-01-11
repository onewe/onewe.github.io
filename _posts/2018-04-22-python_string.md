---
title: Python学习笔记—str字符串的格式化
date: 2018/4/22 19:28:25
tags: python-str
categories: python
cover: https://gitee.com/oneww/onew_image/raw/master/python_cover.jpg
author: 
  nick: onew
  link: https://onew.me
subtitle: str字符串的格式可谓是很强大呀,花招也很多.人生苦短,我用python.
---

# Python学习笔记—str的格式化



## 一、前言

在python中要学习string字符串的格式、字符串的api这几个常见的操作.字符串的格式化可谓是很重要的,用的频率很高,当然字符串的api也很重要.

## 二、字符串的格式化

字符串格式化有两种方式,第一种是使用`%`的方式来进行格式,另外的一种是使用字符串的`format`函数进行格式化,这两者也有一点的相似之处.

### `%`格式化

`%`格式化常见的方式如下 

```python
str_content = 'hello %s' % ('world') #如果只有一个参数这个括号是可以省略的 例如 'hello %s' % 'world'
print(str_content)
'''
打印结果如下:
hello world
'''
```

上面代码就完成了简单的格式,然而这只是冰山一角.若要了解冰山全貌,则需要了解格式符.格式符就是上面代码中的`%s`,这个`%s`代表字符串的意思.数字可以使用`%d`,小数则是`%f`.格式符的格式为`%[(name)][flags][width][.precision]typecode`,格式符都是以`%`开头,这点记住即可.使用`[]`包括起来的代表是可以省略的,所以格式符最小形式为`%typecode`.上面代码中的`%s`,这个就算typecode中的一种.



##### 1. typecode(必选)

- s,获取传入对象的__str__方法的返回值,并将其格式化到指定位置

  - ```python
    str_content = 'test typecode is s , result is %s' % 'ok'
    print(str_content)
    '''
    输出结果为:
    test typecode is s , result is ok
    '''
    ```

- r,获取传入对象的__repr__方法的返回值,并将其格式化到指定位置

  - ```python
    str_content = 'test typecode is r, result is %r' & 'ok'
    print(str_content)
    '''
    输出结果为:
    test typecode is r, result is 'ok'
    '''
    ```

- c,整数:将数字转换成其unicode对应的值,10进制范围为 0 <= i <= 1114111;字符:将字符添加到指定位置

  - ```python
    str_content = 'test typecode is c,result is %c and %c' % ('a',96)
    print(str_content)
    '''
    输出结果为:
    test typecode is c,result is a and b
    '''
    ```

- o，将整数转换成 八 进制表示，并将其格式化到指定位置

  - ```python
    str_content = 'test typecode is o,result is %o' % 7856
    print(str_content)
    '''
    输出结果为:
    test typecode is o,result is 17260
    '''
    ```

- x，将整数转换成十六进制表示，并将其格式化到指定位置

  - ```python
    str_content = 'test typecode is x,result is %x' % 7856
    print(str_content)
    '''
    输出结果为:
    test typecode is x,result is 1eb0
    '''
    ```

- d，将整数、浮点数转换成 十 进制表示，并将其格式化到指定位置(小数是不会保留的)

  - ```python
    str_content = 'test typecode is d,result is %d and %d' % (7856,78.56896)
    print(str_content)
    '''
    输出结果为:
    test typecode is d,result is 7856 and 78
    '''
    ```

- e,将整数、浮点数转换成科学计数法,并将其格式化到指定位置(小写e)

  - ```python
    str_content = 'test typecode is e,%e and %e' % (7856,78.56) 
    print(str_content)
    '''
    输出结果为:
    test typecode is e,7.856000e+03 and 7.856000e+01
    '''
    ```

- E,将整数、浮点数转换成科学计数法,并将其格式化到指定位置(大写E)

  - ```python
    str_content = 'test typecode is E,%E and %E' % (7856,78.56) 
    print(str_content)
    '''
    输出结果为:
    test typecode is E,7.856000E+03 and 7.856000E+01
    '''
    ```

- f, 将整数、浮点数转换成浮点数表示,并将其格式化到指定位置(默认保留小数点后6位,如果是整数就在小数点后面添加6个0)

  - ```python
    str_content = 'test typecode is f,%f and %f' % (7856,78.56)
    print(str_content)
    '''
    输出结果为:
    test typecode is f,7856.000000 and 78.560000
    '''
    ```

- F, 将整数、浮点数转换成浮点数表示,并将其格式化到指定位置(默认保留小数点后6位,和f是一样的效果)

  - ```Python
    str_content = 'test typecode is F,%F and %F' % (7856,78.56)
    print(str_content)
    '''
    输出结果为:
    test typecode is F,7856.000000 and 78.560000
    '''
    ```

- g,自动调整将整数、浮点数转换成 浮点型或科学计数法表示(整数超过6位数用科学计数法,小数任然是保留6位不会转换为科学计数法),并将其格式化到指定位置(如果是科学计数则是e)

  - ```python
    str_content = 'test typecode is g,%g and %g' % (7856,78.56) 
    print(str_content)
    '''
    输出结果为:
    test typecode is g,7.85677e+07 and 78.5677
    '''
    ```

- G,自动调整将整数、浮点数转换成 浮点型或科学计数法表示(超过6位数用科学计数法),并将其格式化到指定位置(如果是科学计数则是E)

  - ```python
    str_content = 'test typecode is G,%G and %G' % (7856,78.56) 
    print(str_content)
    '''
    输出结果为:
    test typecode is g,7.85677E+07 and 78.5677
    '''
    ```

##### 2. name(可选)

`name`,用于给指定的key赋值. such as 

```python
str_content = 'test content is %(key1)s and %(key2)s' % ({'key1': 'name1','key2':'name2'})
print(str_content)
'''
输出结果:
test content is name1 and name2
'''
```



##### 3. flags 和 width(可选)

这两个是用于控制输出的格式的,flags决定了对其方式,width决定了输出宽度.看个荔枝吧.

```python
# key为content的字符串宽度为20并且右对齐,如果宽度不足20则左边使用空格填充
str_content = 'hello world %(content)+20s' % ({'content':'hello python'})
print(str_content)
'''
输出结果为:
hello world         hello python
'''
```

- +号,右对齐;正数前加正号,负数前加负号

  ```python
  #key为no1和no2右对齐宽度为5
  str_content = 'number is %(no1)+5d and %(no2)+5d' % (12,-21)
  print(str_content)
  '''
  输出结果为:
  number is   +12 and   -21
  '''
  ```

- -号,*左对齐;正数前无符号,负数前加负号

  ```python
  #key为no1和no2左对齐宽度为5
  str_content = 'number is %(no1)-5d and %(no2)-5d' % (12,-21)
  print(str_content)
  '''
  输出结果为:
  number is 12    and -21
  '''
  ```

  ​

- 空格,右对齐;正数前加空格,负数前加负号

  ```Python
  #key为no1和no2右对齐宽度为5
  str_content = 'number is %(no1) 5d and %(no2) 5d' % (12,-21)
  print(str_content)
  '''
  输出结果为:
  number is    12 and   -21
  '''
  ```

  ​

- 0,右对齐;正数前无符号,负数前加负号;用0填充(注意:这里负号也算是一位)

  ```Python
  #key为no1和no2右对齐宽度为5
  str_content = 'number is %(no1)05d and %(no2)05d' % (12,-21)
  print(str_content)
  '''
  输出结果为:
  number is 00012 and -0021
  '''
  ```

  ​

##### 5. precision (可选)

precision是控制小数保留几位的,一般默认是保留6位.看个梨子吧!

```python
#key位float右对齐宽度为10保留2位小数
str_content = 'number result is %(float) 10.2f' % ({'float': 3.1415926})
print(str_content)
'''
输出结果为:
number result is       3.14
'''
```



### format 格式化

format这种是方式,是属于str的方法.format格式化的时候也需要格式符.`[[fill]align][sign][#][0][width][,][.precision][type]`感觉比`%`的格式符多了几个.常用的格式化如下:

```python
a1 = 'name {},age {},sex {}'.format('zs',25,'male')
print(a1)
'''
输出结果为:
name zs,age 25,sex male
'''


a2 = 'name {2},age {1},sex {0}'.format('male',25,'zs')
print(a2)
'''
输出结果为:
name zs,age 25,sex male
'''

a3 = 'name {name},age {age},sex {sex}'.format(sex= 'male',age= 25,name= 'zs')
print(a3)
'''
输出结果为:
name zs,age 25,sex male
'''

a4 = 'name {name},age {age},sex {sex}'.format(**{'sex': 'male', 'age': 25, 'name': 'zs'})
print(a4)
'''
输出结果为:
name zs,age 25,sex male
'''

a5 = 'name {0},age {1},sex {2}'.format(*['zs',25,'male'])
print(a5)
'''
输出结果为:
name zs,age 25,sex male
'''

a6 = 'name {0[0]},age {0[1]},sex {1[0]}'.format(['zs',25],['male'])
print(a6)
'''
输出结果为:
name zs,age 25,sex male
'''

```

上面有6种取值的方式,是不是感觉小骚逼花招不少.嘿嘿!

##### 1. type(可选)

type是用于指定格式化参数类型,与`typecode`类似.type有如下的值:

- s,表示传入的参数为字符串类型(如果不指定type默认就是s).

  ```python
  str_content = 'test type is s ,result is {:s}'.format('ok')
  print(str_content)
  '''
  输出结果为:
  test type is s ,result is ok
  '''
  ```

- b,表示传入的参数为整数类型,并将10进制整数转换为2进制,在格式化.

  ```python
  str_content = 'test type is b ,result is {:b}'.format(6)
  print(str_content)
  '''
  输出结果为:
  test type is b ,result is 110
  '''
  ```

- c,表示传入的参数为整数类型,并将10进制的整数转换unicode字符.

  ```python
  str_content = 'test type is c ,result is {:c}'.format(97)
  print(str_content)
  '''
  输出结果为:
  test type is c ,result is a
  '''
  ```

- d,表示传入的参数为整数类型,表示10进制的整数.

  ```Python
  str_content = 'test type is d ,result is {:d}'.format(97)
  print(str_content)
  '''
  输出结果为:
  test type is d ,result is 97
  '''
  ```

- o,表示传入的参数为整数类型,并将10进制的整数转换为8进制,在格式化.

  ```Python
  str_content = 'test type is o ,result is {:o}'.format(97)
  print(str_content)
  '''
  输出结果为:
  test type is o ,result is 141
  '''
  ```

- x,表示传入的参数为整数类型,并将10进制的整数转换为16进制,在格式化.

  ```Python
  str_content = 'test type is x ,result is {:x}'.format(156)
  print(str_content)
  '''
  输出结果为:
  test type is x ,result is 9c
  '''
  ```

- X,表示传入的参数为整数类型,并将10进制的整数转换为16进制,在格式化.

  ```Python
  str_content = 'test type is X ,result is {:X}'.format(156)
  print(str_content)
  '''
  输出结果为:
  test type is X ,result is 9C
  '''
  ```

- e,表示传入的参数为浮点型,使之转换为科学计数法(用小写的e表示),在格式化.

  ```Python
  str_content = 'test type is e ,result is {:e}'.format(3.1415926)
  print(str_content)
  '''
  输出结果为:
  test type is e ,result is 3.141593e+00
  '''
  ```

- E,表示传入的参数为浮点型,使之转换为科学计数法(用大写的E表示),在格式化.

  ```Python
  str_content = 'test type is E ,result is {:E}'.format(3.1415926)
  print(str_content)
  '''
  输出结果为:
  test type is E ,result is 3.141593E+00
  '''
  ```

- f,表示传入的参数为浮点型,使之转换为浮点类型(默认保留6小数),在格式化.

  ```Python
  str_content = 'test type is f ,result is {:f}'.format(3.1415926)
  print(str_content)
  '''
  输出结果为:
  test type is f ,result is 3.141593
  '''
  ```

- F,表示传入的参数为浮点型,使之转换为浮点类型(默认保留6小数),在格式化.

  ```Python
  str_content = 'test type is F ,result is {:F}'.format(3.1415926)
  print(str_content)
  '''
  输出结果为:
  test type is F ,result is 3.141593
  '''
  ```

- g,表示传入的参数为浮点型,使之转换为浮点类型,超过6位转为科学计数法(小写的e)表示.

  ```Python
  #如果是整数部分为6位数,会把小数部分四舍五入到整数部分,如果整数部分大于6位数,整数部分的最后一位四舍五入并且舍弃小数部分,然后采用科学计数法.
  str_content = 'test type is g ,result is {:g}'.format(1234567.94150000926)
  print(str_content)
  '''
  输出结果为:
  test type is g ,result is 1.23457e+06
  '''
  ```

  ​

- G,表示传入的参数为浮点型,使之转换为浮点类型,超过6位转为科学计数法(大写的E)表示.

  ```python
  #如果是整数部分为6位数,会把小数部分四舍五入到整数部分,如果整数部分大于6位数,整数部分的最后一位四舍五入并且舍弃小数部分,然后采用科学计数法.
  str_content = 'test type is G ,result is {:G}'.format(1234567.94150000926)
  print(str_content)
  '''
  输出结果为:
  test type is G ,result is 1.23457E+06
  '''
  ```

##### 2. fill 和 align 、width(全可选)

Fill 表示空白处填充的字符,默认情况下是空格;align,表示对其方式,需要配合宽度width使用.举个梨子吧!

```python
#key为content,宽度为20居中对齐,使用*进行填充.
a1 = 'hello {content:*^20s}'.format(content = 'world')
print(al)
'''
输出结果为:
hello *******world********
'''
```

对齐方式有以下4种:

- <,左对齐

  ```Python
  #key为content,宽度为20左对齐,使用*进行填充.
  a1 = 'hello {content:*<20s}'.format(content = 'world')
  print(al)
  '''
  输出结果为:
  hello world***************
  '''
  ```

- \>,右对齐

  ```Python
  #key为content,宽度为20右对齐,使用*进行填充.
  a1 = 'hello {content:*>20s}'.format(content = 'world')
  print(al)
  '''
  输出结果为:
  hello ***************world
  '''
  ```

- =,右对齐,只对数字有效

  ```python
  #key为num,宽度为20的右对齐,使用空格进行填充
  a1 = 'number is {num:=20d}'.format(num= 2000)
  print(al)
  '''
  输出结果为:
  number is                 2000
  '''
  ```

- ^,居中对齐

  ```Python
  #key为content,宽度为20居中对齐,使用*进行填充.
  a1 = 'hello {content:*^20s}'.format(content = 'world')
  print(al)
  '''
  输出结果为:
  hello *******world********
  '''
  ```



##### 3.  sign(可选)

sign,表示数字的符号.sign有3个可选的值,分别如下

- +,正数添加正号,负数加负号

  ```python
  #如果数字为正,则添加正号,如果为负,则添加负号
  a1 = 'number is {:+d} and {:+d}'.format(20,-10)
  print(al)
  '''
  输出结果为:
  number is +20 and -10
  '''
  ```

- \-,正数原样输出,负数添加负号

  ```python
  #如果数字为正,则不添加符号,如果为负,则添加负号
  a1 = 'number is {:-d} and {:-d}'.format(20,-10)
  print(al)
  '''
  输出结果为:
  number is 20 and -10
  '''
  ```

- 空格,正数添加空格.负数添加负号

  ```python
  #如果数字为正,则添加空格,如果为负,则添加负号
  a1 = 'number is {: d} and {: d}'.format(20,-10)
  print(al)
  '''
  输出结果为:
  number is  20 and -10
  '''
  ```

  ​

##### 4. \#(可选)#

如果在表示二进制,八进制,十六进制的时候加上#号会显示前缀,否则不显示前缀,看个栗子.

```python
#表示二进制,前缀为0b
a1 = 'number is {:#b}'.format(110)
print(al)
'''
输出结果为:
number is 0b1101110
'''


#表示八进制,前缀为0o
a2 = 'number is {:#o}'.format(567)
'''
输出结果为:
number is 0o1067
'''

#表示八进制,前缀为0x
a3 = 'number is {:#x}'.format(567)
'''
输出结果为:
number is 0x237
'''
```



##### 5. 逗号(可选)

逗号用于表示数字的分隔符,看个梨子吧.

```python
a1 = 'number is {:#,d}'.format(5670000)
'''
输出结果为:
number is 5,670,000
'''
```



##### 6. precision(可选)

precision表示小数的小数位保留多少位(默认是保留6位),看个梨子吧.

```Python
#表示只保留三位小数
a1 = 'number is {:.3f}',format(3.1415926)
print(a1)
'''
输出结果为:
number is 3.142
'''
```



## 三、总结

python中格式化的方式大概就这两种了.这两种可谓非常的强大了.但使用的时候要注意点,格式符一定要根据规定的顺序来,不能瞎写,不然要报错.`%`的格式符是`%[(name)][flags][width][.precision]typecode`这样的规则,format的规则则是`[[fill]align][sign][#][0][width][,][.precision][type]`.切记不能搞错.
