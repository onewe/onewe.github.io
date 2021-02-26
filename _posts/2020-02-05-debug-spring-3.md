---
title: "[断点分析之spring-ioc]-xml文件解析(三)"
date: 2020/02/05 22:20:25
tags:
- spring
- java
categories: spring
cover: https://gitee.com/oneww/onew_image/raw/master/spring_cover.png
author: 
  nick: onew
  link: https://onew.me
subtitle: spring xml文件解析
---

# 一、前言

​	前面资源文件加载搞定了,来看看 spring 是如何把 xml 文件变成 bean 的吧.



# 二、分析

​	还是从4句代码看起.

````java
@Test
	public void testSpringLoadXml(){
    // 加载xml
		BeanFactory factory = new XmlBeanFactory(new ClassPathResource("com/sjr/test/bean/MyTestBean.xml"));
    // 获取bean
		final MyTestBean testBean = factory.getBean("myTestBean",MyTestBean.class);
		final String testStr = testBean.getTestStr();
		System.out.println(testStr);
	}
````

​	从解析xml 到 获取bean都是从`XmlBeanFactory`中操作的,那么就来看看`XmlBeanFactory`里面有啥.

```java
public class XmlBeanFactory extends DefaultListableBeanFactory {

	private final XmlBeanDefinitionReader reader = new XmlBeanDefinitionReader(this);


	/**
	 * 构造函数
	 */
	public XmlBeanFactory(Resource resource) throws BeansException {
		this(resource, null);
	}

	/**
	 * 构造函数
	 * 指定 父BeanFactory
	 */
	public XmlBeanFactory(Resource resource, BeanFactory parentBeanFactory) throws BeansException {
		super(parentBeanFactory);
    // 核心代码 A
		this.reader.loadBeanDefinitions(resource);
	}

}

```

​	可以看到核心代码在A处,A处用`XmlBeanDefinitionReader`进行读取文件,继续跟下去.

```java
@Override
	public int loadBeanDefinitions(Resource resource) throws BeanDefinitionStoreException {
		// 把classPathsResource转换为EncodedResource,默认字符编码为空
		return loadBeanDefinitions(new EncodedResource(resource));
	}

	public int loadBeanDefinitions(EncodedResource encodedResource) throws BeanDefinitionStoreException {
		//加载资源,资源不能为空
		Assert.notNull(encodedResource, "EncodedResource must not be null");
		if (logger.isTraceEnabled()) {
			logger.trace("Loading XML bean definitions from " + encodedResource);
		}
		//判断当前线程是否加载过资源,如果没有则创建一个set来保存encodedResource
		Set<EncodedResource> currentResources = this.resourcesCurrentlyBeingLoaded.get();
		if (currentResources == null) {
			currentResources = new HashSet<>(4);
			this.resourcesCurrentlyBeingLoaded.set(currentResources);
		}
		//判断是否有已近添加过相同的encodedResource
		if (!currentResources.add(encodedResource)) {
			throw new BeanDefinitionStoreException(
					"Detected cyclic loading of " + encodedResource + " - check your import definitions!");
		}
		try {
			//获取xml文件流
			InputStream inputStream = encodedResource.getResource().getInputStream();
			try {
				InputSource inputSource = new InputSource(inputStream);
				//如果编码不为空,则设置文件编码
				if (encodedResource.getEncoding() != null) {
					inputSource.setEncoding(encodedResource.getEncoding());
				}
				//加载bean
        // B
				return doLoadBeanDefinitions(inputSource, encodedResource.getResource());
			}
			finally {
				inputStream.close();
			}
		}
		catch (IOException ex) {
			throw new BeanDefinitionStoreException(
					"IOException parsing XML document from " + encodedResource.getResource(), ex);
		}
		finally {
			currentResources.remove(encodedResource);
			if (currentResources.isEmpty()) {
				this.resourcesCurrentlyBeingLoaded.remove();
			}
		}
	}
```

​	以上代码在前面分析加载文件的时候已经看过了,不过这次的重点是在B处,继续跟下去.

```java
protected int doLoadBeanDefinitions(InputSource inputSource, Resource resource)
			throws BeanDefinitionStoreException {

		try {
			// 加载xml
			// C
			Document doc = doLoadDocument(inputSource, resource);
			// 注册bean
			// D
			int count = registerBeanDefinitions(doc, resource);
			if (logger.isDebugEnabled()) {
				logger.debug("Loaded " + count + " bean definitions from " + resource);
			}
			return count;
		}
		catch (BeanDefinitionStoreException ex) {
			throw ex;
		}
		catch (SAXParseException ex) {
			throw new XmlBeanDefinitionStoreException(resource.getDescription(),
					"Line " + ex.getLineNumber() + " in XML document from " + resource + " is invalid", ex);
		}
		catch (SAXException ex) {
			throw new XmlBeanDefinitionStoreException(resource.getDescription(),
					"XML document from " + resource + " is invalid", ex);
		}
		catch (ParserConfigurationException ex) {
			throw new BeanDefinitionStoreException(resource.getDescription(),
					"Parser configuration exception parsing XML from " + resource, ex);
		}
		catch (IOException ex) {
			throw new BeanDefinitionStoreException(resource.getDescription(),
					"IOException parsing XML document from " + resource, ex);
		}
		catch (Throwable ex) {
			throw new BeanDefinitionStoreException(resource.getDescription(),
					"Unexpected exception parsing XML document from " + resource, ex);
		}
	}
```

​	可以看到加载xml的地方是在C处,跟下去看看spring 有没有对加载xml文件做什么特殊处理.

```java
protected Document doLoadDocument(InputSource inputSource, Resource resource) throws Exception {
		return this.documentLoader.loadDocument(inputSource, getEntityResolver(), this.errorHandler,
				getValidationModeForResource(resource), isNamespaceAware());
	}
```

​	`doLoadDocument`方法并未对xml进行处理,而是委托`DocumentLoader`进行处理,而`DocumentLoader`又是个接口,这里使用的是它的默认实现`DefaultDocumentLoader`.

​	在`DocumentLoader`接口中只有一个方法.

```java
public interface DocumentLoader {

	/**
	 * @param inputSource xml 文件
	 * @param entityResolver 实体解析对象
	 * @param errorHandler 错误处理器
	 * @param validationMode 验证模式
	 * @param namespaceAware 是否自动感知名称空间
	 */
	Document loadDocument(
			InputSource inputSource, EntityResolver entityResolver,
			ErrorHandler errorHandler, int validationMode, boolean namespaceAware)
			throws Exception;
}

```

​	参数说明:

 - InputSource

   这个是指xml文件,这个没有什么好说的

- EntityResolver

  用于加载约束文件,这个约束文件就是xml的dtd和xsd.dtd和xsd是用于校验xml内容

  是否合法.而这个解析器跟前面ResourceLoader一样,最后都是用来查找文件,无论是

  在本地文件系统,还是在远程主机上.

- ErrorHandler

  用于处理加载xml过程中出现的异常,一般是记录日志

- validationMode

  用于指定验证模式,验证模式有四种:

  1. VALIDATION_NONE

     禁用验证

  2. VALIDATION_AUTO

     自动检测验证,默认值

  3. VALIDATION_DTD

     采用DTD验证

  4. VALIDATION_XSD

     采用XSD验证

- namespaceAware

  命名空间支持。如果要提供对 XML 名称空间的支持，则需要值为true

## 2.1 EntityResolver

​	`EntityResolver` 是通过 `getEntityResolver`方法获取的,`EntityResolver`也是个接口,用于解析dtd,xsd文件.

```java
public interface EntityResolver {

    public abstract InputSource resolveEntity (String publicId,
                                               String systemId)
        throws SAXException, IOException;

}
```

​	至于这两个参数,是什么意思,可以百度一下.

## 2.2 getEntityResolver() 方法

```java
protected EntityResolver getEntityResolver() {
		// 如果解析器为空
		if (this.entityResolver == null) {
			// Determine default EntityResolver to use.
			// 获取资源加载器
			ResourceLoader resourceLoader = getResourceLoader();
			if (resourceLoader != null) {
				// 如果资源加载器不为空,则使用资源实体解析器
				this.entityResolver = new ResourceEntityResolver(resourceLoader);
			}
			else {
				// 如果为空,则委托其他的解析器
				// 默认的为 BeansDtdResolver 和 PluggableSchemaResolver
				this.entityResolver = new DelegatingEntityResolver(getBeanClassLoader());
			}
		}
		return this.entityResolver;
	}
```

​	以上代码通过多次判断,要么返回`ResourceEntityResolver`要么返回`DelegatingEntityResolver`.这两个解析器是个什么关系?

​	![BgKHbU](https://itinfo.oss-cn-hongkong.aliyuncs.com/img/BgKHbU.jpg)	

​	可以看到 `ResourceEntityResolver`是继承`DelegatingEntityResolver`,而`DelegatingEntityResolver`实现了`EntityResolver`接口.

```java
public class ResourceEntityResolver extends DelegatingEntityResolver {

	private static final Log logger = LogFactory.getLog(ResourceEntityResolver.class);

	private final ResourceLoader resourceLoader;


	/**
	 * Create a ResourceEntityResolver for the specified ResourceLoader
	 * (usually, an ApplicationContext).
	 * @param resourceLoader the ResourceLoader (or ApplicationContext)
	 * to load XML entity includes with
	 */
	public ResourceEntityResolver(ResourceLoader resourceLoader) {
		super(resourceLoader.getClassLoader());
		this.resourceLoader = resourceLoader;
	}


	@Override
	@Nullable
	public InputSource resolveEntity(@Nullable String publicId, @Nullable String systemId)
			throws SAXException, IOException {
		// 调用父类 DelegatingEntityResolver::resolveEntity 获取xsd或者dtd,都是从本地的classpath路径下加载文件
		InputSource source = super.resolveEntity(publicId, systemId);

		//如果 DelegatingEntityResolver::resolveEntity 本地未能加载到xsd或者dtd文件
		if (source == null && systemId != null) {
			String resourcePath = null;
			try {
				// 使用UTF-8 解码
				String decodedSystemId = URLDecoder.decode(systemId, "UTF-8");
				// 转为URL
				String givenUrl = new URL(decodedSystemId).toString();
				// 解析文件资源的相对路径（相对于系统根路径）
				String systemRootUrl = new File("").toURI().toURL().toString();
				// Try relative to resource base if currently in system root.
				if (givenUrl.startsWith(systemRootUrl)) {
					resourcePath = givenUrl.substring(systemRootUrl.length());
				}
			}
			catch (Exception ex) {
				// Typically a MalformedURLException or AccessControlException.
				if (logger.isDebugEnabled()) {
					logger.debug("Could not resolve XML entity [" + systemId + "] against system root URL", ex);
				}
				// No URL (or no resolvable URL) -> try relative to resource base.
				resourcePath = systemId;
			}
			if (resourcePath != null) {
				if (logger.isTraceEnabled()) {
					logger.trace("Trying to locate XML entity [" + systemId + "] as resource [" + resourcePath + "]");
				}
				// 再次尝试从classpath路径下加载文件
				Resource resource = this.resourceLoader.getResource(resourcePath);
				source = new InputSource(resource.getInputStream());
				source.setPublicId(publicId);
				source.setSystemId(systemId);
				if (logger.isDebugEnabled()) {
					logger.debug("Found XML entity [" + systemId + "]: " + resource);
				}
			}//实在没有办法了,从网络上进行加载
			else if (systemId.endsWith(DTD_SUFFIX) || systemId.endsWith(XSD_SUFFIX)) {
				// External dtd/xsd lookup via https even for canonical http declaration
				String url = systemId;
				if (url.startsWith("http:")) {
					url = "https:" + url.substring(5);
				}
				try {
					//通过url http加载资源,网络情况不好的情况下很容易挂
					source = new InputSource(new URL(url).openStream());
					source.setPublicId(publicId);
					source.setSystemId(systemId);
				}
				catch (IOException ex) {
					if (logger.isDebugEnabled()) {
						logger.debug("Could not resolve XML entity [" + systemId + "] through URL [" + url + "]", ex);
					}
					// Fall back to the parser's default behavior.
					source = null;
				}
			}
		}

		return source;
	}

}

```

​	大致逻辑如下:

1. 调用父解析器,进行解析.如果能加载到文件,则返回.

 	2. 尝试从classpath路径进行加载
 	3. 尝试从网络上进行加载
 	4. 加载成功 返回 InputSource 对象 否则 返回 NULL

逻辑并不复杂,这里涉及到父解析器`DelegatingEntityResolver`.

```java
/*
 * Copyright 2002-2019 the original author or authors.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package org.springframework.beans.factory.xml;

import java.io.IOException;

import org.xml.sax.EntityResolver;
import org.xml.sax.InputSource;
import org.xml.sax.SAXException;

import org.springframework.lang.Nullable;
import org.springframework.util.Assert;

/**
 * {@link EntityResolver} implementation that delegates to a {@link BeansDtdResolver}
 * and a {@link PluggableSchemaResolver} for DTDs and XML schemas, respectively.
 *
 * @author Rob Harrop
 * @author Juergen Hoeller
 * @author Rick Evans
 * @since 2.0
 * @see BeansDtdResolver
 * @see PluggableSchemaResolver
 */
public class DelegatingEntityResolver implements EntityResolver {

	/** Suffix for DTD files. */
  // 后缀常量
	public static final String DTD_SUFFIX = ".dtd";

	/** Suffix for schema definition files. */
  // 后缀常量
	public static final String XSD_SUFFIX = ".xsd";

	// dtd 解析器
	private final EntityResolver dtdResolver;
	// xsd 解析器
	private final EntityResolver schemaResolver;


	
	public DelegatingEntityResolver(@Nullable ClassLoader classLoader) {
		this.dtdResolver = new BeansDtdResolver();
		this.schemaResolver = new PluggableSchemaResolver(classLoader);
	}

	
	public DelegatingEntityResolver(EntityResolver dtdResolver, EntityResolver schemaResolver) {
		Assert.notNull(dtdResolver, "'dtdResolver' is required");
		Assert.notNull(schemaResolver, "'schemaResolver' is required");
		this.dtdResolver = dtdResolver;
		this.schemaResolver = schemaResolver;
	}


	@Override
	@Nullable
	public InputSource resolveEntity(@Nullable String publicId, @Nullable String systemId)
			throws SAXException, IOException {
		//通过后缀去获取资源路径
		if (systemId != null) {
			// DTD 模式
			if (systemId.endsWith(DTD_SUFFIX)) {
				// 默认为 BeansDtdResolver
				return this.dtdResolver.resolveEntity(publicId, systemId);
			}
			// XSD 模式
			else if (systemId.endsWith(XSD_SUFFIX)) {
				// 默认为 PluggableSchemaResolver
				return this.schemaResolver.resolveEntity(publicId, systemId);
			}
		}

		// Fall back to the parser's default behavior.
		return null;
	}


	@Override
	public String toString() {
		return "EntityResolver delegating " + XSD_SUFFIX + " to " + this.schemaResolver +
				" and " + DTD_SUFFIX + " to " + this.dtdResolver;
	}

}

```

​	`DelegatingEntityResolver`中的`resolveEntity`方法并没有真正的进行逻辑处理,而是委托`dtdResolver`和

`schemaResolver`进行处理,这两个解析器一个负责DTD,另外一个负责XSD.

​	`dtdResolver` 默认为:`BeansDtdResolver`

​	`schemaResolver`默认为:`PluggableSchemaResolver`



## 2.3 BeansDtdResolver

```java
public class BeansDtdResolver implements EntityResolver {
	// DTD 后缀常量
	private static final String DTD_EXTENSION = ".dtd";
	// DTD 名称
	private static final String DTD_NAME = "spring-beans";

	private static final Log logger = LogFactory.getLog(BeansDtdResolver.class);


	@Override
	@Nullable
	public InputSource resolveEntity(@Nullable String publicId, @Nullable String systemId) throws IOException {
		if (logger.isTraceEnabled()) {
			logger.trace("Trying to resolve XML entity with public ID [" + publicId +
					"] and system ID [" + systemId + "]");
		}
		// 判断后缀是否是 DTD,并且systemId 不能为空
		if (systemId != null && systemId.endsWith(DTD_EXTENSION)) {
      // 分隔符
			int lastPathSeparator = systemId.lastIndexOf('/');
			int dtdNameStart = systemId.indexOf(DTD_NAME, lastPathSeparator);
			// systemId url 中 必须包含 spring-beans
			if (dtdNameStart != -1) {
				// 并且dtd文件名
				String dtdFile = DTD_NAME + DTD_EXTENSION;
				if (logger.isTraceEnabled()) {
					logger.trace("Trying to locate [" + dtdFile + "] in Spring jar on classpath");
				}
				try {
					// 加载classpath路径下的spring-beans.dtd文件
					Resource resource = new ClassPathResource(dtdFile, getClass());
					InputSource source = new InputSource(resource.getInputStream());
					// 设置publicId
					source.setPublicId(publicId);
					// 设置systemId
					source.setSystemId(systemId);
					if (logger.isTraceEnabled()) {
						logger.trace("Found beans DTD [" + systemId + "] in classpath: " + dtdFile);
					}
					return source;
				}
				catch (FileNotFoundException ex) {
					if (logger.isDebugEnabled()) {
						logger.debug("Could not resolve beans DTD [" + systemId + "]: not found in classpath", ex);
					}
				}
			}
		}

		// Fall back to the parser's default behavior.
		return null;
	}


	@Override
	public String toString() {
		return "EntityResolver for spring-beans DTD";
	}

}

```

 `BeansDtdResolver` 逻辑为,从classpath下加载文件名为`spring-beans.dtd`的dtd文件



## 2.4 PluggableSchemaResolver

```java
public class PluggableSchemaResolver implements EntityResolver {

	/**
	 * The location of the file that defines schema mappings.
	 * Can be present in multiple JAR files.
	 */
	public static final String DEFAULT_SCHEMA_MAPPINGS_LOCATION = "META-INF/spring.schemas";


	private static final Log logger = LogFactory.getLog(PluggableSchemaResolver.class);

	@Nullable
	private final ClassLoader classLoader;

	private final String schemaMappingsLocation;

	/** Stores the mapping of schema URL -> local schema path. */
	@Nullable
	private volatile Map<String, String> schemaMappings;


	
	public PluggableSchemaResolver(@Nullable ClassLoader classLoader) {
		this.classLoader = classLoader;
		this.schemaMappingsLocation = DEFAULT_SCHEMA_MAPPINGS_LOCATION;
	}

	public PluggableSchemaResolver(@Nullable ClassLoader classLoader, String schemaMappingsLocation) {
		Assert.hasText(schemaMappingsLocation, "'schemaMappingsLocation' must not be empty");
		this.classLoader = classLoader;
		this.schemaMappingsLocation = schemaMappingsLocation;
	}

	/***
	 * 先把xsd文件下载到本地,在进行加载
	 * **/
	@Override
	@Nullable
	public InputSource resolveEntity(@Nullable String publicId, @Nullable String systemId) throws IOException {
		if (logger.isTraceEnabled()) {
			logger.trace("Trying to resolve XML entity with public id [" + publicId +
					"] and system id [" + systemId + "]");
		}
		// systemId url 不能为空
		if (systemId != null) {
			// 从缓存中加载xsd文件
			// 判断缓存中是否有xsd文件
			// 缓存中的xsd文件都是从网络中加载
			String resourceLocation = getSchemaMappings().get(systemId);
			if (resourceLocation == null && systemId.startsWith("https:")) {
				// Retrieve canonical http schema mapping even for https declaration
				// 如果https 未找到约束文件 则尝试从http 获取缓存
				resourceLocation = getSchemaMappings().get("http:" + systemId.substring(6));
			}
			//如果缓存命中
			if (resourceLocation != null) {
				//从classpath路径中加载xsd文件
				Resource resource = new ClassPathResource(resourceLocation, this.classLoader);
				try {
					InputSource source = new InputSource(resource.getInputStream());
					// 设置publicId
					source.setPublicId(publicId);
					// 设置systemId
					source.setSystemId(systemId);
					if (logger.isTraceEnabled()) {
						logger.trace("Found XML schema [" + systemId + "] in classpath: " + resourceLocation);
					}
					return source;
				}
				catch (FileNotFoundException ex) {
					if (logger.isDebugEnabled()) {
						logger.debug("Could not find XML schema [" + systemId + "]: " + resource, ex);
					}
				}
			}
		}

		// Fall back to the parser's default behavior.
		return null;
	}

	/**
	 * Load the specified schema mappings lazily.
	 */
	private Map<String, String> getSchemaMappings() {
		Map<String, String> schemaMappings = this.schemaMappings;
		if (schemaMappings == null) {
			// 单利模式 同步
			synchronized (this) {
				schemaMappings = this.schemaMappings;
				// 双重检查
				if (schemaMappings == null) {
					if (logger.isTraceEnabled()) {
						logger.trace("Loading schema mappings from [" + this.schemaMappingsLocation + "]");
					}
					try {
						// 加载clsspath路径下的 META-INF/spring.schemas
						Properties mappings =
								PropertiesLoaderUtils.loadAllProperties(this.schemaMappingsLocation, this.classLoader);
						if (logger.isTraceEnabled()) {
							logger.trace("Loaded schema mappings: " + mappings);
						}
						// 创建线程安全的的hashMap
						schemaMappings = new ConcurrentHashMap<>(mappings.size());
						// properties 转 hashMap
						CollectionUtils.mergePropertiesIntoMap(mappings, schemaMappings);
						// 赋值
						this.schemaMappings = schemaMappings;
					}
					catch (IOException ex) {
						throw new IllegalStateException(
								"Unable to load schema mappings from location [" + this.schemaMappingsLocation + "]", ex);
					}
				}
			}
		}
		return schemaMappings;
	}


	@Override
	public String toString() {
		return "EntityResolver using schema mappings " + getSchemaMappings();
	}

}

```

​	`PluggableSchemaResolver`大体逻辑如下:

	1. 先根据classpath路径下的` META-INF/spring.schemas`文件创建一个缓存`schemaMappings`
	2. 从`schemaMappings`获取指定`systemId`的xsd文件路径,如果未获取到返回null
	3. 根据xsd路径加载xsd文件返回 `InputSource` 对象



## 2.5 getValidationModeForResource()

```java
protected int getValidationModeForResource(Resource resource) {
		// 获取验证模式,默认为自动
		int validationModeToUse = getValidationMode();
		// 如果手动指定验证模式则使用指定的验证模式
		if (validationModeToUse != VALIDATION_AUTO) {
			return validationModeToUse;
		}
		// 非手动指定验证模式,自动检测验证模式
		int detectedMode = detectValidationMode(resource);
		if (detectedMode != VALIDATION_AUTO) {
			return detectedMode;
		}
		// Hmm, we didn't get a clear indication... Let's assume XSD,
		// since apparently no DTD declaration has been found up until
		// detection stopped (before finding the document's root tag).
		// 以上都未获取验证模式,则使用xsd验证模式
		return VALIDATION_XSD;
	}
```



## 2.6 loadDocument()

```java
@Override
	public Document loadDocument(InputSource inputSource, EntityResolver entityResolver,
			ErrorHandler errorHandler, int validationMode, boolean namespaceAware) throws Exception {
		// 解析xml常用套路
		DocumentBuilderFactory factory = createDocumentBuilderFactory(validationMode, namespaceAware);
		if (logger.isTraceEnabled()) {
			logger.trace("Using JAXP provider [" + factory.getClass().getName() + "]");
		}
		// 解析xml常用套路
		DocumentBuilder builder = createDocumentBuilder(factory, entityResolver, errorHandler);
		return builder.parse(inputSource);
	}

	/**
	 * Create the {@link DocumentBuilderFactory} instance.
	 * @param validationMode the type of validation: {@link XmlValidationModeDetector#VALIDATION_DTD DTD}
	 * or {@link XmlValidationModeDetector#VALIDATION_XSD XSD})
	 * @param namespaceAware whether the returned factory is to provide support for XML namespaces
	 * @return the JAXP DocumentBuilderFactory
	 * @throws ParserConfigurationException if we failed to build a proper DocumentBuilderFactory
	 */
	protected DocumentBuilderFactory createDocumentBuilderFactory(int validationMode, boolean namespaceAware)
			throws ParserConfigurationException {

		DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
		// 设置命名空间支持
		factory.setNamespaceAware(namespaceAware);
		// 非禁用验证模式
		if (validationMode != XmlValidationModeDetector.VALIDATION_NONE) {
			// 开启校验
			factory.setValidating(true);
			// 如果为XSD
			if (validationMode == XmlValidationModeDetector.VALIDATION_XSD) {
				// Enforce namespace aware for XSD...
				// XSD 模式下，强制设置命名空间支持
				factory.setNamespaceAware(true);
				try {
					// 设置 SCHEMA_LANGUAGE_ATTRIBUTE
					factory.setAttribute(SCHEMA_LANGUAGE_ATTRIBUTE, XSD_SCHEMA_LANGUAGE);
				}
				catch (IllegalArgumentException ex) {
					ParserConfigurationException pcex = new ParserConfigurationException(
							"Unable to validate using XSD: Your JAXP provider [" + factory +
							"] does not support XML Schema. Are you running on Java 1.4 with Apache Crimson? " +
							"Upgrade to Apache Xerces (or Java 1.5) for full XSD support.");
					pcex.initCause(ex);
					throw pcex;
				}
			}
		}

		return factory;
	}

```



# 三、小结

​	xml 加载并创建为 `Document` 对象,接下来就是 解析并创建为bean.
