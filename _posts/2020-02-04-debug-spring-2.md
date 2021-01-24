---
title: "[断点分析之spring-ioc]-资源加载ResourceLoader(二)"
date: 2020/02/04 9:20:25
tags:
- spring
- java
categories: spring
cover: https://gitee.com/oneww/onew_image/raw/master/spring_cover.png
author: 
  nick: onew
  link: https://onew.me
subtitle: spring 资源加载器
---

# 一、前言

​	资源统一抽象为`Resource`对象.可曾记得在 spring 配置文件中的这种写法:`classpath:com/sjr/test/bean/MyTestBean.xml`,那么这种写法的意思是从classpath路径下加载xml,那么spring是如何定位到文件的?

​	上面这种写法相当于是个协议,在spring中默认支持9种文件协议.

- URL_PROTOCOL_FILE

  从文件系统中加载文件

- URL_PROTOCOL_JAR

  从jar包中加载文件

- URL_PROTOCOL_WAR

  从war包中加载文件

- URL_PROTOCOL_ZIP

  从zip中加载文件

- URL_PROTOCOL_WSJAR

  从wsjar中加载文件

- URL_PROTOCOL_VFSZIP

  从vfszip中加载文件

- URL_PROTOCOL_VFSFILE

  从vfsfile中加载文件

- URL_PROTOCOL_VFS

  从vfs中加载文件



# 二、分析

​	这个故事要从一段代码开始

```java
@Test
	public void testSpringResourceLoader(){
		DefaultResourceLoader defaultResourceLoader = new DefaultResourceLoader(this.getClass().getClassLoader());
		BeanFactory factory = new XmlBeanFactory(defaultResourceLoader.getResource("classpath:com/sjr/test/bean/MyTestBean.xml"));
		final MyTestBean testBean = factory.getBean("myTestBean",MyTestBean.class);
		final String testStr = testBean.getTestStr();
		System.out.println(testStr);
	}
```

​	之前的代码,我们是直接使用的`ClassPathResource`来加载文件,这里使用的`DefaultResourceLoader`对象来加载文件.那`DefaultResourceLoader`有什么用处呢?

1. 自动检测文件该如何加载

 	2. 简化文件加载操作流程

## 2.1 DefaultResourceLoader 

​	`DefaultResourceLoader` 是`ResourceLoader`的默认实现.

![yQS6mB](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/yQS6mB.jpg)

上图可以看到 `DefaultResourceLoader` 还有3个子类进行了功能的扩展.先看看`ResourceLoader`这个接口.



## 2.2 ResourceLoader

```java

public interface ResourceLoader {

	/**
	 *  classpath: 前缀常量
	 * */
	String CLASSPATH_URL_PREFIX = ResourceUtils.CLASSPATH_URL_PREFIX;


	/**
	 * 通过 路径 获取 Resource 对象
	 */
	Resource getResource(String location);

	/**
	 * 获取类加载器
	 */
	@Nullable
	ClassLoader getClassLoader();

}

```

​	从代码可以看出,该接口只有2个方法,一个是通过路径获取 `Resource` 对象,另外一个是获取类加载器.那么在来看看 `DefaultResourceLoader` 的默认实现代码吧.

## 2.3 DefaultResourceLoader 具体实现

```java

public class DefaultResourceLoader implements ResourceLoader {

	@Nullable
	private ClassLoader classLoader;
	// 协议解析器 set
	private final Set<ProtocolResolver> protocolResolvers = new LinkedHashSet<>(4);
	// 缓存
	private final Map<Class<?>, Map<Resource, ?>> resourceCaches = new ConcurrentHashMap<>(4);


	/**
	 * 使用默认构造器,默认构造器中使用默认的类加载器
	 */
	public DefaultResourceLoader() {
		this.classLoader = ClassUtils.getDefaultClassLoader();
	}

	/**
	 * 使用指定的类加载器
	 */
	public DefaultResourceLoader(@Nullable ClassLoader classLoader) {
		this.classLoader = classLoader;
	}


	/**
	 * 设置类加载器
	 */
	public void setClassLoader(@Nullable ClassLoader classLoader) {
		this.classLoader = classLoader;
	}

	/**
	 * 获取类加载器
	 */
	@Override
	@Nullable
	public ClassLoader getClassLoader() {
		return (this.classLoader != null ? this.classLoader : ClassUtils.getDefaultClassLoader());
	}

	/**
	 * 添加协议解析器
	 */
	public void addProtocolResolver(ProtocolResolver resolver) {
		Assert.notNull(resolver, "ProtocolResolver must not be null");
		this.protocolResolvers.add(resolver);
	}

	/**
	 * 获取协议解析器集合
	 */
	public Collection<ProtocolResolver> getProtocolResolvers() {
		return this.protocolResolvers;
	}

	/**
	 * 获取资源缓存
	 */
	@SuppressWarnings("unchecked")
	public <T> Map<Resource, T> getResourceCache(Class<T> valueType) {
		return (Map<Resource, T>) this.resourceCaches.computeIfAbsent(valueType, key -> new ConcurrentHashMap<>());
	}

	/**
	 * 清除所有资源缓存
	 */
	public void clearResourceCaches() {
		this.resourceCaches.clear();
	}

	/**
	 * 获取资源
	 * **/
	@Override
	public Resource getResource(String location) {
		Assert.notNull(location, "Location must not be null");
		// 遍历所有协议解析器
		for (ProtocolResolver protocolResolver : getProtocolResolvers()) {
			// 解析资源
			Resource resource = protocolResolver.resolve(location, this);
			// 如果资源解析到则返回 resource 对象
			if (resource != null) {
				return resource;
			}
		}
		// 判断是否是/开头
		if (location.startsWith("/")) {
			// 获取classpath上下文中的资源
			return getResourceByPath(location);
		}
		// 判断是否是classpath:开头路径,如果是则从classpath中获取资源
		else if (location.startsWith(CLASSPATH_URL_PREFIX)) {
			return new ClassPathResource(location.substring(CLASSPATH_URL_PREFIX.length()), getClassLoader());
		}
		else {
			try {
				// 尝试把路径转化为url
				// Try to parse the location as a URL...
				URL url = new URL(location);
				// 判断是文件资源 还是url资源
				return (ResourceUtils.isFileURL(url) ? new FileUrlResource(url) : new UrlResource(url));
			}
			catch (MalformedURLException ex) {
				// No URL -> resolve as resource path.
				// 非url 尝试从 classpath 上下文中获取资源
				return getResourceByPath(location);
			}
		}
	}

	/**
	 * 通过路径获取 Resource 对象
	 * 从 classPath 中加载文件
	 */
	protected Resource getResourceByPath(String path) {
		return new ClassPathContextResource(path, getClassLoader());
	}


	protected static class ClassPathContextResource extends ClassPathResource implements ContextResource {

		public ClassPathContextResource(String path, @Nullable ClassLoader classLoader) {
			super(path, classLoader);
		}

		@Override
		public String getPathWithinContext() {
			return getPath();
		}
		
    /**
    * 创建相对路径的 Resource 对象
    */
		@Override
		public Resource createRelative(String relativePath) {
			String pathToUse = StringUtils.applyRelativePath(getPath(), relativePath);
			return new ClassPathContextResource(pathToUse, getClassLoader());
		}
	}

}

```

​	以上代码的逻辑比较简单明了,核心逻辑在 `getResource` 这个方法中.

```java
	public Resource getResource(String location) {
		Assert.notNull(location, "Location must not be null");
		// 遍历所有协议解析器
		for (ProtocolResolver protocolResolver : getProtocolResolvers()) {
			// 解析资源
			Resource resource = protocolResolver.resolve(location, this);
			// 如果资源解析到则返回 resource 对象
			if (resource != null) {
				return resource;
			}
		}
		// 判断是否是/开头
		if (location.startsWith("/")) {
			// 获取classpath上下文中的资源
			return getResourceByPath(location);
		}
		// 判断是否是classpath:开头路径,如果是则从classpath中获取资源
		else if (location.startsWith(CLASSPATH_URL_PREFIX)) {
			return new ClassPathResource(location.substring(CLASSPATH_URL_PREFIX.length()), getClassLoader());
		}
		else {
			try {
				// 尝试把路径转化为url
				// Try to parse the location as a URL...
				URL url = new URL(location);
				// 判断是文件资源 还是url资源
				return (ResourceUtils.isFileURL(url) ? new FileUrlResource(url) : new UrlResource(url));
			}
			catch (MalformedURLException ex) {
				// No URL -> resolve as resource path.
				// 非url 尝试从 classpath 上下文中获取资源
				return getResourceByPath(location);
			}
		}
	}
```

​	逻辑流程为以下几步:

  1. 判断是否设置了 协议解析器,如果设置了,则遍历所有的协议解析,

     并解析文件,如果解析成功则返回 Resource 对象否则执行第二步.

		2. 判断路径是否是 `/ ` 开头,若是则从classPath 加载文件,调用 

     `getResourceByPath`方法,返回 `Resource` 对象

		3. 判断是否是 `classpath:` 开头,若是则从 classPath 加载文件
		
		4. 若是以上几步都失败,则尝试把路径转为URL,如果成功则返回

     `FileUrlResource` 或 `UrlResource` 对象

		5. 最后挣扎以下,从classPath 加载文件



## 2.4 FileUrlResource

​	开篇说道 spring 默认支持 9中协议(如果把 classPath 也算上的话),那么除了 常用的 classPath 以外,其他的怎么使用呢?其他的笔者本人都没用过多少,就来看看 file 协议吧.

```java

	@Test
	public void testSpringResourceLoaderForFileProtocol(){
		DefaultResourceLoader defaultResourceLoader = new DefaultResourceLoader(this.getClass().getClassLoader());
		BeanFactory factory = new XmlBeanFactory(defaultResourceLoader.getResource("file:///src/test/resources/com/sjr/test/bean/MyTestBean.xml"));
		final MyTestBean testBean = factory.getBean("myTestBean",MyTestBean.class);
		final String testStr = testBean.getTestStr();
		System.out.println(testStr);
	}
```

​	相当于是个绝对路径了.其他协议可以查查资料.



# 三、自定义文件协议解析器

​	在`DefaultResourceLoader` 中的核心代码中有段遍历解析器的代码,来瞧瞧.

```java
		// 遍历所有协议解析器
		for (ProtocolResolver protocolResolver : getProtocolResolvers()) {
			// 解析资源
			Resource resource = protocolResolver.resolve(location, this);
			// 如果资源解析到则返回 resource 对象
			if (resource != null) {
				return resource;
			}
		}
```

​	通过这段代码,可以实现自定义文件协议解析器的逻辑,方便扩展.`ProtocolResolver`是个接口,里面就一个方法,非常简单.

```java
@FunctionalInterface
public interface ProtocolResolver {

	/**
	 * 解析
	 */
	@Nullable
	Resource resolve(String location, ResourceLoader resourceLoader);

}

```

​	该接口也是个函数接口(可以使用Lambda表达式).来实现一个协议试一试.

```java
// 实现ProtocolResolver 接口 自定义解析逻辑
public class SjrProtocolResolver implements ProtocolResolver {

	@Override
	public Resource resolve(String location, ResourceLoader resourceLoader) {
		if(resourceLoader == null){
			return null;
		}
		if(location == null || !location.startsWith("sjr")){
			return null;
		}
		final int index = location.indexOf("sjr:");
		return resourceLoader.getResource(location.substring(index + 4));
	}
}
```

```java
@Test
	public void testSpringProtocolResolverOfAdv(){
		DefaultResourceLoader defaultResourceLoader = new DefaultResourceLoader(this.getClass().getClassLoader());
		defaultResourceLoader.addProtocolResolver(new SjrProtocolResolver());
		BeanFactory factory = new XmlBeanFactory(defaultResourceLoader.getResource("sjr:com/sjr/test/bean/MyTestBean.xml"));
		final MyTestBean testBean = factory.getBean("myTestBean",MyTestBean.class);
		final String testStr = testBean.getTestStr();
		System.out.println(testStr);
	}
```

​	这样就完成了自定义协议的解析.

​	`DefaultResourceLoader` 还有三个子类:

- ServletContextResourceLoader

  返回`ServletContextResource`,从`ServletContext`获取资源.

- FileSystemResourceLoader

  返回`FileSystemContextResource` ,从文件系统中获取资源,

   其本质上是`FileSystemResource`,实现了`ContextResource`接口

- ClassRelativeResourceLoader

  返回`ClassRelativeContextResource` ,从classPath获取资源,

  其本质上是`ClassPathResource`,实现了`ContextResource`接口

  这三个子类,都是做的简单扩展,逻辑简单,有兴趣可以去看看.



# 四、小结

​	文件是加载到,那么spring 是怎么解析xml文件的呢?
