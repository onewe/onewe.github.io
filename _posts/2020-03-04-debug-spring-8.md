---
title: "[断点分析之spring-ioc]-bean的创建(八)"
date: 2020/03/04 16:20:25
tags:
- spring
- java
categories: spring
cover: https://gitee.com/oneww/onew_image/raw/master/spring_cover.png
author: 
  nick: onew
  link: https://onew.me
subtitle: spring bean的创建
---

# 一、前言

​	经过前面的一顿折腾,终于要到了扯开遮羞布的时候了.

```java
@Test
	public void testSpringLoadXml(){
    // A
		BeanFactory factory = new XmlBeanFactory(new ClassPathResource("com/sjr/test/bean/MyTestBean.xml"));
    // B
		final MyTestBean testBean = factory.getBean("myTestBean",MyTestBean.class);
		final String testStr = testBean.getTestStr();
		System.out.println(testStr);
	}
```

​	前面记录了A这个过程,整个过程总结为:

1. 加载xml文件
2. 解析xml文件
3. 选用合适的handler解析标签
4. 创建bean的定义
5. 注册bean定义



​	那么后面B这一步就是比较重要的一步.



# 二、分析

​	从`MyTestBean testBean = factory.getBean("myTestBean",MyTestBean.class);`这句代码开始吧,进去看看里面是啥妖魔鬼怪.

```java
// AbstractBeanFactory
@Override
	public <T> T getBean(String name, Class<T> requiredType) throws BeansException {
		return doGetBean(name, requiredType, null, false);
	}
	@SuppressWarnings("unchecked")
	protected <T> T doGetBean(final String name, @Nullable final Class<T> requiredType,
			@Nullable final Object[] args, boolean typeCheckOnly) throws BeansException {

		// 提取 bean name,bean name 可能不是单纯的名称也可能是工厂的名称
		// 例如 &bean 就代表从名称为bean的工厂中获取 bean
		final String beanName = transformedBeanName(name);
		Object bean;

		// Eagerly check singleton cache for manually registered singletons.
		// 通过单利工厂获取 bean
		Object sharedInstance = getSingleton(beanName);
		if (sharedInstance != null && args == null) {
			if (logger.isTraceEnabled()) {
				if (isSingletonCurrentlyInCreation(beanName)) {
					logger.trace("Returning eagerly cached instance of singleton bean '" + beanName +
							"' that is not fully initialized yet - a consequence of a circular reference");
				}
				else {
					logger.trace("Returning cached instance of singleton bean '" + beanName + "'");
				}
			}
			bean = getObjectForBeanInstance(sharedInstance, name, beanName, null);
		}

		else {
			// 如果为原型模式,存在循环依赖则报错
			// Fail if we're already creating this bean instance:
			// We're assumably within a circular reference.
			// 如果是原型模式则不解决循环依赖问题,直接抛出异常
			if (isPrototypeCurrentlyInCreation(beanName)) {
				throw new BeanCurrentlyInCreationException(beanName);
			}
			// 获取父bean工厂
			// Check if bean definition exists in this factory.
			BeanFactory parentBeanFactory = getParentBeanFactory();
			// 通过递归父工厂获取bean对象
			// 如果无bean定义并且还要加载这个bean 说明这个bean已经被加载过了
			if (parentBeanFactory != null && !containsBeanDefinition(beanName)) {
				// Not found -> check parent.
				String nameToLookup = originalBeanName(name);
				if (parentBeanFactory instanceof AbstractBeanFactory) {
					return ((AbstractBeanFactory) parentBeanFactory).doGetBean(
							nameToLookup, requiredType, args, typeCheckOnly);
				}
				else if (args != null) {
					// Delegation to parent with explicit args.
					return (T) parentBeanFactory.getBean(nameToLookup, args);
				}
				else if (requiredType != null) {
					// No args -> delegate to standard getBean method.
					return parentBeanFactory.getBean(nameToLookup, requiredType);
				}
				else {
					return (T) parentBeanFactory.getBean(nameToLookup);
				}
			}
			//记录 bean 正在创建中
			if (!typeCheckOnly) {
				markBeanAsCreated(beanName);
			}

			try {
				final RootBeanDefinition mbd = getMergedLocalBeanDefinition(beanName);
				checkMergedBeanDefinition(mbd, beanName, args);

				// Guarantee initialization of beans that the current bean depends on.
				String[] dependsOn = mbd.getDependsOn();
				if (dependsOn != null) {
					for (String dep : dependsOn) {
						if (isDependent(beanName, dep)) {
							throw new BeanCreationException(mbd.getResourceDescription(), beanName,
									"Circular depends-on relationship between '" + beanName + "' and '" + dep + "'");
						}
						//依赖注册
						registerDependentBean(dep, beanName);
						try {
							//获取bean,循环获取依赖
							getBean(dep);
						}
						catch (NoSuchBeanDefinitionException ex) {
							throw new BeanCreationException(mbd.getResourceDescription(), beanName,
									"'" + beanName + "' depends on missing bean '" + dep + "'", ex);
						}
					}
				}

				// 创建bean实例
				// Create bean instance.
				// 单利模式
				if (mbd.isSingleton()) {
					sharedInstance = getSingleton(beanName, () -> {
						try {
							return createBean(beanName, mbd, args);
						}
						catch (BeansException ex) {
							// Explicitly remove instance from singleton cache: It might have been put there
							// eagerly by the creation process, to allow for circular reference resolution.
							// Also remove any beans that received a temporary reference to the bean.
							destroySingleton(beanName);
							throw ex;
						}
					});
					bean = getObjectForBeanInstance(sharedInstance, name, beanName, mbd);
				}
				// 原型模式
				else if (mbd.isPrototype()) {
					// It's a prototype -> create a new instance.
					Object prototypeInstance = null;
					try {
						// 前置处理
						beforePrototypeCreation(beanName);
						// 创建bean
						prototypeInstance = createBean(beanName, mbd, args);
					}
					finally {
						// 后置处理
						afterPrototypeCreation(beanName);
					}
					bean = getObjectForBeanInstance(prototypeInstance, name, beanName, mbd);
				}

				else {
					// 其他作用域
					String scopeName = mbd.getScope();
					final Scope scope = this.scopes.get(scopeName);
					if (scope == null) {
						throw new IllegalStateException("No Scope registered for scope name '" + scopeName + "'");
					}
					try {
						Object scopedInstance = scope.get(beanName, () -> {
							// 前置处理
							beforePrototypeCreation(beanName);
							try {
								// 创建 bean
								return createBean(beanName, mbd, args);
							}
							finally {
								// 后置处理
								afterPrototypeCreation(beanName);
							}
						});
						bean = getObjectForBeanInstance(scopedInstance, name, beanName, mbd);
					}
					catch (IllegalStateException ex) {
						throw new BeanCreationException(beanName,
								"Scope '" + scopeName + "' is not active for the current thread; consider " +
								"defining a scoped proxy for this bean if you intend to refer to it from a singleton",
								ex);
					}
				}
			}
			catch (BeansException ex) {
				cleanupAfterBeanCreationFailure(beanName);
				throw ex;
			}
		}

		//类型转换
		// Check if required type matches the type of the actual bean instance.
		if (requiredType != null && !requiredType.isInstance(bean)) {
			try {
				T convertedBean = getTypeConverter().convertIfNecessary(bean, requiredType);
				if (convertedBean == null) {
					throw new BeanNotOfRequiredTypeException(name, requiredType, bean.getClass());
				}
				return convertedBean;
			}
			catch (TypeMismatchException ex) {
				if (logger.isTraceEnabled()) {
					logger.trace("Failed to convert bean '" + name + "' to required type '" +
							ClassUtils.getQualifiedName(requiredType) + "'", ex);
				}
				throw new BeanNotOfRequiredTypeException(name, requiredType, bean.getClass());
			}
		}
		return (T) bean;
	}
```

​	代码很长,看起来比较费劲.拆分来看看。

```java
// AbstractBeanFactory
// 提取 bean name,bean name 可能不是单纯的名称也可能是工厂的名称
		// 例如 &bean 就代表从名称为bean的工厂中获取 bean
final String beanName = transformedBeanName(name);
		Object bean;

		// Eagerly check singleton cache for manually registered singletons.
		// 通过单利工厂获取 bean
		Object sharedInstance = getSingleton(beanName);
		if (sharedInstance != null && args == null) {
			if (logger.isTraceEnabled()) {
				if (isSingletonCurrentlyInCreation(beanName)) {
					logger.trace("Returning eagerly cached instance of singleton bean '" + beanName +
							"' that is not fully initialized yet - a consequence of a circular reference");
				}
				else {
					logger.trace("Returning cached instance of singleton bean '" + beanName + "'");
				}
			}
			bean = getObjectForBeanInstance(sharedInstance, name, beanName, null);
		}

```

1. 获取bean的真实名称
2. 获取bean



​	这部分分成3句代码

1. `String beanName = transformedBeanName(name);`
2. `Object sharedInstance = getSingleton(beanName);`
3. `bean = getObjectForBeanInstance(sharedInstance, name, beanName, null);`



## 2.1 transformedBeanName

```java
// AbstractBeanFactory
protected String transformedBeanName(String name) {
		return canonicalName(BeanFactoryUtils.transformedBeanName(name));
	}
// BeanFactoryUtils
public static String transformedBeanName(String name) {
		Assert.notNull(name, "'name' must not be null");
		// 判断是否是以& 开头的名称
		if (!name.startsWith(BeanFactory.FACTORY_BEAN_PREFIX)) {
			return name;
		}
		// 名称->真实名称 放入换成中
		// 不停的循环截取&后面的部分,直到不以&开头为止
		return transformedBeanNameCache.computeIfAbsent(name, beanName -> {
			do {
				beanName = beanName.substring(BeanFactory.FACTORY_BEAN_PREFIX.length());
			}
			while (beanName.startsWith(BeanFactory.FACTORY_BEAN_PREFIX));
			return beanName;
		});
	}
// AbstractBeanFactory
public String canonicalName(String name) {
		String canonicalName = name;
		// Handle aliasing...
		String resolvedName;
		// 判断bean的名称是否是别名
		// 一直循环 跟着别名的引用链走
		// 直到非别名为止
		// 例如 A-B-C-D-E-F
		// 从A找到F
		do {
			resolvedName = this.aliasMap.get(canonicalName);
			if (resolvedName != null) {
				canonicalName = resolvedName;
			}
		}
		while (resolvedName != null);
		return canonicalName;
	}

```

1. 先判断是否是以&开头,这个符号代表着引用的意思,在c/c++里面估计会很熟悉.
2. 判断是否是别名
3. 返回最终确定下来的bean名称



## 2.2 & 符号的作用

```java

public class MyTestFactoryBean implements FactoryBean<MyTestBean> {
	@Override
	public MyTestBean getObject() throws Exception {
		return new MyTestBean();
	}

	@Override
	public Class<?> getObjectType() {
		return MyTestBean.class;
	}

	@Override
	public boolean isSingleton() {
		return true;
	}
}

```



```java
<?xml version="1.0" encoding="ISO-8859-1"?>
<beans xmlns="http://www.springframework.org/schema/beans"
	   xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
	   xsi:schemaLocation="http://www.springframework.org/schema/beans
                       https://www.springframework.org/schema/beans/spring-beans-3.0.xsd">
	<bean id="myTestBeanFactory" class="com.sjr.test.bean.MyTestFactoryBean"/>
</beans>

```



```java

public class TestSpringFactoryBean {

	@Test
	public void testFactoryBean() {
		BeanFactory factory = new XmlBeanFactory(new ClassPathResource("com/sjr/test/bean/MyTestBeanFactory.xml"));
		final Object bean = factory.getBean("myTestBeanFactory");
		System.out.println(bean.getClass().getName());
		final Object bean1 = factory.getBean("&myTestBeanFactory");
		System.out.println(bean1.getClass().getName());
	}
}

```

最后结果输出为:

```properties
com.sjr.test.bean.MyTestBean
com.sjr.test.bean.MyTestFactoryBean
```

​	从结果上来应该秒懂吧,如果一`FactoryBean`对象在spring创建的时候会判断bean名称,如果bean名称中不带有&符号,说明是要获取`FactoryBean`所产生的对象,如果带有&符号,则说明需要获取`FactoryBean`对象本身.

## 2.2 getSingleton

```java
// DefaultSingletonBeanRegistry
@Override
	@Nullable
	public Object getSingleton(String beanName) {
		return getSingleton(beanName, true);
	}

@Nullable
	protected Object getSingleton(String beanName, boolean allowEarlyReference) {
		// 缓存中是否有创建好的bean
		Object singletonObject = this.singletonObjects.get(beanName);
		// 缓存中无指定的bean并且该bean未在创建中
		if (singletonObject == null && isSingletonCurrentlyInCreation(beanName)) {
			// 加锁 
			synchronized (this.singletonObjects) {
				// 指定的bean是否在创建中
				singletonObject = this.earlySingletonObjects.get(beanName);
				// 非创建中,并且允许提前引用
				if (singletonObject == null && allowEarlyReference) {
					// 获取单利工厂
					ObjectFactory<?> singletonFactory = this.singletonFactories.get(beanName);
					if (singletonFactory != null) {
						// 调用工厂创建对象
						singletonObject = singletonFactory.getObject();
						// 把创建好的对象放入到正在创建的集合中去
						this.earlySingletonObjects.put(beanName, singletonObject);
						// 移除单利工厂
						this.singletonFactories.remove(beanName);
					}
				}
			}
		}
		return singletonObject;
	}
```

​	逻辑比较简单,这里有几个map 比较重要:

1. singletonObjects 用于保存BeanName和创建bean实例之间的关系 beanName->bean
2. earlySingletonObjects 用于保存BeanName和创建bean实例之间的关系 beanName->bean,不同点是,当bean放入到此集合中时,在bean创建的过程中就可以通 过getBean方法来获取bean的引用,主要是用于解决循环依赖问题.
3. singletonFactories:用于保存beanName与bean工厂之间的关系
4. registeredSingletons:用来保存当前所有已注册的bean



​	如果bean名称是工厂的名称,那么这里已经完成了bean的创建了,但仅仅是创建完成还是不够,spring还要插上一脚进行管理.



## 2.3 getObjectForBeanInstance

```java
protected Object getObjectForBeanInstance(
			Object beanInstance, String name, String beanName, @Nullable RootBeanDefinition mbd) {

		// Don't let calling code try to dereference the factory if the bean isn't a factory.
		// 检查bean名称是否符合bean工厂的命名规范,如果名称是工厂的格式,则获取的bean为工厂实例
		if (BeanFactoryUtils.isFactoryDereference(name)) {
			// 符合规范但是个null
			if (beanInstance instanceof NullBean) {
				return beanInstance;
			}
			// 符合规范但不是factory,异常
			if (!(beanInstance instanceof FactoryBean)) {
				throw new BeanIsNotAFactoryException(beanName, beanInstance.getClass());
			}
			// 如果bean定义不为空,设置为true表明是个工厂bean
			if (mbd != null) {
				mbd.isFactoryBean = true;
			}
			return beanInstance;
		}

		// Now we have the bean instance, which may be a normal bean or a FactoryBean.
		// If it's a FactoryBean, we use it to create a bean instance, unless the
		// caller actually wants a reference to the factory.
		// 如果bean实例为非工厂,直接返回
		if (!(beanInstance instanceof FactoryBean)) {
			return beanInstance;
		}

		// 后面的逻辑是bean是工厂,而名称则不是工厂的解引用格式
		Object object = null;
		if (mbd != null) {
			mbd.isFactoryBean = true;
		}
		else {
			// 从缓存中获取对象对应的工厂bean
			object = getCachedObjectForFactoryBean(beanName);
		}
		if (object == null) {
			// Return bean instance from factory.
			FactoryBean<?> factory = (FactoryBean<?>) beanInstance;
			// Caches object obtained from FactoryBean if it is a singleton.
			if (mbd == null && containsBeanDefinition(beanName)) {
				mbd = getMergedLocalBeanDefinition(beanName);
			}
			boolean synthetic = (mbd != null && mbd.isSynthetic());
			object = getObjectFromFactoryBean(factory, beanName, !synthetic);
		}
		return object;
	}
```

1. 如果bean的名称以& 开头并且是`FactoryBean`子类,直接返回工厂对象
2. 如果bean的名称非以&开头并且非`FactoryBean`子类直接返回对象
3. 如果bean的名称非以&开头并且是`FactoryBean`子类调用`FactoryBean`的getObject方法获取对象



以上代码中的核心代码有三处:

1. getCachedObjectForFactoryBean()
2. getMergedLocalBeanDefinition()
3. getObjectFromFactoryBean()



## 2.4 getCachedObjectForFactoryBean

```java
@Nullable
	protected Object getCachedObjectForFactoryBean(String beanName) {
		return this.factoryBeanObjectCache.get(beanName);
	}
```

​	代码很简单,就是根据beanName在换成中获取对应的bean

## 2.5 getMergedLocalBeanDefinition

```java
// AbstractBeanFactory
protected RootBeanDefinition getMergedLocalBeanDefinition(String beanName) throws BeansException {
		// Quick check on the concurrent map first, with minimal locking.
		// 从缓存中获取
		RootBeanDefinition mbd = this.mergedBeanDefinitions.get(beanName);
		if (mbd != null && !mbd.stale) {
			return mbd;
		}
		return getMergedBeanDefinition(beanName, getBeanDefinition(beanName));
	}
protected RootBeanDefinition getMergedBeanDefinition(String beanName, BeanDefinition bd)
			throws BeanDefinitionStoreException {

		return getMergedBeanDefinition(beanName, bd, null);
	}

protected RootBeanDefinition getMergedBeanDefinition(
			String beanName, BeanDefinition bd, @Nullable BeanDefinition containingBd)
			throws BeanDefinitionStoreException {
		// 加锁,并发控制
		synchronized (this.mergedBeanDefinitions) {
			RootBeanDefinition mbd = null;
			RootBeanDefinition previous = null;

			// Check with full lock now in order to enforce the same merged instance.
			if (containingBd == null) {
				// 如果为空 从缓存中获取
				mbd = this.mergedBeanDefinitions.get(beanName);
			}
			
			
			if (mbd == null || mbd.stale) {
				previous = mbd;
				// 判断是否具有父子关系
				if (bd.getParentName() == null) {
					// Use copy of given root bean definition.
					// 判断类型是否是 RootBeanDefinition
					if (bd instanceof RootBeanDefinition) {
						// copy一个
						mbd = ((RootBeanDefinition) bd).cloneBeanDefinition();
					}
					else {
						// 转换为 RootBeanDefinition
						mbd = new RootBeanDefinition(bd);
					}
				}
				else {
					// Child bean definition: needs to be merged with parent.
					BeanDefinition pbd;
					try {
						// 获取 父bean 名称
						String parentBeanName = transformedBeanName(bd.getParentName());
						// 判断父与子的bean 名称是否相同
						if (!beanName.equals(parentBeanName)) {
							// 如果不相同,则顺则 父子关系 一路递归上去
							// 全部转换为 RootBeanDefinition
							pbd = getMergedBeanDefinition(parentBeanName);
						}
						else {
							// 和上面代码逻辑相同 只是类型不一样
							BeanFactory parent = getParentBeanFactory();
							if (parent instanceof ConfigurableBeanFactory) {
								pbd = ((ConfigurableBeanFactory) parent).getMergedBeanDefinition(parentBeanName);
							}
							else {
								throw new NoSuchBeanDefinitionException(parentBeanName,
										"Parent name '" + parentBeanName + "' is equal to bean name '" + beanName +
										"': cannot be resolved without an AbstractBeanFactory parent");
							}
						}
					}
					catch (NoSuchBeanDefinitionException ex) {
						throw new BeanDefinitionStoreException(bd.getResourceDescription(), beanName,
								"Could not resolve parent bean definition '" + bd.getParentName() + "'", ex);
					}
					// Deep copy with overridden values.
					// 深拷贝 转换为RootBeanDefinition
					mbd = new RootBeanDefinition(pbd);
					mbd.overrideFrom(bd);
				}

				// Set default singleton scope, if not configured before.
				if (!StringUtils.hasLength(mbd.getScope())) {
					mbd.setScope(SCOPE_SINGLETON);
				}

				// A bean contained in a non-singleton bean cannot be a singleton itself.
				// Let's correct this on the fly here, since this might be the result of
				// parent-child merging for the outer bean, in which case the original inner bean
				// definition will not have inherited the merged outer bean's singleton status.
				if (containingBd != null && !containingBd.isSingleton() && mbd.isSingleton()) {
					mbd.setScope(containingBd.getScope());
				}

				// Cache the merged bean definition for the time being
				// (it might still get re-merged later on in order to pick up metadata changes)
				if (containingBd == null && isCacheBeanMetadata()) {
					// 加入缓存
					this.mergedBeanDefinitions.put(beanName, mbd);
				}
			}
			if (previous != null) {
				copyRelevantMergedBeanDefinitionCaches(previous, mbd);
			}
			return mbd;
		}
	}

```

​	说这代码之前,先说说spring中的基本数据结构.在spring中基本数据结构为`BeanDefinition`,通过spring产生的普通bean为`GenericBeanDefinition`.而spring后续处理的类型则为`RootBeanDefinition`.关系图如下:

![zlb4uh](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/zlb4uh.jpg)

​	这两个长的都差不多,只不过后续处理的步骤用到的类型为`RootBeanDefinition`,所以在上面的方法中,进行递归转换.

## 2.6 getObjectFromFactoryBean

```java
// AbstractBeanFactory
boolean synthetic = (mbd != null && mbd.isSynthetic());
object = getObjectFromFactoryBean(factory, beanName, !synthetic);
```

​	这里这个`isSynthetic`方法代表是否是人造的,emma就这样理解吧.什么叫做人造的呢?意思就是不加干预通spring产生的就是非人造的,如果是后面通过代理产生的就是非人造的.

​	看了一下setSynthetic这个方法的调用情况,都是在aop那边调用的比较多.不知道解释的对不对哈.

```java
// FactoryBeanRegistrySupport
protected Object getObjectFromFactoryBean(FactoryBean<?> factory, String beanName, boolean shouldPostProcess) {
		// 判断工厂是否为单利工厂,并且单利对象已被创建完成
		if (factory.isSingleton() && containsSingleton(beanName)) {
			// 加锁
			synchronized (getSingletonMutex()) {
				// 在缓存中获取通过工厂创建的bean
				Object object = this.factoryBeanObjectCache.get(beanName);
				if (object == null) {
					// 获取bean通过工厂
					object = doGetObjectFromFactoryBean(factory, beanName);
					// Only post-process and store if not put there already during getObject() call above
					// (e.g. because of circular reference processing triggered by custom getBean calls)
					// 再次从缓存中获取bean
					Object alreadyThere = this.factoryBeanObjectCache.get(beanName);
					if (alreadyThere != null) {
						// 如果缓存中获取到bean,则丢弃当前创建的对象
						object = alreadyThere;
					}
					else {
						// 判断是否需要post-processing
						if (shouldPostProcess) {
							// 当前的bean是否被创建中,如果是就直接返回当前的bean不做处理
							if (isSingletonCurrentlyInCreation(beanName)) {
								// Temporarily return non-post-processed object, not storing it yet..
								return object;
							}
							// bean创建之前,把当前bean加入正在创建中的集合中去
							beforeSingletonCreation(beanName);
							try {
								// AOP的核心步骤
								object = postProcessObjectFromFactoryBean(object, beanName);
							}
							catch (Throwable ex) {
								throw new BeanCreationException(beanName,
										"Post-processing of FactoryBean's singleton object failed", ex);
							}
							finally {
								// bean创建之后,把bean从正在创建中的集合中移除
								afterSingletonCreation(beanName);
							}
						}
						if (containsSingleton(beanName)) {
							// 缓存bean对象
							this.factoryBeanObjectCache.put(beanName, object);
						}
					}
				}
				return object;
			}
		}
		else {
			//创建对象
			Object object = doGetObjectFromFactoryBean(factory, beanName);
			if (shouldPostProcess) {
				try {
					//处理bean流程
					object = postProcessObjectFromFactoryBean(object, beanName);
				}
				catch (Throwable ex) {
					throw new BeanCreationException(beanName, "Post-processing of FactoryBean's object failed", ex);
				}
			}
			return object;
		}
	}
```

1. 判断是否是单利工厂,并且缓存中已经创建了该bean的factoryBean
2. 判断factoryBeanObjectCache缓存中bean是否存在
3. 通过factoryBean创建bean



​	以上逻辑为当有factoryBean的逻辑.

# 三、后半段逻辑

```java
//AbstractBeanFactory
			// 如果为原型模式,存在循环依赖则报错
			// Fail if we're already creating this bean instance:
			// We're assumably within a circular reference.
			// 如果是原型模式则不解决循环依赖问题,直接抛出异常
			if (isPrototypeCurrentlyInCreation(beanName)) {
				throw new BeanCurrentlyInCreationException(beanName);
			}
			// 获取父bean工厂
			// Check if bean definition exists in this factory.
			BeanFactory parentBeanFactory = getParentBeanFactory();
			// 通过递归父工厂获取bean对象
			// 如果无bean定义并且还要加载这个bean 说明这个bean已经被加载过了
			if (parentBeanFactory != null && !containsBeanDefinition(beanName)) {
				// Not found -> check parent.
				String nameToLookup = originalBeanName(name);
				if (parentBeanFactory instanceof AbstractBeanFactory) {
					return ((AbstractBeanFactory) parentBeanFactory).doGetBean(
							nameToLookup, requiredType, args, typeCheckOnly);
				}
				else if (args != null) {
					// Delegation to parent with explicit args.
					return (T) parentBeanFactory.getBean(nameToLookup, args);
				}
				else if (requiredType != null) {
					// No args -> delegate to standard getBean method.
					return parentBeanFactory.getBean(nameToLookup, requiredType);
				}
				else {
					return (T) parentBeanFactory.getBean(nameToLookup);
				}
			}
```

​	如果非单利模式,spring在这里不处理循环依赖问题.如果`BeanFactory`存在父子关系,则进行递归创建.

```java
// AbstractBeanFactory
// 记录 bean 正在创建中
			if (!typeCheckOnly) {
				markBeanAsCreated(beanName);
			}
// 转换BeanDefinition为RootBeanDefinition
final RootBeanDefinition mbd = getMergedLocalBeanDefinition(beanName);
			// 检查RootBeanDefinition是否合法
				checkMergedBeanDefinition(mbd, beanName, args);

				// Guarantee initialization of beans that the current bean depends on.
				// 遍历所有依赖,并进行注册、创建等过程
				String[] dependsOn = mbd.getDependsOn();
				if (dependsOn != null) {
					for (String dep : dependsOn) {
						if (isDependent(beanName, dep)) {
							throw new BeanCreationException(mbd.getResourceDescription(), beanName,
									"Circular depends-on relationship between '" + beanName + "' and '" + dep + "'");
						}
						// 依赖注册
						registerDependentBean(dep, beanName);
						try {
							// 获取bean,循环获取依赖
							getBean(dep);
						}
						catch (NoSuchBeanDefinitionException ex) {
							throw new BeanCreationException(mbd.getResourceDescription(), beanName,
									"'" + beanName + "' depends on missing bean '" + dep + "'", ex);
						}
					}
				}

				// 创建bean实例
				// Create bean instance.
				// 单利模式
				if (mbd.isSingleton()) {
					sharedInstance = getSingleton(beanName, () -> {
						try {
							return createBean(beanName, mbd, args);
						}
						catch (BeansException ex) {
							// Explicitly remove instance from singleton cache: It might have been put there
							// eagerly by the creation process, to allow for circular reference resolution.
							// Also remove any beans that received a temporary reference to the bean.
							destroySingleton(beanName);
							throw ex;
						}
					});
					bean = getObjectForBeanInstance(sharedInstance, name, beanName, mbd);
				}			
```

1. 标记该bean未正在创建中.

   ```java
   // AbstractBeanFactory
   protected void markBeanAsCreated(String beanName) {
   		// 判断是否包含beanName
   		if (!this.alreadyCreated.contains(beanName)) {
   			// 加锁并发控制
   			synchronized (this.mergedBeanDefinitions) {
   				// 双重检查
   				if (!this.alreadyCreated.contains(beanName)) {
   					// Let the bean definition get re-merged now that we're actually creating
   					// the bean... just in case some of its metadata changed in the meantime.
   					clearMergedBeanDefinition(beanName);
   					// 添加进行已经创建集合中
   					this.alreadyCreated.add(beanName);
   				}
   			}
   		}
   	}
   ```

2. 遍历依赖并进行递归创建

   ```java
   // AbstractBeanFactory
   			if (dependsOn != null) {
   					for (String dep : dependsOn) {
   						if (isDependent(beanName, dep)) {
   							throw new BeanCreationException(mbd.getResourceDescription(), beanName,
   									"Circular depends-on relationship between '" + beanName + "' and '" + dep + "'");
   						}
   						//依赖注册
   						registerDependentBean(dep, beanName);
   						try {
   							//获取bean,循环获取依赖
   							getBean(dep);
   						}
   						catch (NoSuchBeanDefinitionException ex) {
   							throw new BeanCreationException(mbd.getResourceDescription(), beanName,
   									"'" + beanName + "' depends on missing bean '" + dep + "'", ex);
   						}
   					}
   				}
   ```



​	这里的核心逻辑在于`getSingleton`这个方法里



### 3.1 getSingleton

```java
// AbstractBeanFactory
public Object getSingleton(String beanName, ObjectFactory<?> singletonFactory) {
		Assert.notNull(beanName, "Bean name must not be null");
		// 加锁
		synchronized (this.singletonObjects) {
			// 从缓存中获取 bean
			Object singletonObject = this.singletonObjects.get(beanName);
			// 如果缓存中没有
			if (singletonObject == null) {
        // 判断当前bean是否被标记为销毁
        // 相当于不能在destrory方法里面再去创建这个bean
				if (this.singletonsCurrentlyInDestruction) {
					throw new BeanCreationNotAllowedException(beanName,
							"Singleton bean creation not allowed while singletons of this factory are in destruction " +
							"(Do not request a bean from a BeanFactory in a destroy method implementation!)");
				}
				if (logger.isDebugEnabled()) {
					logger.debug("Creating shared instance of singleton bean '" + beanName + "'");
				}
				// 开始创建 bean
				// 添加到 创建中集合中去
				// 前置处理
				beforeSingletonCreation(beanName);
				boolean newSingleton = false;
				boolean recordSuppressedExceptions = (this.suppressedExceptions == null);
				if (recordSuppressedExceptions) {
					this.suppressedExceptions = new LinkedHashSet<>();
				}
				try {
					// 从工厂中获取 bean
					singletonObject = singletonFactory.getObject();
					newSingleton = true;
				}
				catch (IllegalStateException ex) {
					// Has the singleton object implicitly appeared in the meantime ->
					// if yes, proceed with it since the exception indicates that state.
					singletonObject = this.singletonObjects.get(beanName);
					if (singletonObject == null) {
						throw ex;
					}
				}
				catch (BeanCreationException ex) {
					if (recordSuppressedExceptions) {
						for (Exception suppressedException : this.suppressedExceptions) {
							ex.addRelatedCause(suppressedException);
						}
					}
					throw ex;
				}
				finally {
					if (recordSuppressedExceptions) {
						this.suppressedExceptions = null;
					}
					// 移除创建中的集合
					afterSingletonCreation(beanName);
				}
				if (newSingleton) {
					// 放入缓存
					addSingleton(beanName, singletonObject);
				}
			}
			return singletonObject;
		}
	}
```

1. 从缓存中获取bean
2. 如果换成中没有,则判断当前的bean是否被记被销毁
3. 在创建之前把beanName加入正在创建的缓存中去
4. 从单利工厂中创建bean
5. 从正在创建的换成中移除beanName
6. 把创建好的singletonObject加入缓存中



值得注意的是这里的`singletonFactory`对象是通过Lambda表达传入进来的

```java
// AbstractBeanFactory
sharedInstance = getSingleton(beanName, () -> {
						try {
							return createBean(beanName, mbd, args);
						}
						catch (BeansException ex) {
							// Explicitly remove instance from singleton cache: It might have been put there
							// eagerly by the creation process, to allow for circular reference resolution.
							// Also remove any beans that received a temporary reference to the bean.
							destroySingleton(beanName);
							throw ex;
						}
					});
```

这里的核心逻辑代码是`createBean(beanName, mbd, args)`



### 3.2 createBean

```java
// AbstractAutowireCapableBeanFactory
@Override
	protected Object createBean(String beanName, RootBeanDefinition mbd, @Nullable Object[] args)
			throws BeanCreationException {

		if (logger.isTraceEnabled()) {
			logger.trace("Creating instance of bean '" + beanName + "'");
		}
		RootBeanDefinition mbdToUse = mbd;

		// Make sure bean class is actually resolved at this point, and
		// clone the bean definition in case of a dynamically resolved Class
		// which cannot be stored in the shared merged bean definition.
		// 根据类名加载class对象
		Class<?> resolvedClass = resolveBeanClass(mbd, beanName);
		if (resolvedClass != null && !mbd.hasBeanClass() && mbd.getBeanClassName() != null) {
			mbdToUse = new RootBeanDefinition(mbd);
			mbdToUse.setBeanClass(resolvedClass);
		}

		// Prepare method overrides.
		try {
			// 匹配需要覆盖的方法
			mbdToUse.prepareMethodOverrides();
		}
		catch (BeanDefinitionValidationException ex) {
			throw new BeanDefinitionStoreException(mbdToUse.getResourceDescription(),
					beanName, "Validation of method overrides failed", ex);
		}

		try {
			// Give BeanPostProcessors a chance to return a proxy instead of the target bean instance.
			// 返回一个代理对象,也可能是非代理对象
			Object bean = resolveBeforeInstantiation(beanName, mbdToUse);
			if (bean != null) {
				return bean;
			}
		}
		catch (Throwable ex) {
			throw new BeanCreationException(mbdToUse.getResourceDescription(), beanName,
					"BeanPostProcessor before instantiation of bean failed", ex);
		}

		try {
			// 创建bean
			Object beanInstance = doCreateBean(beanName, mbdToUse, args);
			if (logger.isTraceEnabled()) {
				logger.trace("Finished creating instance of bean '" + beanName + "'");
			}
			return beanInstance;
		}
		catch (BeanCreationException | ImplicitlyAppearedSingletonException ex) {
			// A previously detected exception with proper bean creation context already,
			// or illegal singleton state to be communicated up to DefaultSingletonBeanRegistry.
			throw ex;
		}
		catch (Throwable ex) {
			throw new BeanCreationException(
					mbdToUse.getResourceDescription(), beanName, "Unexpected exception during bean creation", ex);
		}
	}
```

1. 加载class
2. 判断该bean是否需要`InstantiationAwareBeanPostProcessor`进行处理,这个接口与`BeanPostProcessor`不同,主要区别是在调用时机上的区别,`InstantiationAwareBeanPostProcessor`会在对象创建前进行调用,而`BeanPostProcessor`会在对象初始化前后进行调用,这个可以从doCreateBean看出时机的差别.
3. 创建对象



### 3.3 doCreateBean

```java
// AbstractAutowireCapableBeanFactory
protected Object doCreateBean(final String beanName, final RootBeanDefinition mbd, final @Nullable Object[] args)
			throws BeanCreationException {

		// Instantiate the bean.
		BeanWrapper instanceWrapper = null;
		if (mbd.isSingleton()) {
			// 从缓存中获取实例wrapper,并移除它
			instanceWrapper = this.factoryBeanInstanceCache.remove(beanName);
		}
		// 如果没有获取到实例的wrapper,则创建一个实例
		if (instanceWrapper == null) {
			instanceWrapper = createBeanInstance(beanName, mbd, args);
		}
		final Object bean = instanceWrapper.getWrappedInstance();
		Class<?> beanType = instanceWrapper.getWrappedClass();
		if (beanType != NullBean.class) {
			mbd.resolvedTargetType = beanType;
		}

		// Allow post-processors to modify the merged bean definition.
		// 判断是否有 后置处理器
		// 加锁
		synchronized (mbd.postProcessingLock) {
			if (!mbd.postProcessed) {
				try {
					applyMergedBeanDefinitionPostProcessors(mbd, beanType, beanName);
				}
				catch (Throwable ex) {
					throw new BeanCreationException(mbd.getResourceDescription(), beanName,
							"Post-processing of merged bean definition failed", ex);
				}
				mbd.postProcessed = true;
			}
		}

		// 是否允许循环引用
		// Eagerly cache singletons to be able to resolve circular references
		// even when triggered by lifecycle interfaces like BeanFactoryAware.
		boolean earlySingletonExposure = (mbd.isSingleton() && this.allowCircularReferences &&
				isSingletonCurrentlyInCreation(beanName));
		if (earlySingletonExposure) {
			if (logger.isTraceEnabled()) {
				logger.trace("Eagerly caching bean '" + beanName +
						"' to allow for resolving potential circular references");
			}
			addSingletonFactory(beanName, () -> getEarlyBeanReference(beanName, mbd, bean));
		}

		// Initialize the bean instance.
		Object exposedObject = bean;
		try {
			// 填充bean属性
			populateBean(beanName, mbd, instanceWrapper);
			// 初始化bean
			exposedObject = initializeBean(beanName, exposedObject, mbd);
		}
		catch (Throwable ex) {
			if (ex instanceof BeanCreationException && beanName.equals(((BeanCreationException) ex).getBeanName())) {
				throw (BeanCreationException) ex;
			}
			else {
				throw new BeanCreationException(
						mbd.getResourceDescription(), beanName, "Initialization of bean failed", ex);
			}
		}
		// 循环依赖处理
		if (earlySingletonExposure) {
			// 获取单利对象
			Object earlySingletonReference = getSingleton(beanName, false);
			if (earlySingletonReference != null) {
				if (exposedObject == bean) {
					exposedObject = earlySingletonReference;
				}
				else if (!this.allowRawInjectionDespiteWrapping && hasDependentBean(beanName)) {
					String[] dependentBeans = getDependentBeans(beanName);
					Set<String> actualDependentBeans = new LinkedHashSet<>(dependentBeans.length);
					for (String dependentBean : dependentBeans) {
						if (!removeSingletonIfCreatedForTypeCheckOnly(dependentBean)) {
							actualDependentBeans.add(dependentBean);
						}
					}
					if (!actualDependentBeans.isEmpty()) {
						throw new BeanCurrentlyInCreationException(beanName,
								"Bean with name '" + beanName + "' has been injected into other beans [" +
								StringUtils.collectionToCommaDelimitedString(actualDependentBeans) +
								"] in its raw version as part of a circular reference, but has eventually been " +
								"wrapped. This means that said other beans do not use the final version of the " +
								"bean. This is often the result of over-eager type matching - consider using " +
								"'getBeanNamesOfType' with the 'allowEagerInit' flag turned off, for example.");
					}
				}
			}
		}

		// Register bean as disposable.
		try {
			// 注册销毁处理器
			registerDisposableBeanIfNecessary(beanName, bean, mbd);
		}
		catch (BeanDefinitionValidationException ex) {
			throw new BeanCreationException(
					mbd.getResourceDescription(), beanName, "Invalid destruction signature", ex);
		}

		return exposedObject;
	}
```

​	进过以上骚操作就完成了bean的创建,在创建的过程中还会有属性的填充,bean的初始化等.



# 四、小结

​	继续bean的初始化,与属性的填充.
