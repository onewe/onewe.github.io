---
title: "[断点分析之spring-ioc]-bean标签解析(五)"
date: 2020/02/19 14:20:25
tags:
- spring
- java
categories: spring
cover: https://gitee.com/oneww/onew_image/raw/master/spring_cover.png
author: 
  nick: onew
  link: https://onew.me
subtitle: spring bean标签解析
---



# 一、前言

​	分析了`import`标签、`alias`标签,顺势引出了`bean`标签,只不过`bean`标签逻辑较为复杂没有记录完.

# 二、从BeanDefinitionParserDelegate开始

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

​	核心逻辑在于`	AbstractBeanDefinition beanDefinition = parseBeanDefinitionElement(ele, beanName, containingBean);`这句代码,进去看看.



## 2.1 parseBeanDefinitionElement

```java
  // BeanDefinitionParserDelegate
  @Nullable
	public AbstractBeanDefinition parseBeanDefinitionElement(
			Element ele, String beanName, @Nullable BeanDefinition containingBean) {
		// 放入状态对象到链表中
		this.parseState.push(new BeanEntry(beanName));

		String className = null;
		// 判断是否拥有class属性
		if (ele.hasAttribute(CLASS_ATTRIBUTE)) {
			// 获取className属性值
			className = ele.getAttribute(CLASS_ATTRIBUTE).trim();
		}
		String parent = null;
		// 判断是否拥有parent属性
		if (ele.hasAttribute(PARENT_ATTRIBUTE)) {
			// 获取parent属性值
			parent = ele.getAttribute(PARENT_ATTRIBUTE);
		}
		try {
			// 创建BeanDefinitio对象,封装bean的描述信息
			AbstractBeanDefinition bd = createBeanDefinition(className, parent);
			// 解析bean标签中的各种属性,例如:singleton,scope,abstract等属性
			parseBeanDefinitionAttributes(ele, beanName, containingBean, bd);
			// 提取描述信息
			bd.setDescription(DomUtils.getChildElementValueByTagName(ele, DESCRIPTION_ELEMENT));
			// 解析元数据
			parseMetaElements(ele, bd);
			// 解析lookup-method,相当于动态代理了,可利用此功能来进行热插拔,不用修改代码
			// 此功能可以修改方法的返回值
			parseLookupOverrideSubElements(ele, bd.getMethodOverrides());
			// 解析replaced-method,此功能可在运行过程中替换掉原有的方法,与lookup-method有点不同
			// 要替换需要实现MethodReplacer接口才能替换掉目标方法
			parseReplacedMethodSubElements(ele, bd.getMethodOverrides());
			// 解析构造方法参数
			parseConstructorArgElements(ele, bd);
			// 解析property属性
			parsePropertyElements(ele, bd);
			// 解析qualifier属性
			parseQualifierElements(ele, bd);

			bd.setResource(this.readerContext.getResource());
			bd.setSource(extractSource(ele));

			return bd;
		}
		catch (ClassNotFoundException ex) {
			error("Bean class [" + className + "] not found", ele, ex);
		}
		catch (NoClassDefFoundError err) {
			error("Class that bean class [" + className + "] depends on not found", ele, err);
		}
		catch (Throwable ex) {
			error("Unexpected failure during bean definition parsing", ele, ex);
		}
		finally {
			// 弹出解析状态
			this.parseState.pop();
		}

		return null;
	}

```

1. 判断是否拥有class属性,获取class属性值
2. 判断是否拥有parent属性,获取parent属性值
3. 创建`AbstractBeanDefinition`对象
4. 解析`bean`标签中的描述信息,例如:singleton,scope,abstract等属性
5. 提取描述信息
6. 解析元数据
7. 解析`lookup-method`
8. 解析`replaced-method`
9. 解析构造方法参数
10. 解析`property`属性
11. 解析`qualifier`属性

大体逻辑如上,以上步骤从步骤3开始进行分析.



## 2.2 createBeanDefinition

```java
// BeanDefinitionParserDelegate
protected AbstractBeanDefinition createBeanDefinition(@Nullable String className, @Nullable String parentName)
			throws ClassNotFoundException {

		return BeanDefinitionReaderUtils.createBeanDefinition(
				parentName, className, this.readerContext.getBeanClassLoader());
	}
```

```java
// BeanDefinitionReaderUtils
public static AbstractBeanDefinition createBeanDefinition(
			@Nullable String parentName, @Nullable String className, @Nullable ClassLoader classLoader) throws ClassNotFoundException {

		GenericBeanDefinition bd = new GenericBeanDefinition();
		bd.setParentName(parentName);
		if (className != null) {
			if (classLoader != null) {
				// 加载类
				bd.setBeanClass(ClassUtils.forName(className, classLoader));
			}
			else {
				// 如果class-loader为空则只记录类名
				bd.setBeanClassName(className);
			}
		}
		return bd;
	}
```

1. 判断类加载器是否为空,如果类加载器不为空则使用指定的类加载器加载类
2. 返回`GenericBeanDefinition`对象

以上逻辑比较简单,重点是`GenericBeanDefinition`这个对象.



## 2.3 GenericBeanDefinition

​	`GenericBeanDefinition`是用于描述`bean`,该类继承了`AbstractBeanDefinition`.如下图:

![images](https://gitee.com/oneww/onew_image/raw/master/GenericBeanDefinition.png)

​	总共有2个作用,描述`bean`的信息,访问`bean`中的属性值.

## 2.4 parseBeanDefinitionAttributes

```java
// BeanDefinitionParserDelegate
public AbstractBeanDefinition parseBeanDefinitionAttributes(Element ele, String beanName,
			@Nullable BeanDefinition containingBean, AbstractBeanDefinition bd) {
		// 解析singleton属性
		// singleton属性不能使用,已经过时
		if (ele.hasAttribute(SINGLETON_ATTRIBUTE)) {
			error("Old 1.x 'singleton' attribute in use - upgrade to 'scope' declaration", ele);
		}
		// 判断是否存在scope属性
		else if (ele.hasAttribute(SCOPE_ATTRIBUTE)) {
			// 设置scope属性值
			bd.setScope(ele.getAttribute(SCOPE_ATTRIBUTE));
		}
		else if (containingBean != null) {
			// Take default from containing bean in case of an inner bean definition.
			bd.setScope(containingBean.getScope());
		}
		// 判断是否存在abstract属性
		if (ele.hasAttribute(ABSTRACT_ATTRIBUTE)) {
			// 设置abstract属性值
			bd.setAbstract(TRUE_VALUE.equals(ele.getAttribute(ABSTRACT_ATTRIBUTE)));
		}
		// 解析lazy-init属性
		String lazyInit = ele.getAttribute(LAZY_INIT_ATTRIBUTE);
		if (isDefaultValue(lazyInit)) {
			lazyInit = this.defaults.getLazyInit();
		}
		// 设置懒加载值
		bd.setLazyInit(TRUE_VALUE.equals(lazyInit));
		// 获取自动装配属性值
		String autowire = ele.getAttribute(AUTOWIRE_ATTRIBUTE);
		// 设置自动装配模式
		bd.setAutowireMode(getAutowireMode(autowire));
		// 判断是否存在depends-on属性
		if (ele.hasAttribute(DEPENDS_ON_ATTRIBUTE)) {
			// 获取depends-on属性值
			String dependsOn = ele.getAttribute(DEPENDS_ON_ATTRIBUTE);
			// 设置depends-on属性值
			bd.setDependsOn(StringUtils.tokenizeToStringArray(dependsOn, MULTI_VALUE_ATTRIBUTE_DELIMITERS));
		}
		// 解析autowire属性,自动装配.存在条件判断
		String autowireCandidate = ele.getAttribute(AUTOWIRE_CANDIDATE_ATTRIBUTE);
		if (isDefaultValue(autowireCandidate)) {
			String candidatePattern = this.defaults.getAutowireCandidates();
			if (candidatePattern != null) {
				String[] patterns = StringUtils.commaDelimitedListToStringArray(candidatePattern);
				bd.setAutowireCandidate(PatternMatchUtils.simpleMatch(patterns, beanName));
			}
		}
		else {
			// 设置autowire-candidate属性值
			bd.setAutowireCandidate(TRUE_VALUE.equals(autowireCandidate));
		}
		// 判断是否存在primary属性
		if (ele.hasAttribute(PRIMARY_ATTRIBUTE)) {
			// 设置primary值
			bd.setPrimary(TRUE_VALUE.equals(ele.getAttribute(PRIMARY_ATTRIBUTE)));
		}
		// 判断是否存在init属性
		if (ele.hasAttribute(INIT_METHOD_ATTRIBUTE)) {
			// 获取init属性值
			String initMethodName = ele.getAttribute(INIT_METHOD_ATTRIBUTE);
			// 设置init属性值
			bd.setInitMethodName(initMethodName);
		}
		// 设置init属性默认值
		else if (this.defaults.getInitMethod() != null) {
			bd.setInitMethodName(this.defaults.getInitMethod());
			bd.setEnforceInitMethod(false);
		}
		// 判断是否存在destroy属性
		if (ele.hasAttribute(DESTROY_METHOD_ATTRIBUTE)) {
			// 获取destroy属性值
			String destroyMethodName = ele.getAttribute(DESTROY_METHOD_ATTRIBUTE);
			// 设置destroy属性值
			bd.setDestroyMethodName(destroyMethodName);
		}
		// 设置destroy属性默认值
		else if (this.defaults.getDestroyMethod() != null) {
			bd.setDestroyMethodName(this.defaults.getDestroyMethod());
			bd.setEnforceDestroyMethod(false);
		}
		// 判断是否存在factory属性
		if (ele.hasAttribute(FACTORY_METHOD_ATTRIBUTE)) {
			// 设置factory属性值
			bd.setFactoryMethodName(ele.getAttribute(FACTORY_METHOD_ATTRIBUTE));
		}
		// 判断是否存在factory-bean属性
		if (ele.hasAttribute(FACTORY_BEAN_ATTRIBUTE)) {
			// 设置factory-bean属性值
			bd.setFactoryBeanName(ele.getAttribute(FACTORY_BEAN_ATTRIBUTE));
		}

		return bd;
	}
```

1. 设置`BeanDefinition`的scope属性值
2. 设置`BeanDefinition`的abstract属性值
3. 设置`BeanDefinition`的lazy-init属性值
4. 设置`BeanDefinition`的autowire属性值
5. 设置`BeanDefinition`的depends-on属性值
6. 设置`BeanDefinition`的autowire-candidate属性值
7. 设置`BeanDefinition`的primary属性值
8. 设置`BeanDefinition`的init-method属性值
9. 设置`BeanDefinition`的destroy-method属性值
10. 设置`BeanDefinition`的factory-method属性值
11. 设置`BeanDefinition`的factory-bean的属性值

以上代码就是对`BeanDefinition`对象的一个属性填充.



## 2.5 parseMetaElements

```java
// BeanDefinitionParserDelegate
public void parseMetaElements(Element ele, BeanMetadataAttributeAccessor attributeAccessor) {
		// 解析元数据
		NodeList nl = ele.getChildNodes();
		for (int i = 0; i < nl.getLength(); i++) {
			Node node = nl.item(i);
			// 解析meta标签
			if (isCandidateElement(node) && nodeNameEquals(node, META_ELEMENT)) {
				Element metaElement = (Element) node;
				String key = metaElement.getAttribute(KEY_ATTRIBUTE);
				String value = metaElement.getAttribute(VALUE_ATTRIBUTE);
				// 使用kv方式创建对象
				BeanMetadataAttribute attribute = new BeanMetadataAttribute(key, value);
				attribute.setSource(extractSource(metaElement));
				// 记录属性
				attributeAccessor.addMetadataAttribute(attribute);
			}
		}
	}

```

	1. 遍历所有节点
 	2. 解析meta标签
 	3. 设置值到attributeAccessor中



## 2.6 parseLookupOverrideSubElements

```java
	// BeanDefinitionParserDelegate
public void parseLookupOverrideSubElements(Element beanEle, MethodOverrides overrides) {
		// 获取所有子节点
		NodeList nl = beanEle.getChildNodes();
		for (int i = 0; i < nl.getLength(); i++) {
			// 遍历子节点
			Node node = nl.item(i);
			// 判断是lookup-method 节点
			if (isCandidateElement(node) && nodeNameEquals(node, LOOKUP_METHOD_ELEMENT)) {
				Element ele = (Element) node;
				// 获取name属性 方法名
				String methodName = ele.getAttribute(NAME_ATTRIBUTE);
				// 获取bean属性 用于替代的bean名称,用于引用bean对象
				String beanRef = ele.getAttribute(BEAN_ELEMENT);
				// 创建LookupOverride 对象
				LookupOverride override = new LookupOverride(methodName, beanRef);
				override.setSource(extractSource(ele));
				// 添加到overrides对象中的集合中
				overrides.addOverride(override);
			}
		}
	}
```

1. 遍历所有节点
2. 获取name属性
3. 获取bean属性
4. 创建`LookupOverride`对象
5. 添加到`MethodOverrides`中

​	`lookup-method`这个东西,相当于是替换一个方法,与`replaced-method`这个有些许不同.在后面处理bean的时候还会再次出现.



## 2.7 parseReplacedMethodSubElements

```java
// BeanDefinitionParserDelegate
public void parseReplacedMethodSubElements(Element beanEle, MethodOverrides overrides) {
		// 获取所有节点
		NodeList nl = beanEle.getChildNodes();
		for (int i = 0; i < nl.getLength(); i++) {
			// 遍历所有节点
			Node node = nl.item(i);
			// 判断是replaced-method 节点
			if (isCandidateElement(node) && nodeNameEquals(node, REPLACED_METHOD_ELEMENT)) {
				Element replacedMethodEle = (Element) node;
				// 获取name属性
				String name = replacedMethodEle.getAttribute(NAME_ATTRIBUTE);
				// 获取replacer 属性
				String callback = replacedMethodEle.getAttribute(REPLACER_ATTRIBUTE);
				// 创建ReplaceOverride 对象
				ReplaceOverride replaceOverride = new ReplaceOverride(name, callback);
				// Look for arg-type match elements.
				// 获取arg-type 子节点
				List<Element> argTypeEles = DomUtils.getChildElementsByTagName(replacedMethodEle, ARG_TYPE_ELEMENT);
				// 遍历arg-type 节点
				for (Element argTypeEle : argTypeEles) {
					// 获取match 属性
					String match = argTypeEle.getAttribute(ARG_TYPE_MATCH_ATTRIBUTE);
					// 如果match属性为空 说明有子节点循环遍历子节点值,拼装参数
					// 如果match属性不为空 match 值就为本身
					match = (StringUtils.hasText(match) ? match : DomUtils.getTextValue(argTypeEle));
					if (StringUtils.hasText(match)) {
						replaceOverride.addTypeIdentifier(match);
					}
				}
				replaceOverride.setSource(extractSource(replacedMethodEle));
				// 添加到集合
				overrides.addOverride(replaceOverride);
			}
		}
	}

```

​	逻辑与lookup-method处理的差不多.



## 2.8 parseConstructorArgElements

```java
// BeanDefinitionParserDelegate
public void parseConstructorArgElements(Element beanEle, BeanDefinition bd) {
		// 获取所有子节点
		NodeList nl = beanEle.getChildNodes();
		for (int i = 0; i < nl.getLength(); i++) {
			// 遍历子节点
			Node node = nl.item(i);
			// 判断是constructor-arg 节点
			if (isCandidateElement(node) && nodeNameEquals(node, CONSTRUCTOR_ARG_ELEMENT)) {
				parseConstructorArgElement((Element) node, bd);
			}
		}
	}

```

1. 遍历所有节点
2. 查找节点`constructor-arg`
3. 解析参数

解析参数的逻辑单独在一个方法中`parseConstructorArgElement`。

```java
// BeanDefinitionParserDelegate
public void parseConstructorArgElement(Element ele, BeanDefinition bd) {
		// 提取 index 属性
		String indexAttr = ele.getAttribute(INDEX_ATTRIBUTE);
		// 提取 type 属性
		String typeAttr = ele.getAttribute(TYPE_ATTRIBUTE);
		// 提取 name 属性
		String nameAttr = ele.getAttribute(NAME_ATTRIBUTE);
		// 处理 index 属性逻辑
		if (StringUtils.hasLength(indexAttr)) {
			try {
				// 下标转换为 int
				int index = Integer.parseInt(indexAttr);
				// 下标不允许小于0
				if (index < 0) {
					error("'index' cannot be lower than 0", ele);
				}
				else {
					try {
						this.parseState.push(new ConstructorArgumentEntry(index));
						// 解析 properties 属性
						Object value = parsePropertyValue(ele, bd, null);
						ConstructorArgumentValues.ValueHolder valueHolder = new ConstructorArgumentValues.ValueHolder(value);
						// 设置 typeAttr 属性值
						if (StringUtils.hasLength(typeAttr)) {
							valueHolder.setType(typeAttr);
						}
						// 设置 name 属性值
						if (StringUtils.hasLength(nameAttr)) {
							valueHolder.setName(nameAttr);
						}
						valueHolder.setSource(extractSource(ele));
						// 判断下标是否重复
						if (bd.getConstructorArgumentValues().hasIndexedArgumentValue(index)) {
							error("Ambiguous constructor-arg entries for index " + index, ele);
						}
						else {
							// 添加 下标 参数
							bd.getConstructorArgumentValues().addIndexedArgumentValue(index, valueHolder);
						}
					}
					finally {
						this.parseState.pop();
					}
				}
			}
			catch (NumberFormatException ex) {
				error("Attribute 'index' of tag 'constructor-arg' must be an integer", ele);
			}
		}
		else {
			// 不包含 index 属性处理逻辑
			try {
				this.parseState.push(new ConstructorArgumentEntry());
				Object value = parsePropertyValue(ele, bd, null);
				ConstructorArgumentValues.ValueHolder valueHolder = new ConstructorArgumentValues.ValueHolder(value);
				if (StringUtils.hasLength(typeAttr)) {
					valueHolder.setType(typeAttr);
				}
				if (StringUtils.hasLength(nameAttr)) {
					valueHolder.setName(nameAttr);
				}
				valueHolder.setSource(extractSource(ele));
				bd.getConstructorArgumentValues().addGenericArgumentValue(valueHolder);
			}
			finally {
				this.parseState.pop();
			}
		}
	}
```

通过判断是否有index属性来进行解析配置文件.解析参数的代码为`parsePropertyValue(ele, bd, null);`

```java
// BeanDefinitionParserDelegate
@Nullable
	public Object parsePropertyValue(Element ele, BeanDefinition bd, @Nullable String propertyName) {
		String elementName = (propertyName != null ?
				"<property> element for property '" + propertyName + "'" :
				"<constructor-arg> element");

		// Should only have one child element: ref, value, list, etc.
		// 获取所有子节点
		NodeList nl = ele.getChildNodes();
		Element subElement = null;
		// 遍历所有子节点
		for (int i = 0; i < nl.getLength(); i++) {
			Node node = nl.item(i);
			// description 节点 和 meta节点 不处理
			if (node instanceof Element && !nodeNameEquals(node, DESCRIPTION_ELEMENT) &&
					!nodeNameEquals(node, META_ELEMENT)) {
				// Child element is what we're looking for.
				if (subElement != null) {
					error(elementName + " must not contain more than one sub-element", ele);
				}
				else {
					subElement = (Element) node;
				}
			}
		}
		// 判断是够包含 ref 属性
		boolean hasRefAttribute = ele.hasAttribute(REF_ATTRIBUTE);
		// 判断是否包含 value 属性
		boolean hasValueAttribute = ele.hasAttribute(VALUE_ATTRIBUTE);
		// 如果 [[同时包含 ref 属性 和 value 属性] 或者 [[包含 ref 属性 或者 value属性 之一] 并且 subElement 不为空]]
		// 则 抛出异常
		if ((hasRefAttribute && hasValueAttribute) ||
				((hasRefAttribute || hasValueAttribute) && subElement != null)) {
			error(elementName +
					" is only allowed to contain either 'ref' attribute OR 'value' attribute OR sub-element", ele);
		}
		// 处理只包含 ref 属性逻辑
		if (hasRefAttribute) {
			// 获取 ref 属性值
			String refName = ele.getAttribute(REF_ATTRIBUTE);
			// 如果 ref 属性值为空 error
			if (!StringUtils.hasText(refName)) {
				error(elementName + " contains empty 'ref' attribute", ele);
			}
			// 创建 RuntimeBeanReference 对象
			RuntimeBeanReference ref = new RuntimeBeanReference(refName);
			ref.setSource(extractSource(ele));
			return ref;
		}
		// 处理值包含 value 属性逻辑
		else if (hasValueAttribute) {
			// 创建 TypedStringValue 对象
			TypedStringValue valueHolder = new TypedStringValue(ele.getAttribute(VALUE_ATTRIBUTE));
			valueHolder.setSource(extractSource(ele));
			return valueHolder;
		}
		// 处理只有子元素逻辑
		else if (subElement != null) {
			return parsePropertySubElement(subElement, bd);
		}
		// error
		else {
			// Neither child element nor "ref" or "value" attribute found.
			error(elementName + " must specify a ref or value", ele);
			return null;
		}
	}
```

1. 遍历所有节点
2. description 和 meta 节点不处理,跳过.
3. 判断是否包含 ref 属性
4. 判断是否包含 value 属性
5. 处理 ref
6. 处理 value
7. 处理子元素

​	处理逻辑不复杂,复杂点的可能是在处理子元素的实时,相对复杂点.通常子元素的处理就是把值转换为 Map\List\Set等数据结构.处理子元素的方法是`parsePropertySubElement`.

```java
// BeanDefinitionParserDelegate
@Nullable
	public Object parsePropertySubElement(Element ele, @Nullable BeanDefinition bd) {
		return parsePropertySubElement(ele, bd, null);
	}

	/**
	 * Parse a value, ref or collection sub-element of a property or
	 * constructor-arg element.
	 * @param ele subelement of property element; we don't know which yet
	 * @param bd the current bean definition (if any)
	 * @param defaultValueType the default type (class name) for any
	 * {@code <value>} tag that might be created
	 */
	@Nullable
	public Object parsePropertySubElement(Element ele, @Nullable BeanDefinition bd, @Nullable String defaultValueType) {
		// 处理非默认名称空间
		if (!isDefaultNamespace(ele)) {
			return parseNestedCustomElement(ele, bd);
		}
		// 处理 bean
		else if (nodeNameEquals(ele, BEAN_ELEMENT)) {
			BeanDefinitionHolder nestedBd = parseBeanDefinitionElement(ele, bd);
			if (nestedBd != null) {
				nestedBd = decorateBeanDefinitionIfRequired(ele, nestedBd, bd);
			}
			return nestedBd;
		}
		// 处理 ref
		else if (nodeNameEquals(ele, REF_ELEMENT)) {
			// A generic reference to any name of any bean.
			// 获取 需要引用的 bean 名称
			String refName = ele.getAttribute(BEAN_REF_ATTRIBUTE);
			boolean toParent = false;
			// 如果 需要引用的bean 名称为空
			if (!StringUtils.hasLength(refName)) {
				// A reference to the id of another bean in a parent context.
				// 获取 需要引用的parent 属性
				refName = ele.getAttribute(PARENT_REF_ATTRIBUTE);
				toParent = true;
				// 如果 bean 为空 并且 parent 属性都为空 则 error
				if (!StringUtils.hasLength(refName)) {
					error("'bean' or 'parent' is required for <ref> element", ele);
					return null;
				}
			}
			// 如果需要引用的 bean 名称 依然为空 则 error
			if (!StringUtils.hasText(refName)) {
				error("<ref> element contains empty target attribute", ele);
				return null;
			}
			// 创建 RuntimeBeanReference 对象
			RuntimeBeanReference ref = new RuntimeBeanReference(refName, toParent);
			ref.setSource(extractSource(ele));
			return ref;
		}
		// 处理 idref
		else if (nodeNameEquals(ele, IDREF_ELEMENT)) {
			return parseIdRefElement(ele);
		}
		// 处理 value
		else if (nodeNameEquals(ele, VALUE_ELEMENT)) {
			return parseValueElement(ele, defaultValueType);
		}
		// 处理 null
		else if (nodeNameEquals(ele, NULL_ELEMENT)) {
			// It's a distinguished null value. Let's wrap it in a TypedStringValue
			// object in order to preserve the source location.
			// 创建 TypedStringValue 对象
			TypedStringValue nullHolder = new TypedStringValue(null);
			nullHolder.setSource(extractSource(ele));
			return nullHolder;
		}
		// 处理 array
		else if (nodeNameEquals(ele, ARRAY_ELEMENT)) {
			return parseArrayElement(ele, bd);
		}
		// 处理 list
		else if (nodeNameEquals(ele, LIST_ELEMENT)) {
			return parseListElement(ele, bd);
		}
		// 处理 set
		else if (nodeNameEquals(ele, SET_ELEMENT)) {
			return parseSetElement(ele, bd);
		}
		// 处理 map
		else if (nodeNameEquals(ele, MAP_ELEMENT)) {
			return parseMapElement(ele, bd);
		}
		// 处理 props
		else if (nodeNameEquals(ele, PROPS_ELEMENT)) {
			return parsePropsElement(ele);
		}
		// error
		else {
			error("Unknown property sub-element: [" + ele.getNodeName() + "]", ele);
			return null;
		}
	}
```

​	开头就是一个判断,判断是否是默认名称空间,如果非默认名称空间采用自定义解析逻辑.



### 2.8.1 自定义解析

​	创建自定义xsd

```xml
<?xml version="1.0" encoding="UTF-8"?>
<xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema"
			xmlns="https://onew.me/schema/adv"
			targetNamespace="https://onew.me/schema/adv" elementFormDefault="qualified">
	<xsd:element name="AdvProp">
		<xsd:complexType>
			<xsd:attribute name="name" type="xsd:string" />
			<xsd:attribute name="age" type="xsd:string" />
		</xsd:complexType>
	</xsd:element>

</xsd:schema>
```

​	创建类

```java
package com.sjr.test.bean;

public class AdvProp {

	private String name;

	private String age;

	public String getName() {
		return name;
	}

	public AdvProp setName(String name) {
		this.name = name;
		return this;
	}

	public String getAge() {
		return age;
	}

	public AdvProp setAge(String age) {
		this.age = age;
		return this;
	}
}

```

​	修改测试类

```java
package com.sjr.test.bean;

public class MyTestBean {

	private AdvProp advProp;

	private String testStr = "test--one";

	public MyTestBean(AdvProp advProp) {
		this.advProp = advProp;
	}

	public MyTestBean() {
	}

	public String getTestStr() {
		return testStr;
	}

	public MyTestBean setTestStr(String testStr) {
		this.testStr = testStr;
		return this;
	}

	public AdvProp getAdvProp() {
		return advProp;
	}

	public MyTestBean setAdvProp(AdvProp advProp) {
		this.advProp = advProp;
		return this;
	}

	public void printAdvProp(){
		System.out.println("advProp: age-" + advProp.getAge() + ",name-" + advProp.getName());
	}
}

```

​	创建自定义解析类

```java
public class TestAdvPropParser extends AbstractSingleBeanDefinitionParser {

	@Override
	protected Class<?> getBeanClass(Element element) {
		return AdvProp.class;
	}

	@Override
	protected void doParse(Element element, BeanDefinitionBuilder builder) {
		final String name = element.getAttribute("name");
		final String age = element.getAttribute("age");
		builder.addPropertyValue("name",name);
		builder.addPropertyValue("age",age);
	}
}

```

​	创建自定义NamespaceHandler类

```java
public class TestNamespaceHandler extends NamespaceHandlerSupport {

	@Override
	public void init() {
		registerBeanDefinitionParser("AdvProp",new TestAdvPropParser());
	}
}

```

​	配置spring.handlers

```properties
https\://onew.me/schema/adv=com.sjr.test.handler.TestNamespaceHandler
```

​	配置spring.schemas

```properties
https\://onew.me/schema/adv/AdvProp.xsd=com/sjr/test/bean/AdvProp.xsd
```

​	配置xml

```xml
<?xml version="1.0" encoding="ISO-8859-1"?>
<beans xmlns="http://www.springframework.org/schema/beans"
	   xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
	   xmlns:adv="https://onew.me/schema/adv"
	   xsi:schemaLocation="http://www.springframework.org/schema/beans
                       https://www.springframework.org/schema/beans/spring-beans-3.0.xsd
                       https://onew.me/schema/adv https://onew.me/schema/adv/AdvProp.xsd
">
	<bean id="myTestBean" class="com.sjr.test.bean.MyTestBean">
		<constructor-arg>
			<adv:AdvProp  name="testAdv" age="31"/>
		</constructor-arg>
	</bean>
</beans>

```

​	修改测试代码

```java
@Test
	public void testSpringAdvParseTag(){
		BeanFactory factory = new XmlBeanFactory(new ClassPathResource("com/sjr/test/bean/AdvTestBean.xml"));
		final MyTestBean testBean = factory.getBean("myTestBean",MyTestBean.class);
		testBean.printAdvProp();
	}
```

​	运行结果

```properties
advProp: age-31,name-testAdv
```



1. `TestNamespaceHandler`用于注册自定义解析器
2. `TestAdvPropParser`用于解析自定义标签
3. `spring.schemas`用于描述xsd文件路径
4. `spring.handlers`用于指定自定义名称空间使用指定的handler



### 2.8.2 解析bean标签

​	解析逻辑与bean标签逻辑一致

```java
// BeanDefinitionParserDelegate	
// 处理 bean
		else if (nodeNameEquals(ele, BEAN_ELEMENT)) {
			BeanDefinitionHolder nestedBd = parseBeanDefinitionElement(ele, bd);
			if (nestedBd != null) {
				nestedBd = decorateBeanDefinitionIfRequired(ele, nestedBd, bd);
			}
			return nestedBd;
		}
```

### 2.8.3 解析ref标签

```java
// BeanDefinitionParserDelegate
if (nodeNameEquals(ele, REF_ELEMENT)) {
			// A generic reference to any name of any bean.
			// 获取 需要引用的 bean 名称
			String refName = ele.getAttribute(BEAN_REF_ATTRIBUTE);
			boolean toParent = false;
			// 如果 需要引用的bean 名称为空
			if (!StringUtils.hasLength(refName)) {
				// A reference to the id of another bean in a parent context.
				// 获取 需要引用的parent 属性
				refName = ele.getAttribute(PARENT_REF_ATTRIBUTE);
				toParent = true;
				// 如果 bean 为空 并且 parent 属性都为空 则 error
				if (!StringUtils.hasLength(refName)) {
					error("'bean' or 'parent' is required for <ref> element", ele);
					return null;
				}
			}
			// 如果需要引用的 bean 名称 依然为空 则 error
			if (!StringUtils.hasText(refName)) {
				error("<ref> element contains empty target attribute", ele);
				return null;
			}
			// 创建 RuntimeBeanReference 对象
			RuntimeBeanReference ref = new RuntimeBeanReference(refName, toParent);
			ref.setSource(extractSource(ele));
			return ref;
		}
```

### 2.8.4 解析idref标签

```java
	// BeanDefinitionParserDelegate
	@Nullable
	public Object parseIdRefElement(Element ele) {
		// A generic reference to any name of any bean.
		// 获取需要引用的 bean 属性
		String refName = ele.getAttribute(BEAN_REF_ATTRIBUTE);
		// 引用的名称为空 则 error
		if (!StringUtils.hasLength(refName)) {
			error("'bean' is required for <idref> element", ele);
			return null;
		}
		// 引用的名称为空 则 error
		if (!StringUtils.hasText(refName)) {
			error("<idref> element contains empty target attribute", ele);
			return null;
		}
		// 创建 RuntimeBeanNameReference
		RuntimeBeanNameReference ref = new RuntimeBeanNameReference(refName);
		ref.setSource(extractSource(ele));
		return ref;
	}
```

### 2.8.5 解析value标签

```java
	// BeanDefinitionParserDelegate
	public Object parseValueElement(Element ele, @Nullable String defaultTypeName) {
		// It's a literal value.
		// 获取文本值
		String value = DomUtils.getTextValue(ele);
		// 获取 type 属性
		String specifiedTypeName = ele.getAttribute(TYPE_ATTRIBUTE);
		String typeName = specifiedTypeName;
		// 如果 type 属性为空 则 设置为默认的 type
		if (!StringUtils.hasText(typeName)) {
			// 默认为 null
			typeName = defaultTypeName;
		}
		try {
			// 创建 TypedStringValue 对象
			TypedStringValue typedValue = buildTypedStringValue(value, typeName);
			typedValue.setSource(extractSource(ele));
			typedValue.setSpecifiedTypeName(specifiedTypeName);
			return typedValue;
		}
		catch (ClassNotFoundException ex) {
			error("Type class [" + typeName + "] not found for <value> element", ele, ex);
			return value;
		}
	}

```

### 2.8.6 解析array 标签

```java
	// BeanDefinitionParserDelegate
public Object parseArrayElement(Element arrayEle, @Nullable BeanDefinition bd) {
		// 获取 value-type 属性
		String elementType = arrayEle.getAttribute(VALUE_TYPE_ATTRIBUTE);
		// 获取所有子节点
		NodeList nl = arrayEle.getChildNodes();
		// 创建 ManagedArray 对象
		ManagedArray target = new ManagedArray(elementType, nl.getLength());
		target.setSource(extractSource(arrayEle));
		target.setElementTypeName(elementType);
		target.setMergeEnabled(parseMergeAttribute(arrayEle));
		parseCollectionElements(nl, target, bd, elementType);
		return target;
	}
```

### 2.8.7 解析list标签

```java
	// BeanDefinitionParserDelegate
public List<Object> parseListElement(Element collectionEle, @Nullable BeanDefinition bd) {
		// 获取 value-type 属性
		String defaultElementType = collectionEle.getAttribute(VALUE_TYPE_ATTRIBUTE);
		// 获取所有子节点
		NodeList nl = collectionEle.getChildNodes();
		// 创建 ManagedList 对象
		ManagedList<Object> target = new ManagedList<>(nl.getLength());
		target.setSource(extractSource(collectionEle));
		target.setElementTypeName(defaultElementType);
		target.setMergeEnabled(parseMergeAttribute(collectionEle));
		parseCollectionElements(nl, target, bd, defaultElementType);
		return target;
	}
```

### 2.8.8 解析set标签

```java
	// BeanDefinitionParserDelegate
public Set<Object> parseSetElement(Element collectionEle, @Nullable BeanDefinition bd) {
		// 获取 value-type 属性
		String defaultElementType = collectionEle.getAttribute(VALUE_TYPE_ATTRIBUTE);
		// 获取所有子节点
		NodeList nl = collectionEle.getChildNodes();
		// 创建 ManagedSet 对象
		ManagedSet<Object> target = new ManagedSet<>(nl.getLength());
		target.setSource(extractSource(collectionEle));
		target.setElementTypeName(defaultElementType);
		target.setMergeEnabled(parseMergeAttribute(collectionEle));
		parseCollectionElements(nl, target, bd, defaultElementType);
		return target;
	}
```



### 2.8.9 解析map标签

```java
	// BeanDefinitionParserDelegate
public Map<Object, Object> parseMapElement(Element mapEle, @Nullable BeanDefinition bd) {
		// 获取 key-type 属性值
		String defaultKeyType = mapEle.getAttribute(KEY_TYPE_ATTRIBUTE);
		// 获取 value-type 属性值
		String defaultValueType = mapEle.getAttribute(VALUE_TYPE_ATTRIBUTE);

		// 获取 entry 子节点
		List<Element> entryEles = DomUtils.getChildElementsByTagName(mapEle, ENTRY_ELEMENT);
		// 创建 ManagedMap 对象
		ManagedMap<Object, Object> map = new ManagedMap<>(entryEles.size());
		map.setSource(extractSource(mapEle));
		map.setKeyTypeName(defaultKeyType);
		map.setValueTypeName(defaultValueType);
		map.setMergeEnabled(parseMergeAttribute(mapEle));

		// 遍历 entryEles 集合
		for (Element entryEle : entryEles) {
			// Should only have one value child element: ref, value, list, etc.
			// Optionally, there might be a key child element.
			// 获取子节点
			NodeList entrySubNodes = entryEle.getChildNodes();
			Element keyEle = null;
			Element valueEle = null;
			// 遍历 entrySubNodes
			for (int j = 0; j < entrySubNodes.getLength(); j++) {
				Node node = entrySubNodes.item(j);
				if (node instanceof Element) {
					Element candidateEle = (Element) node;
					// 处理 key 节点逻辑
					if (nodeNameEquals(candidateEle, KEY_ELEMENT)) {
						if (keyEle != null) {
							error("<entry> element is only allowed to contain one <key> sub-element", entryEle);
						}
						else {
							keyEle = candidateEle;
						}
					}
					else {
						// 忽略 description 节点
						// Child element is what we're looking for.
						if (nodeNameEquals(candidateEle, DESCRIPTION_ELEMENT)) {
							// the element is a <description> -> ignore it
						}
						else if (valueEle != null) {
							error("<entry> element must not contain more than one value sub-element", entryEle);
						}
						else {
							valueEle = candidateEle;
						}
					}
				}
			}

			// Extract key from attribute or sub-element.
			Object key = null;
			// 判断是否包含 key 属性
			boolean hasKeyAttribute = entryEle.hasAttribute(KEY_ATTRIBUTE);
			// 判断是否包含 key-ref 属性
			boolean hasKeyRefAttribute = entryEle.hasAttribute(KEY_REF_ATTRIBUTE);
			// 如果 [[包含 key 属性 并且 包含 key-ref 属性] 或者 [[包含 key 属性 或 包含 key-ref 之一]] 并且 keyEle 不为空]
			// 则 报错
			if ((hasKeyAttribute && hasKeyRefAttribute) ||
					(hasKeyAttribute || hasKeyRefAttribute) && keyEle != null) {
				error("<entry> element is only allowed to contain either " +
						"a 'key' attribute OR a 'key-ref' attribute OR a <key> sub-element", entryEle);
			}
			// 处理 key 属性
			if (hasKeyAttribute) {
				key = buildTypedStringValueForMap(entryEle.getAttribute(KEY_ATTRIBUTE), defaultKeyType, entryEle);
			}
			// 处理 key-ref 属性
			else if (hasKeyRefAttribute) {
				String refName = entryEle.getAttribute(KEY_REF_ATTRIBUTE);
				if (!StringUtils.hasText(refName)) {
					error("<entry> element contains empty 'key-ref' attribute", entryEle);
				}
				RuntimeBeanReference ref = new RuntimeBeanReference(refName);
				ref.setSource(extractSource(entryEle));
				key = ref;
			}
			else if (keyEle != null) {
				key = parseKeyElement(keyEle, bd, defaultKeyType);
			}
			else {
				error("<entry> element must specify a key", entryEle);
			}

			// Extract value from attribute or sub-element.
			Object value = null;
			// 判断 是否包含 value 属性
			boolean hasValueAttribute = entryEle.hasAttribute(VALUE_ATTRIBUTE);
			// 判断 是否包含 value-ref 属性
			boolean hasValueRefAttribute = entryEle.hasAttribute(VALUE_REF_ATTRIBUTE);
			// 判断 是否包含 value-type 属性
			boolean hasValueTypeAttribute = entryEle.hasAttribute(VALUE_TYPE_ATTRIBUTE);
			if ((hasValueAttribute && hasValueRefAttribute) ||
					(hasValueAttribute || hasValueRefAttribute) && valueEle != null) {
				error("<entry> element is only allowed to contain either " +
						"'value' attribute OR 'value-ref' attribute OR <value> sub-element", entryEle);
			}
			if ((hasValueTypeAttribute && hasValueRefAttribute) ||
				(hasValueTypeAttribute && !hasValueAttribute) ||
					(hasValueTypeAttribute && valueEle != null)) {
				error("<entry> element is only allowed to contain a 'value-type' " +
						"attribute when it has a 'value' attribute", entryEle);
			}
			// 处理 value 属性
			if (hasValueAttribute) {
				String valueType = entryEle.getAttribute(VALUE_TYPE_ATTRIBUTE);
				if (!StringUtils.hasText(valueType)) {
					valueType = defaultValueType;
				}
				value = buildTypedStringValueForMap(entryEle.getAttribute(VALUE_ATTRIBUTE), valueType, entryEle);
			}
			// 处理 value-ref 属性
			else if (hasValueRefAttribute) {
				String refName = entryEle.getAttribute(VALUE_REF_ATTRIBUTE);
				if (!StringUtils.hasText(refName)) {
					error("<entry> element contains empty 'value-ref' attribute", entryEle);
				}
				RuntimeBeanReference ref = new RuntimeBeanReference(refName);
				ref.setSource(extractSource(entryEle));
				value = ref;
			}
			// 处理 valueEle
			else if (valueEle != null) {
				value = parsePropertySubElement(valueEle, bd, defaultValueType);
			}
			else {
				error("<entry> element must specify a value", entryEle);
			}

			// Add final key and value to the Map.
			// 添加最终的 key 和 value 到 map 中去
			map.put(key, value);
		}

		return map;
	}
```

转换为map的时候逻辑稍微有点复杂,慢慢看,还是能看懂.

### 2.8.10 解析props标签

```java
	// BeanDefinitionParserDelegate
public Properties parsePropsElement(Element propsEle) {
		// 创建 ManagedProperties 对象
		ManagedProperties props = new ManagedProperties();
		props.setSource(extractSource(propsEle));
		props.setMergeEnabled(parseMergeAttribute(propsEle));

		//获取节点下面素有 prop 节点
		List<Element> propEles = DomUtils.getChildElementsByTagName(propsEle, PROP_ELEMENT);
		// 遍历 prop 节点
		for (Element propEle : propEles) {
			// 获取 key
			String key = propEle.getAttribute(KEY_ATTRIBUTE);
			// Trim the text value to avoid unwanted whitespace
			// caused by typical XML formatting.
			// 获取 值
			String value = DomUtils.getTextValue(propEle).trim();
			TypedStringValue keyHolder = new TypedStringValue(key);
			keyHolder.setSource(extractSource(propEle));
			TypedStringValue valueHolder = new TypedStringValue(value);
			valueHolder.setSource(extractSource(propEle));
			// 放入到 props 对象中
			props.put(keyHolder, valueHolder);
		}

		return props;
	}
```



## 2.9 parsePropertyElements

```java
	// BeanDefinitionParserDelegate	
 public void parsePropertyElements(Element beanEle, BeanDefinition bd) {
		// 获取所有子节点
		NodeList nl = beanEle.getChildNodes();
		for (int i = 0; i < nl.getLength(); i++) {
			// 遍历 所有节点
			Node node = nl.item(i);
			if (isCandidateElement(node) && nodeNameEquals(node, PROPERTY_ELEMENT)) {
				parsePropertyElement((Element) node, bd);
			}
		}
	}
	
	public void parsePropertyElement(Element ele, BeanDefinition bd) {
		// 获取 name 属性
		String propertyName = ele.getAttribute(NAME_ATTRIBUTE);
		// name 属性为空 则报错
		if (!StringUtils.hasLength(propertyName)) {
			error("Tag 'property' must have a 'name' attribute", ele);
			return;
		}
		this.parseState.push(new PropertyEntry(propertyName));
		try {
			// 属性名相同则报错
			if (bd.getPropertyValues().contains(propertyName)) {
				error("Multiple 'property' definitions for property '" + propertyName + "'", ele);
				return;
			}
			Object val = parsePropertyValue(ele, bd, propertyName);
			PropertyValue pv = new PropertyValue(propertyName, val);
			parseMetaElements(ele, pv);
			pv.setSource(extractSource(ele));
			bd.getPropertyValues().addPropertyValue(pv);
		}
		finally {
			this.parseState.pop();
		}
	}
```

1. 遍历所有节点
2. 使用`parsePropertyValue`方法处理值(该方法已经写到过)
3. 把解析到的值放入`BeanDefinition`中去



## 2.10 parseQualifierElements

```java
	// BeanDefinitionParserDelegate
public void parseQualifierElements(Element beanEle, AbstractBeanDefinition bd) {
		// 获取所有子节点
		NodeList nl = beanEle.getChildNodes();
		for (int i = 0; i < nl.getLength(); i++) {
			// 遍历所有子节点
			Node node = nl.item(i);
			// 处理 qualifier 节点
			if (isCandidateElement(node) && nodeNameEquals(node, QUALIFIER_ELEMENT)) {
				parseQualifierElement((Element) node, bd);
			}
		}
	}
	
```

1. 遍历所有节点
2. 通过`parseQualifierElement`方法处理

```java
// BeanDefinitionParserDelegate
public void parseQualifierElement(Element ele, AbstractBeanDefinition bd) {
		// 获取 type 属性
		String typeName = ele.getAttribute(TYPE_ATTRIBUTE);
		// 如果 type 属性为空 则 error
		if (!StringUtils.hasLength(typeName)) {
			error("Tag 'qualifier' must have a 'type' attribute", ele);
			return;
		}
		this.parseState.push(new QualifierEntry(typeName));
		try {
			// 创建 AutowireCandidateQualifier 对象
			AutowireCandidateQualifier qualifier = new AutowireCandidateQualifier(typeName);
			qualifier.setSource(extractSource(ele));
			// 获取 value 属性
			String value = ele.getAttribute(VALUE_ATTRIBUTE);
			if (StringUtils.hasLength(value)) {
				qualifier.setAttribute(AutowireCandidateQualifier.VALUE_KEY, value);
			}
			// 获取当前节点下的所有节点
			NodeList nl = ele.getChildNodes();
			for (int i = 0; i < nl.getLength(); i++) {
				// 遍历所有子节点
				Node node = nl.item(i);
				// 处理 attribute 属性
				if (isCandidateElement(node) && nodeNameEquals(node, QUALIFIER_ATTRIBUTE_ELEMENT)) {
					Element attributeEle = (Element) node;
					// 获取 key 属性
					String attributeName = attributeEle.getAttribute(KEY_ATTRIBUTE);
					// 获取 value 属性
					String attributeValue = attributeEle.getAttribute(VALUE_ATTRIBUTE);
					// key and value is not null
					if (StringUtils.hasLength(attributeName) && StringUtils.hasLength(attributeValue)) {
						BeanMetadataAttribute attribute = new BeanMetadataAttribute(attributeName, attributeValue);
						attribute.setSource(extractSource(attributeEle));
						qualifier.addMetadataAttribute(attribute);
					}
					else {
						error("Qualifier 'attribute' tag must have a 'name' and 'value'", attributeEle);
						return;
					}
				}
			}
			bd.addQualifier(qualifier);
		}
		finally {
			this.parseState.pop();
		}
	}
```

1. 遍历所有节点
2. 把获取到的kv全部放入到`AutowireCandidateQualifier`对象中去
3. `BeanDefinition`对象设置`qualifier`属性



# 三、小结

​	至此已经创建一了一个完整的`AbstractBeanDefinition`对象,一个对bean信息的描述对象有了,会转为`BeanDefinitionHolder`为后续操作作为基础.
