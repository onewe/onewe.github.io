---
title: "[断点分析之spring-ioc]-bean属性填充与初始化(九)"
date: 2020/03/04 17:20:25
tags:
- spring
- java
categories: spring
cover: https://gitee.com/oneww/onew_image/raw/master/spring_cover.png
author: 
  nick: onew
  link: https://onew.me
subtitle: spring bean的属性填充与初始化
---

# 一、前言

​	bean是创建好了,但还需要一些属性填充,初始化等操作.

```java
	// 属性填充
	populateBean(beanName, mbd, instanceWrapper);
	// 初始化bean
	exposedObject = initializeBean(beanName, exposedObject, mbd);
```



# 二、populateBean

```java
protected void populateBean(String beanName, RootBeanDefinition mbd, @Nullable BeanWrapper bw) {
		// 跳过 null bean 赋值
		if (bw == null) {
			if (mbd.hasPropertyValues()) {
				throw new BeanCreationException(
						mbd.getResourceDescription(), beanName, "Cannot apply property values to null instance");
			}
			else {
				// Skip property population phase for null instance.
				return;
			}
		}

		// Give any InstantiationAwareBeanPostProcessors the opportunity to modify the
		// state of the bean before properties are set. This can be used, for example,
		// to support styles of field injection.
		// 判断是否是拥有InstantiationAwareBeanPostProcessor
		if (!mbd.isSynthetic() && hasInstantiationAwareBeanPostProcessors()) {
			// 遍历所有BeanPostProcessor
			for (BeanPostProcessor bp : getBeanPostProcessors()) {
				// 针对InstantiationAwareBeanPostProcessor 进行调用
				if (bp instanceof InstantiationAwareBeanPostProcessor) {
					InstantiationAwareBeanPostProcessor ibp = (InstantiationAwareBeanPostProcessor) bp;
					if (!ibp.postProcessAfterInstantiation(bw.getWrappedInstance(), beanName)) {
						return;
					}
				}
			}
		}

		PropertyValues pvs = (mbd.hasPropertyValues() ? mbd.getPropertyValues() : null);

		// 获取自动注入模式
		int resolvedAutowireMode = mbd.getResolvedAutowireMode();
		// 根据名称 或者 类型 自动注入
		if (resolvedAutowireMode == AUTOWIRE_BY_NAME || resolvedAutowireMode == AUTOWIRE_BY_TYPE) {
			MutablePropertyValues newPvs = new MutablePropertyValues(pvs);
			// Add property values based on autowire by name if applicable.
			// 处理根据名称注入
			if (resolvedAutowireMode == AUTOWIRE_BY_NAME) {
				autowireByName(beanName, mbd, bw, newPvs);
			}
			// Add property values based on autowire by type if applicable.
			// 处理根据类型注入
			if (resolvedAutowireMode == AUTOWIRE_BY_TYPE) {
				autowireByType(beanName, mbd, bw, newPvs);
			}
			pvs = newPvs;
		}

		boolean hasInstAwareBpps = hasInstantiationAwareBeanPostProcessors();
		// 是否需要依赖检查
		boolean needsDepCheck = (mbd.getDependencyCheck() != AbstractBeanDefinition.DEPENDENCY_CHECK_NONE);

		PropertyDescriptor[] filteredPds = null;
		// BeanPostProcessor 处理
		if (hasInstAwareBpps) {
			if (pvs == null) {
				pvs = mbd.getPropertyValues();
			}
			// 遍历所有的 BeanPostProcessor
			for (BeanPostProcessor bp : getBeanPostProcessors()) {
				if (bp instanceof InstantiationAwareBeanPostProcessor) {
					InstantiationAwareBeanPostProcessor ibp = (InstantiationAwareBeanPostProcessor) bp;
					PropertyValues pvsToUse = ibp.postProcessProperties(pvs, bw.getWrappedInstance(), beanName);
					if (pvsToUse == null) {
						if (filteredPds == null) {
							filteredPds = filterPropertyDescriptorsForDependencyCheck(bw, mbd.allowCaching);
						}
						pvsToUse = ibp.postProcessPropertyValues(pvs, filteredPds, bw.getWrappedInstance(), beanName);
						if (pvsToUse == null) {
							return;
						}
					}
					pvs = pvsToUse;
				}
			}
		}
		// 依赖检查
		if (needsDepCheck) {
			if (filteredPds == null) {
				filteredPds = filterPropertyDescriptorsForDependencyCheck(bw, mbd.allowCaching);
			}
			checkDependencies(beanName, mbd, filteredPds, pvs);
		}
		// 将属性应用到 bean 中
		if (pvs != null) {
			applyPropertyValues(beanName, mbd, bw, pvs);
		}
	}
```

​	可以看到`InstantiationAwareBeanPostProcessor`对象的调用时机分别是在创建对象后调用了`postProcessAfterInstantiation`方法,在注入完了后调用了`postProcessProperties`方法,随即填充属性.



# 三、initializeBean

```java
protected Object initializeBean(final String beanName, final Object bean, @Nullable RootBeanDefinition mbd) {
		if (System.getSecurityManager() != null) {
			AccessController.doPrivileged((PrivilegedAction<Object>) () -> {
				invokeAwareMethods(beanName, bean);
				return null;
			}, getAccessControlContext());
		}
		else {
			// 对实现Aware接口的类进行注入例如BeanFactoryAware等接口
			invokeAwareMethods(beanName, bean);
		}

		Object wrappedBean = bean;
		if (mbd == null || !mbd.isSynthetic()) {
			// 前置处理
			wrappedBean = applyBeanPostProcessorsBeforeInitialization(wrappedBean, beanName);
		}

		try {
			// 调用用户的init方法
			invokeInitMethods(beanName, wrappedBean, mbd);
		}
		catch (Throwable ex) {
			throw new BeanCreationException(
					(mbd != null ? mbd.getResourceDescription() : null),
					beanName, "Invocation of init method failed", ex);
		}
		if (mbd == null || !mbd.isSynthetic()) {
			// 后置处理
			wrappedBean = applyBeanPostProcessorsAfterInitialization(wrappedBean, beanName);
		}

		return wrappedBean;
	}
```

1. 对实现Aware接口的进行注入
2. 调用PostProcessor的前置方法`postProcessBeforeInitialization`
3. 初始化bean 初始化方法
4. 初始化完毕后调用PostProcessors的后置方法`postProcessAfterInitialization`



单利的创建流程记录完毕,其他scope的创建方式都是大同小异,不再重复记录.



# 四、小结

​	创建的过程终于走完了:)
