---
title: List源码通读之ArrayList(一)
date: 2019/10/31 17:39:12
tags:
- java
- list
- arrayList
categories: java
cover: ./img/List_relationship.jpg
author: 
  nick: onew
  link: https://onew.me
subtitle: 通读jdk源码之ArrayList
---

# 一、前言

list集合作为在日常使用中是频率较高的一个类,接下来会用比较啰嗦的形式,做个源码阅读的笔记.list直接之类关系如下,不涉及到javax中的类.

![image](./img/List_relationship.jpg)

如上图所示,直接子类在util包中的有5个,这章将会重点解读一下Arraylist,