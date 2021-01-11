---
title: "[断点分析之spring-ioc]-xml标签解析(四)"
date: 2020/02/14 14:20:25
tags:
- spring
- java
categories: spring
cover: https://gitee.com/oneww/onew_image/raw/master/spring_cover.png
author: 
  nick: onew
  link: https://onew.me
subtitle: spring xml标签解析
---



# 一、前言

​	接上文,分析了spring 把 xml 文件读取到内存中,并生成一个`document`对象,然而离创建`bean`还比较遥远.在xml中定了`bean`该如何创建的规则,而spring也是遵循xml中的标签所描述规则来进行创建`bean`.接下来就是要分析,spring是如何解析这些标签的.



# 二、分析

​	还是常规套路,从下面的测试代码开始.

```java
@Test
	public void testSpringLoadXml(){
		BeanFactory factory = new XmlBeanFactory(new ClassPathResource("com/sjr/test/bean/MyTestBean.xml"));
		final MyTestBean testBean = factory.getBean("myTestBean",MyTestBean.class);
		final String testStr = testBean.getTestStr();
		System.out.println(testStr);
	}
```

​	xml内容如下:

```xml
<?xml version="1.0" encoding="ISO-8859-1"?>
<beans xmlns="http://www.springframework.org/schema/beans"
	   xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
	   xsi:schemaLocation="http://www.springframework.org/schema/beans
                       https://www.springframework.org/schema/beans/spring-beans-3.0.xsd">
	<bean id="myTestBean" class="com.sjr.test.bean.MyTestBean"/>
</beans>

```

​	结合xml,就可以让spring创建一个`MyTestBean`对象出来.那么spring是怎么办到的呢?

```java
// XmlBeanDefinitionReader
protected int doLoadBeanDefinitions(InputSource inputSource, Resource resource)
			throws BeanDefinitionStoreException {

		try {
			// 加载xml
      // 加载xml的时候这里已经讲过了
			Document doc = doLoadDocument(inputSource, resource);
			// 注册bean
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

​	看来答案出现在`int count = registerBeanDefinitions(doc, resource);`这句代码里面

## 2.1 registerBeanDefinitions()

```java
//xmlBeanDefinitionReader
/***
* @param doc 通过xml 创建的document对象
* @param resource xml 资源对象
* @return 注册的数量
*/
public int registerBeanDefinitions(Document doc, Resource resource) throws BeanDefinitionStoreException {
		// 创建BeanDefinitionDocumentReader 默认是DefaultBeanDefinitionDocumentReader
		BeanDefinitionDocumentReader documentReader = createBeanDefinitionDocumentReader();
		// 获取已经注册的bean的数量,beanDefinitionMap.size()
		int countBefore = getRegistry().getBeanDefinitionCount();
    // 注册xml bean定义
		documentReader.registerBeanDefinitions(doc, createReaderContext(resource));
  	// 返回已经注册的数量
		return getRegistry().getBeanDefinitionCount() - countBefore;
	}
```

​	解析xml标签的核心逻辑在于`documentReader.registerBeanDefinitions(doc, createReaderContext(resource));`,逐步分析一下.



## 2.2 createReaderContext(resource)

```java
//xmlBeanDefinitionReader
public XmlReaderContext createReaderContext(Resource resource) {
		return new XmlReaderContext(resource, this.problemReporter, this.eventListener,
				this.sourceExtractor, this, getNamespaceHandlerResolver());
	}
```

​	这个对象相当于是个工具类,里面未封装逻辑代码.封装了一些日志相关的函数,获取resource的函数等.这里值得注意是`getNamespaceHandlerResolver()`这个方法,这个方法返回了一个`NamespaceHandlerResolver`对象,这个对象是用于解析指定名称空间的解析器,如果要自定义标签就得要这个对象来帮忙.



```java
 //xmlBeanDefinitionReader
	public NamespaceHandlerResolver getNamespaceHandlerResolver() {
		// 如果名称空间解析器为空,则创建一个默认的名称空间解析器
    if (this.namespaceHandlerResolver == null) {
			this.namespaceHandlerResolver = createDefaultNamespaceHandlerResolver();
		}
		return this.namespaceHandlerResolver;
	}

	/**
	 * Create the default implementation of {@link NamespaceHandlerResolver} used if none is specified.
	 * <p>The default implementation returns an instance of {@link DefaultNamespaceHandlerResolver}.
	 * @see DefaultNamespaceHandlerResolver#DefaultNamespaceHandlerResolver(ClassLoader)
	 */
	protected NamespaceHandlerResolver createDefaultNamespaceHandlerResolver() {
		// 获取classLoader
    ClassLoader cl = (getResourceLoader() != null ? getResourceLoader().getClassLoader() : getBeanClassLoader());
    // 创建默认的名称空间解析器
		return new DefaultNamespaceHandlerResolver(cl);
	}
```



## 2.3 registerBeanDefinitions()

```java
 // DefaultBeanDefinitionDocumentReader
	// bean
	public static final String BEAN_ELEMENT = BeanDefinitionParserDelegate.BEAN_ELEMENT;

	public static final String NESTED_BEANS_ELEMENT = "beans";

	public static final String ALIAS_ELEMENT = "alias";

	public static final String NAME_ATTRIBUTE = "name";

	public static final String ALIAS_ATTRIBUTE = "alias";

	public static final String IMPORT_ELEMENT = "import";

	public static final String RESOURCE_ATTRIBUTE = "resource";

	public static final String PROFILE_ATTRIBUTE = "profile";


	@Override
	public void registerBeanDefinitions(Document doc, XmlReaderContext readerContext) {
		this.readerContext = readerContext;
		doRegisterBeanDefinitions(doc.getDocumentElement());
	}

	protected void doRegisterBeanDefinitions(Element root) {
		// Any nested <beans> elements will cause recursion in this method. In
		// order to propagate and preserve <beans> default-* attributes correctly,
		// keep track of the current (parent) delegate, which may be null. Create
		// the new (child) delegate with a reference to the parent for fallback purposes,
		// then ultimately reset this.delegate back to its original (parent) reference.
		// this behavior emulates a stack of delegates without actually necessitating one.
		// root节点进来默认委托为null
		BeanDefinitionParserDelegate parent = this.delegate;
		// 创建委托,用于解析各个标签
    // BeanDefinitionParserDelegate
		this.delegate = createDelegate(getReaderContext(), root, parent);

		// 处理profile属性,用于切换不同环境的配置文件
		if (this.delegate.isDefaultNamespace(root)) {
			// 判断是否含有profile属性
			String profileSpec = root.getAttribute(PROFILE_ATTRIBUTE);
			// 如果profile属性不为空
			if (StringUtils.hasText(profileSpec)) {
				// 可能会有多个profile属性,使用,;进行分割
				String[] specifiedProfiles = StringUtils.tokenizeToStringArray(
						profileSpec, BeanDefinitionParserDelegate.MULTI_VALUE_ATTRIBUTE_DELIMITERS);
				// We cannot use Profiles.of(...) since profile expressions are not supported
				// in XML config. See SPR-12458 for details.
				// 如果不是有效的profile 则返回
				if (!getReaderContext().getEnvironment().acceptsProfiles(specifiedProfiles)) {
					if (logger.isDebugEnabled()) {
						logger.debug("Skipped XML bean definition file due to specified profiles [" + profileSpec +
								"] not matching: " + getReaderContext().getResource());
					}
					return;
				}
			}
		}
		// 前置解析器(空逻辑,留给子类去完善)
		preProcessXml(root);
		// 核心逻辑
		parseBeanDefinitions(root, this.delegate);
		// 后置解析器(空逻辑,留给子类去完善)
		postProcessXml(root);

		this.delegate = parent;
	}
```

1. 根节点默认没有父节点为NULL
2. 创建委托用于解析xml标签
3. 判断是否有多个环境配置,并切换配置
4. 开始解析

​	`preProcessXml(root)`方法和`postProcessXm(root)`默认都是空实现,这里是应用的设计模式为 模板模式,增强扩展新,子类需要扩展只需要去实现这两个方法即可.



## 2.4 parseBeanDefinitions

```java
protected void parseBeanDefinitions(Element root, BeanDefinitionParserDelegate delegate) {
		// 如果根节点使用默认命名空间，执行默认解析
		if (delegate.isDefaultNamespace(root)) {
			// 获取节点下面的子节点
			NodeList nl = root.getChildNodes();
			// 遍历子节点
			for (int i = 0; i < nl.getLength(); i++) {
				Node node = nl.item(i);
				if (node instanceof Element) {
					Element ele = (Element) node;
					if (delegate.isDefaultNamespace(ele)) {
						// 解析默认名称空间元素
						parseDefaultElement(ele, delegate);
					}
					else {
						// 解析自定义名称命名空间
						delegate.parseCustomElement(ele);
					}
				}
			}
		}
		else {
			// 解析自定义名称命名空间
			delegate.parseCustomElement(root);
		}
	}
```

​	这里从判断节点是否是默认的名称命名空间,从而引发了2种不同的逻辑分支.一个是执行spring的内置的解析逻辑,另一个是执行自定义的解析逻辑.

​	spring判断是否是默认的名称空间依据是:如果`namespaceUri`为空并且不等于`http://www.springframework.org/schema/beans`,则判断为非默认名称空间.



# 三、默认解析

```java
// DefaultBeanDefinitionDocumentReader
private void parseDefaultElement(Element ele, BeanDefinitionParserDelegate delegate) {
		// 默认名称空间解析,由此可见spring默认名称命名空间只有4个
		// import alias bean beans
		// import 标签处理.用于加载引用进来的xml
		if (delegate.nodeNameEquals(ele, IMPORT_ELEMENT)) {
			importBeanDefinitionResource(ele);
		}
		// alias 标签处理
		else if (delegate.nodeNameEquals(ele, ALIAS_ELEMENT)) {
			processAliasRegistration(ele);
		}
		// bean 标签处理
		else if (delegate.nodeNameEquals(ele, BEAN_ELEMENT)) {
			processBeanDefinition(ele, delegate);
		}
		// beans 标签处理
		else if (delegate.nodeNameEquals(ele, NESTED_BEANS_ELEMENT)) {
			// recurse 递归解析
			doRegisterBeanDefinitions(ele);
		}
	}
```



## 3.1 import标签

```java
// DefaultBeanDefinitionDocumentReader
protected void importBeanDefinitionResource(Element ele) {
		// 获取resource属性,用于加载文件
		String location = ele.getAttribute(RESOURCE_ATTRIBUTE);
		// 如果为空则退出
		if (!StringUtils.hasText(location)) {
			getReaderContext().error("Resource location must not be empty", ele);
			return;
		}
		// 解析当前环境中的文件路径
		// Resolve system properties: e.g. "${user.dir}"
		location = getReaderContext().getEnvironment().resolveRequiredPlaceholders(location);

		Set<Resource> actualResources = new LinkedHashSet<>(4);

		// Discover whether the location is an absolute or relative URI
		boolean absoluteLocation = false;
		try {
			absoluteLocation = ResourcePatternUtils.isUrl(location) || ResourceUtils.toURI(location).isAbsolute();
		}
		catch (URISyntaxException ex) {
			// cannot convert to an URI, considering the location relative
			// unless it is the well-known Spring prefix "classpath*:"
		}

		// 判断是绝对路径还是相对路径
		// Absolute or relative?
		if (absoluteLocation) {
			// 绝对路径
			try {
				// 加载resource属性中的xml文件,加载bean定义
				int importCount = getReaderContext().getReader().loadBeanDefinitions(location, actualResources);
				if (logger.isTraceEnabled()) {
					logger.trace("Imported " + importCount + " bean definitions from URL location [" + location + "]");
				}
			}
			catch (BeanDefinitionStoreException ex) {
				getReaderContext().error(
						"Failed to import bean definitions from URL location [" + location + "]", ele, ex);
			}
		}
		else {
			// 相对路径
			// No URL -> considering resource location as relative to the current file.
			try {
				int importCount;
				Resource relativeResource = getReaderContext().getResource().createRelative(location);
				// 判断资源文件是否存在
				if (relativeResource.exists()) {
					// 加载文件
					importCount = getReaderContext().getReader().loadBeanDefinitions(relativeResource);
					actualResources.add(relativeResource);
				}
				else {
					// 转换为绝对路径
					String baseLocation = getReaderContext().getResource().getURL().toString();
					// 加载文件
					importCount = getReaderContext().getReader().loadBeanDefinitions(
							// 计算绝对路径
							StringUtils.applyRelativePath(baseLocation, location), actualResources);
				}
				if (logger.isTraceEnabled()) {
					logger.trace("Imported " + importCount + " bean definitions from relative location [" + location + "]");
				}
			}
			catch (IOException ex) {
				getReaderContext().error("Failed to resolve current resource location", ele, ex);
			}
			catch (BeanDefinitionStoreException ex) {
				getReaderContext().error(
						"Failed to import bean definitions from relative location [" + location + "]", ele, ex);
			}
		}
		// 转换为数组
		Resource[] actResArray = actualResources.toArray(new Resource[0]);
		// 释放资源
		getReaderContext().fireImportProcessed(location, actResArray, extractSource(ele));
	}

```

1. 判断路径是否为空
2. 如果为相对路径,加载xml文件
3. 如果为绝对路径,判断文件是否存在,存在则加载文件
4. 如果文件不存在,转换为相对路径,加载文件

## 3.2 alias标签

```java
// DefaultBeanDefinitionDocumentReader	
protected void processAliasRegistration(Element ele) {
    // 获取name属性值
		String name = ele.getAttribute(NAME_ATTRIBUTE);
    // 获取alias属性值
		String alias = ele.getAttribute(ALIAS_ATTRIBUTE);
		boolean valid = true;
		// 验证名称是否合法
		if (!StringUtils.hasText(name)) {
			getReaderContext().error("Name must not be empty", ele);
			valid = false;
		}
		// 验证别名是否合法
		if (!StringUtils.hasText(alias)) {
			getReaderContext().error("Alias must not be empty", ele);
			valid = false;
		}
		// 验证通过映射别名
		if (valid) {
			try {
        // 注册别名
				getReaderContext().getRegistry().registerAlias(name, alias);
			}
			catch (Exception ex) {
				getReaderContext().error("Failed to register alias '" + alias +
						"' for bean with name '" + name + "'", ele, ex);
			}
			// 发送事件
			getReaderContext().fireAliasRegistered(name, alias, extractSource(ele));
		}
	}
```

1. 获取name属性值
2. 获取alias属性值
3. 验证alias是否合法
4. 如果合法则进行注册

```java
// DefaultBeanDefinitionDocumentReader
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

​	这里的逻辑比较简单,循环引用这里有点意思.

```java
// DefaultBeanDefinitionDocumentReader
protected void checkForAliasCircle(String name, String alias) {
  	// 注意这里把 alias 和 name 调换了一下位置
		if (hasAlias(alias, name)) {
			throw new IllegalStateException("Cannot register alias '" + alias +
					"' for name '" + name + "': Circular reference - '" +
					name + "' is a direct or indirect alias for '" + alias + "' already");
		}
	}
/**
* 由于调换过参数顺序,所以理解的时候需要调换回来
*/
public boolean hasAlias(String name, String alias) {
		for (Map.Entry<String, String> entry : this.aliasMap.entrySet()) {
			String registeredName = entry.getValue();
			if (registeredName.equals(name)) {
				String registeredAlias = entry.getKey();
				if (registeredAlias.equals(alias) || hasAlias(registeredAlias, alias)) {
					return true;
				}
			}
		}
		return false;
	}

```

​	光看代码估计会比较蒙,来举例看看.

​	准备三对 别名->名称:

| alias | name |
| ----- | ---- |
| A     | B    |
| B     | C    |
| C     | A    |

1. 检查 A->B 是否存在循环引用
   - 由于集合是空的,所以不存在循环引用.
2. 检查B->C是否存在循环引用
   - 遍历集合获取value: B
   - B==B(注意这里的name其实是alias)
   - 获取集合中的key: A 
   - A != C 把 A->C当作参数进行递归
   - 递归检查不存在循环引用
3. 检查C-A是否存在循环引用
   - 遍历集合获取value: B
   - B != C
   - 遍历集合获取value: C
   - C == C
   - 获取集合中的key: B
   - B != A,把B->A作为参数递归
   - 遍历集合获取value: B
   - B==B
   - 获取集合中的key: A
   - A == A 停止递归,返回true
   - 存在循环引用

之所以这个逻辑有点绕因为这个参数调换了一下位置,建议用笔画一下就豁达了.LOL :).



## 3.3 bean标签

```java
// DefaultBeanDefinitionDocumentReader
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

1. 解析xml创建`BeanDefinitionHolder`
2. 如果不为空,进行进行装饰
3. 注册到容器中
4. 发送事件

### 3.3.1 parseBeanDefinitionElement()

```java
// BeanDefinitionParserDelegate
 @Nullable
	public BeanDefinitionHolder parseBeanDefinitionElement(Element ele) {
		return parseBeanDefinitionElement(ele, null);
	}

	/**
	 * Parses the supplied {@code <bean>} element. May return {@code null}
	 * if there were errors during parse. Errors are reported to the
	 * {@link org.springframework.beans.factory.parsing.ProblemReporter}.
	 */
	@Nullable
	public BeanDefinitionHolder parseBeanDefinitionElement(Element ele, @Nullable BeanDefinition containingBean) {
		// 获取id
		String id = ele.getAttribute(ID_ATTRIBUTE);
		// 获取名称
		String nameAttr = ele.getAttribute(NAME_ATTRIBUTE);
		// 获取别名,别名可以使用多个
		List<String> aliases = new ArrayList<>();
		// 名称不为空
		if (StringUtils.hasLength(nameAttr)) {
			// 如果有多个名称,使用,;切割
			String[] nameArr = StringUtils.tokenizeToStringArray(nameAttr, MULTI_VALUE_ATTRIBUTE_DELIMITERS);
			aliases.addAll(Arrays.asList(nameArr));
		}
		// bean名称就是id
		String beanName = id;
		// 如果名称为空,并且别名集合不为空,则从别名中获取第一个,作为名称
		if (!StringUtils.hasText(beanName) && !aliases.isEmpty()) {
			beanName = aliases.remove(0);
			if (logger.isTraceEnabled()) {
				logger.trace("No XML 'id' specified - using '" + beanName +
						"' as bean name and " + aliases + " as aliases");
			}
		}

		if (containingBean == null) {
			// 检查beanName是否唯一(名称未被使用过)
			checkNameUniqueness(beanName, aliases, ele);
		}
		// 解析标签封装为beanDefinition
		AbstractBeanDefinition beanDefinition = parseBeanDefinitionElement(ele, beanName, containingBean);
		// beanDefinition对象不为空
		if (beanDefinition != null) {
			// beanName为空
			if (!StringUtils.hasText(beanName)) {
				try {
					if (containingBean != null) {
						// 生成bean的 name
						beanName = BeanDefinitionReaderUtils.generateBeanName(
								beanDefinition, this.readerContext.getRegistry(), true);
					}
					else {
            // 生成bean的 name
						beanName = this.readerContext.generateBeanName(beanDefinition);
						// Register an alias for the plain bean class name, if still possible,
						// if the generator returned the class name plus a suffix.
						// This is expected for Spring 1.2/2.0 backwards compatibility.
            // 获取 className
						String beanClassName = beanDefinition.getBeanClassName();
            // 判断bean名称不为空 并且 以类名开头 并且名称没有被使用
						if (beanClassName != null &&
								beanName.startsWith(beanClassName) && beanName.length() > beanClassName.length() &&
								!this.readerContext.getRegistry().isBeanNameInUse(beanClassName)) {
							aliases.add(beanClassName);
						}
					}
					if (logger.isTraceEnabled()) {
						logger.trace("Neither XML 'id' nor 'name' specified - " +
								"using generated bean name [" + beanName + "]");
					}
				}
				catch (Exception ex) {
					error(ex.getMessage(), ele);
					return null;
				}
			}
			// 别名集合转为数组
			String[] aliasesArray = StringUtils.toStringArray(aliases);
			// 返回BeanDefinitionHolder
			return new BeanDefinitionHolder(beanDefinition, beanName, aliasesArray);
		}

		return null;
	}
```

​	以上代码逻辑不是很复杂,核心逻辑在于通过`AbstractBeanDefinition`转换为`BeanDefinitionHolder`,核心代码`AbstractBeanDefinition beanDefinition = parseBeanDefinitionElement(ele, beanName, containingBean);`



# 四、小结

​	由于后面的逻辑比较复杂,打算分两章来写,天色已晚,准备吃饭.

