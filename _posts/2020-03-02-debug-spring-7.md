---
title: "[断点分析之spring-ioc]-BeanDefinitionHolder注册(七)"
date: 2020/03/02 14:20:25
tags:
- spring
- java
categories: spring
cover: https://gitee.com/oneww/onew_image/raw/master/spring_cover.png
author: 
  nick: onew
  link: https://onew.me
subtitle: spring BeanDefinitionHolder注册
---



# 一、前言

​	通过前面大批量的工作,终于要到注册BeanDefinitionHolder这一步了.当然还是通过一下代码作为入口进行分析.

```java
protected void processBeanDefinition(Element ele, BeanDefinitionParserDelegate delegate) {
		// 解析xml元素
		BeanDefinitionHolder bdHolder = delegate.parseBeanDefinitionElement(ele);
		if (bdHolder != null) {
			// 装饰bean
			bdHolder = delegate.decorateBeanDefinitionIfRequired(ele, bdHolder);
			try {
				// Register the final decorated instance.
				// 注册bean到容器中
				BeanDefinitionReaderUtils.registerBeanDefinition(bdHolder, getReaderContext().getRegistry());
			}
			catch (BeanDefinitionStoreException ex) {
				getReaderContext().error("Failed to register bean definition with name '" +
						bdHolder.getBeanName() + "'", ele, ex);
			}
			// Send registration event.
			// 发送事件
			getReaderContext().fireComponentRegistered(new BeanComponentDefinition(bdHolder));
		}
	}
```

​	解析、装饰都已经记录了,解析来的重点就是`BeanDefinitionReaderUtils.registerBeanDefinition(bdHolder, getReaderContext().getRegistry());`这句代码了.



# 二、分析

```java
public static void registerBeanDefinition(
			BeanDefinitionHolder definitionHolder, BeanDefinitionRegistry registry)
			throws BeanDefinitionStoreException {
		// 注册 bean
		// Register bean definition under primary name.
		// 获取 bean 的名称
		String beanName = definitionHolder.getBeanName();
		// 注册
		registry.registerBeanDefinition(beanName, definitionHolder.getBeanDefinition());

		//注册 bean 的所有别名
		// Register aliases for bean name, if any.
		String[] aliases = definitionHolder.getAliases();
		if (aliases != null) {
			for (String alias : aliases) {
				registry.registerAlias(beanName, alias);
			}
		}
	}
```

1. 通过bean的名称进行注册
2. 通过bean的别名进行注册



`BeanDefinitionRegistry`这个对象是通过`XmlReaderContext`中获取的.

```java
// XmlReaderContext
public final BeanDefinitionRegistry getRegistry() {
		return this.reader.getRegistry();
	}
```

​	而这个reader则是`XmlBeanDefinitionReader`,`registry`对象则通过`XmlBeanDefinitionReader`的构造方法传入进来,实际上这个`registry`对象就是`XmlBeanFactory`或者说是`DefaultListableBeanFactory`,因为这两个有继承关系.

​	![images](https://gitee.com/oneww/onew_image/raw/master/XmlBeanFactory.png)





## 2.1 registerBeanDefinition



```java
// DefaultListableBeanFactory
@Override
	public void registerBeanDefinition(String beanName, BeanDefinition beanDefinition)
			throws BeanDefinitionStoreException {

		Assert.hasText(beanName, "Bean name must not be empty");
		Assert.notNull(beanDefinition, "BeanDefinition must not be null");

		if (beanDefinition instanceof AbstractBeanDefinition) {
			try {
				// 校验 bean 的定义是否合法
				((AbstractBeanDefinition) beanDefinition).validate();
			}
			catch (BeanDefinitionValidationException ex) {
				throw new BeanDefinitionStoreException(beanDefinition.getResourceDescription(), beanName,
						"Validation of bean definition failed", ex);
			}
		}
		// 从缓存中取出 BeanDefinition
		BeanDefinition existingDefinition = this.beanDefinitionMap.get(beanName);
		// bean 已被注册过
		if (existingDefinition != null) {
			// 如果不允许重复注册则抛出异常
			if (!isAllowBeanDefinitionOverriding()) {
				throw new BeanDefinitionOverrideException(beanName, beanDefinition, existingDefinition);
			}
			else if (existingDefinition.getRole() < beanDefinition.getRole()) {
				// e.g. was ROLE_APPLICATION, now overriding with ROLE_SUPPORT or ROLE_INFRASTRUCTURE
				if (logger.isInfoEnabled()) {
					logger.info("Overriding user-defined bean definition for bean '" + beanName +
							"' with a framework-generated bean definition: replacing [" +
							existingDefinition + "] with [" + beanDefinition + "]");
				}
			}
			else if (!beanDefinition.equals(existingDefinition)) {
				if (logger.isDebugEnabled()) {
					logger.debug("Overriding bean definition for bean '" + beanName +
							"' with a different definition: replacing [" + existingDefinition +
							"] with [" + beanDefinition + "]");
				}
			}
			else {
				if (logger.isTraceEnabled()) {
					logger.trace("Overriding bean definition for bean '" + beanName +
							"' with an equivalent definition: replacing [" + existingDefinition +
							"] with [" + beanDefinition + "]");
				}
			}
			// 放入到 map 中
			// 覆盖
			this.beanDefinitionMap.put(beanName, beanDefinition);
		}
		else {
			// 判断是否有创建中的bean
			if (hasBeanCreationStarted()) {
				// Cannot modify startup-time collection elements anymore (for stable iteration)
				// 加锁
				// 不能修改启动时的集合,需要重新创建一个集合
				synchronized (this.beanDefinitionMap) {
					// 放入map中
					this.beanDefinitionMap.put(beanName, beanDefinition);
					List<String> updatedDefinitions = new ArrayList<>(this.beanDefinitionNames.size() + 1);
					updatedDefinitions.addAll(this.beanDefinitionNames);
					updatedDefinitions.add(beanName);
					this.beanDefinitionNames = updatedDefinitions;
					// 如果这个已经 bean 在存在 则移除
					removeManualSingletonName(beanName);
				}
			}
			else {
				// Still in startup registration phase
				this.beanDefinitionMap.put(beanName, beanDefinition);
				this.beanDefinitionNames.add(beanName);
        // 如果这个已经 bean 在存在 则移除
				removeManualSingletonName(beanName);
			}
			this.frozenBeanDefinitionNames = null;
		}
		//注册成功,如果是重复注册的则销毁之前注册的bean
		if (existingDefinition != null || containsSingleton(beanName)) {
			resetBeanDefinition(beanName);
		}
	}
```

​	这个阶段呢,bean都还没开始创建,都是在做解析,注册之类的事情,所以这里有一个判断看起来比较迷惑`hasBeanCreationStarted`.或许后面才会知道这个判断条件有啥用吧.

1. 验证`beanDefinition`是否合法

 	2. 判断bean是否被注册过,如果不允许重复注册则抛出异常
 	3. 如果允许重复注册则放入`beanDefinitionMap`这个map集合中
 	4. 如果该`beanDefinition`未被注册过,则添加映射到`beanDefinitionMap`中去和`beanDefinitionNames`集合中去.
 	5. 注册成功,如果是重复注册的则销毁之前注册的bean



## 2.2 registerAlias

```java
// SimpleAliasRegistry
@Override
	public void registerAlias(String name, String alias) {
		Assert.hasText(name, "'name' must not be empty");
		Assert.hasText(alias, "'alias' must not be empty");
		// 加锁 并发控制
		synchronized (this.aliasMap) {
			// 判断 bean 名称是否与别名相同,如果相同则忽略
			if (alias.equals(name)) {
				// 移除别名
				this.aliasMap.remove(alias);
				if (logger.isDebugEnabled()) {
					logger.debug("Alias definition '" + alias + "' ignored since it points to same name");
				}
			}
			else {
				// 判断别名是否已存在
				String registeredName = this.aliasMap.get(alias);
				if (registeredName != null) {
					// 如果别名对应的bean的名称与name相同则忽略
					if (registeredName.equals(name)) {
						// An existing alias - no need to re-register
						return;
					}
					// 是否允许覆盖,如果不允许则报错
					if (!allowAliasOverriding()) {
						throw new IllegalStateException("Cannot define alias '" + alias + "' for name '" +
								name + "': It is already registered for name '" + registeredName + "'.");
					}
					if (logger.isDebugEnabled()) {
						logger.debug("Overriding alias '" + alias + "' definition for registered name '" +
								registeredName + "' with new target name '" + name + "'");
					}
				}
				//检查是否有循环引用别名 例如:A-B C-B A-C
				checkForAliasCircle(name, alias);
				//映射别名和名称到map中
				this.aliasMap.put(alias, name);
				if (logger.isTraceEnabled()) {
					logger.trace("Alias definition '" + alias + "' registered for name '" + name + "'");
				}
			}
		}
	}
```

1. 判断别名是否与bean名称是否相同
2. 如果相同则移除别名
3. 判断别名是否已经存在
4. 如果不存在检查是否存在循环引用
5. 映射别名



​	这里检测是否存在循环引用比较有意思,之前文章应该记录到了这块儿的逻辑.



# 三、小结

​	bean的解析与注册已经分析完了,接下来就是重头戏了,终于要看看 spring 是怎么根据`BeanDefinition`来创建bean对象.
