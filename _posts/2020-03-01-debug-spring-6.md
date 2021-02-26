---
title: "[断点分析之spring-ioc]-BeanDefinitionHolder装饰(六)"
date: 2020/03/01 14:20:25
tags:
- spring
- java
categories: spring
cover: https://gitee.com/oneww/onew_image/raw/master/spring_cover.png
author: 
  nick: onew
  link: https://onew.me
subtitle: spring BeanDefinitionHolder装饰
---



# 一、前言

​	在xml标签解析完之后会产生一个`BeanDefinitionHolder`对象,紧接着就来谈谈,`spring`用这个对象来干嘛吧.

```java
//DefaultBeanDefinitionDocumentReader.java
protected void processBeanDefinition(Element ele, BeanDefinitionParserDelegate delegate) {
		// 解析xml元素 
		BeanDefinitionHolder bdHolder = delegate.parseBeanDefinitionElement(ele);
		if (bdHolder != null) {
			// 装饰
			bdHolder = delegate.decorateBeanDefinitionIfRequired(ele, bdHolder);
			try {
				// Register the final decorated instance.
				// 注册到容器中
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

​	解析xml这边已经记录过了,接下来的重点在于`delegate.decorateBeanDefinitionIfRequired(ele, bdHolder);`,从方法名可以看出意思大概为:如果有必要就进行装饰.说到装饰感觉跟装饰模式有关.



# 二、分析

```java
public BeanDefinitionHolder decorateBeanDefinitionIfRequired(Element ele, BeanDefinitionHolder originalDef) {
		return decorateBeanDefinitionIfRequired(ele, originalDef, null);
	}

	/**
	 * Decorate the given bean definition through a namespace handler, if applicable.
	 * @param ele the current element
	 * @param originalDef the current bean definition
	 * @param containingBd the containing bean definition (if any)
	 * @return the decorated bean definition
	 */
	public BeanDefinitionHolder decorateBeanDefinitionIfRequired(
			Element ele, BeanDefinitionHolder originalDef, @Nullable BeanDefinition containingBd) {

		BeanDefinitionHolder finalDefinition = originalDef;
		// 遍历节点,寻找可以装饰的属性
		// Decorate based on custom attributes first.
		NamedNodeMap attributes = ele.getAttributes();
		for (int i = 0; i < attributes.getLength(); i++) {
			Node node = attributes.item(i);
			finalDefinition = decorateIfRequired(node, finalDefinition, containingBd);
		}
		// 遍历子节点,寻找可以装饰的子节点
		// Decorate based on custom nested elements.
		NodeList children = ele.getChildNodes();
		for (int i = 0; i < children.getLength(); i++) {
			Node node = children.item(i);
			if (node.getNodeType() == Node.ELEMENT_NODE) {
				finalDefinition = decorateIfRequired(node, finalDefinition, containingBd);
			}
		}
		return finalDefinition;
	}
```

1. 遍历当前节点的所有属性进行装饰
2. 遍历当前节点的所有子节点进行装饰
3. 返回`BeanDefinitionHolder`



​	从上面可以看到核心方法在于`decorateIfRequired`,进去看一看.

## 2.1 decorateIfRequired

```java
public BeanDefinitionHolder decorateIfRequired(
			Node node, BeanDefinitionHolder originalDef, @Nullable BeanDefinition containingBd) {
		// 获取名称空间URI
		String namespaceUri = getNamespaceURI(node);
		// 判断是否是自定义名称空间,只对自定义名称空间进行处理
		if (namespaceUri != null && !isDefaultNamespace(namespaceUri)) {
			// 获取名称空间对应的处理器
			NamespaceHandler handler = this.readerContext.getNamespaceHandlerResolver().resolve(namespaceUri);
			if (handler != null) {
				// 进行装饰处理
				BeanDefinitionHolder decorated =
						handler.decorate(node, originalDef, new ParserContext(this.readerContext, this, containingBd));
				if (decorated != null) {
					return decorated;
				}
			}
			else if (namespaceUri.startsWith("http://www.springframework.org/schema/")) {
				error("Unable to locate Spring NamespaceHandler for XML schema namespace [" + namespaceUri + "]", node);
			}
			else {
				// A custom namespace, not to be handled by Spring - maybe "xml:...".
				if (logger.isDebugEnabled()) {
					logger.debug("No Spring NamespaceHandler found for XML schema namespace [" + namespaceUri + "]");
				}
			}
		}
		return originalDef;
	}
```

1. 判断是否是默认名称命名空间
2. 非默认进行装饰处理



​	那么这个装饰是个什么鬼呢？通过判断是否是默认名称空间这个条件感觉在前面分析的时候遇到过.从这个条件可以看出这个逻辑与最后达到的效果与前面自定义标签是一回事.可以看看官方给出的例子.

- 用于测试的xml

```xml
<?xml version="1.0" encoding="UTF-8"?>
<beans xmlns="http://www.springframework.org/schema/beans"
	   xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
	   xmlns:test="http://www.springframework.org/schema/beans/test"
	   xmlns:util="http://www.springframework.org/schema/util"
	   xsi:schemaLocation="http://www.springframework.org/schema/beans https://www.springframework.org/schema/beans/spring-beans-2.0.xsd
       http://www.springframework.org/schema/util https://www.springframework.org/schema/util/spring-util-2.0.xsd
       http://www.springframework.org/schema/beans/test https://www.springframework.org/schema/beans/factory/xml/support/CustomNamespaceHandlerTests.xsd"
	default-lazy-init="true">

	<test:testBean id="testBean" name="Rob Harrop" age="23"/>

	<bean id="customisedTestBean" class="org.springframework.tests.sample.beans.TestBean">
		<test:set name="Rob Harrop" age="23"/>
	</bean>

	<bean id="debuggingTestBean" class="org.springframework.tests.sample.beans.TestBean">
		<test:debug/>
		<property name="name" value="Rob Harrop"/>
		<property name="age" value="23"/>
	</bean>

	<bean id="debuggingTestBeanNoInstance" class="org.springframework.context.ApplicationListener">
		<test:debug/>
	</bean>

	<bean id="chainedTestBean" class="org.springframework.tests.sample.beans.TestBean">
		<test:debug/>
		<test:nop/>
		<property name="name" value="Rob Harrop"/>
		<property name="age" value="23"/>
	</bean>

	<bean id="decorateWithAttribute" class="org.springframework.tests.sample.beans.TestBean" test:object-name="foo"/>

	<util:list id="list.of.things">
		<test:person name="Fiona Apple" age="20"/>
		<test:person name="Harriet Wheeler" age="30"/>
	</util:list>

	<util:set id="set.of.things">
		<test:person name="Fiona Apple" age="20"/>
		<test:person name="Harriet Wheeler" age="30"/>
	</util:set>

	<util:map id="map.of.things">
		<entry key="fiona.apple">
			<test:person name="Fiona Apple" age="20"/>
		</entry>
		<entry key="harriet.wheeler">
			<test:person name="Harriet Wheeler" age="30"/>
		</entry>
	</util:map>

</beans>


```

- 用于测试的xsd文件

```xml
<?xml version="1.0" encoding="UTF-8" standalone="no"?>

<xsd:schema xmlns="http://www.springframework.org/schema/beans/test"
			xmlns:xsd="http://www.w3.org/2001/XMLSchema"
			targetNamespace="http://www.springframework.org/schema/beans/test"
			elementFormDefault="qualified">
	
	<xsd:element name="person">
		<xsd:complexType>
			<xsd:attribute name="id" type="xsd:string" use="optional" form="unqualified"/>
			<xsd:attribute name="name" type="xsd:string" use="required" form="unqualified"/>
			<xsd:attribute name="age" type="xsd:integer" use="required" form="unqualified"/>
		</xsd:complexType>
	</xsd:element>

	<xsd:element name="testBean">
		<xsd:complexType>
			<xsd:attribute name="id" type="xsd:string" use="required" form="unqualified"/>
			<xsd:attribute name="name" type="xsd:string" use="required" form="unqualified"/>
			<xsd:attribute name="age" type="xsd:integer" use="required" form="unqualified"/>
		</xsd:complexType>
	</xsd:element>

	<xsd:element name="set">
		<xsd:complexType>
			<xsd:attribute name="name" type="xsd:string" use="required" form="unqualified"/>
			<xsd:attribute name="age" type="xsd:integer" use="required" form="unqualified"/>
		</xsd:complexType>
	</xsd:element>

	<xsd:element name="debug"/>
	<xsd:element name="nop"/>

	<xsd:attribute name="object-name" type="xsd:string"/>

</xsd:schema>

```

- 用于测试的property文件

```properties
http\://www.springframework.org/schema/beans/test=org.springframework.beans.factory.xml.support.TestNamespaceHandler
http\://www.springframework.org/schema/util=org.springframework.beans.factory.xml.UtilNamespaceHandler
```

- 测试代码

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

package org.springframework.beans.factory.xml.support;

import java.io.IOException;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.Set;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.w3c.dom.Attr;
import org.w3c.dom.Element;
import org.w3c.dom.Node;
import org.xml.sax.InputSource;

import org.springframework.aop.Advisor;
import org.springframework.aop.config.AbstractInterceptorDrivenBeanDefinitionDecorator;
import org.springframework.aop.framework.Advised;
import org.springframework.aop.interceptor.DebugInterceptor;
import org.springframework.aop.support.AopUtils;
import org.springframework.beans.BeanInstantiationException;
import org.springframework.beans.MutablePropertyValues;
import org.springframework.beans.factory.BeanCreationException;
import org.springframework.beans.factory.config.BeanDefinition;
import org.springframework.beans.factory.config.BeanDefinitionHolder;
import org.springframework.beans.factory.support.AbstractBeanDefinition;
import org.springframework.beans.factory.support.BeanDefinitionBuilder;
import org.springframework.beans.factory.support.RootBeanDefinition;
import org.springframework.beans.factory.xml.AbstractSingleBeanDefinitionParser;
import org.springframework.beans.factory.xml.BeanDefinitionDecorator;
import org.springframework.beans.factory.xml.BeanDefinitionParser;
import org.springframework.beans.factory.xml.DefaultNamespaceHandlerResolver;
import org.springframework.beans.factory.xml.NamespaceHandlerResolver;
import org.springframework.beans.factory.xml.NamespaceHandlerSupport;
import org.springframework.beans.factory.xml.ParserContext;
import org.springframework.beans.factory.xml.PluggableSchemaResolver;
import org.springframework.beans.factory.xml.XmlBeanDefinitionReader;
import org.springframework.context.ApplicationListener;
import org.springframework.context.support.GenericApplicationContext;
import org.springframework.core.io.ClassPathResource;
import org.springframework.core.io.Resource;
import org.springframework.tests.aop.interceptor.NopInterceptor;
import org.springframework.tests.sample.beans.ITestBean;
import org.springframework.tests.sample.beans.TestBean;

import static java.lang.String.format;
import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatExceptionOfType;

/**
 * Unit tests for custom XML namespace handler implementations.
 *
 * @author Rob Harrop
 * @author Rick Evans
 * @author Chris Beams
 * @author Juergen Hoeller
 */
public class CustomNamespaceHandlerTests {

	private static final Class<?> CLASS = CustomNamespaceHandlerTests.class;
	private static final String CLASSNAME = CLASS.getSimpleName();
	private static final String FQ_PATH = "org/springframework/beans/factory/xml/support";

	private static final String NS_PROPS = format("%s/%s.properties", FQ_PATH, CLASSNAME);
	private static final String NS_XML = format("%s/%s-context.xml", FQ_PATH, CLASSNAME);
	private static final String TEST_XSD = format("%s/%s.xsd", FQ_PATH, CLASSNAME);

	private GenericApplicationContext beanFactory;


	@BeforeEach
	public void setUp() throws Exception {
		NamespaceHandlerResolver resolver = new DefaultNamespaceHandlerResolver(CLASS.getClassLoader(), NS_PROPS);
		this.beanFactory = new GenericApplicationContext();
		XmlBeanDefinitionReader reader = new XmlBeanDefinitionReader(this.beanFactory);
		reader.setNamespaceHandlerResolver(resolver);
		reader.setValidationMode(XmlBeanDefinitionReader.VALIDATION_XSD);
		reader.setEntityResolver(new DummySchemaResolver());
		reader.loadBeanDefinitions(getResource());
		this.beanFactory.refresh();
	}


	@Test
	public void testSimpleParser() throws Exception {
		TestBean bean = (TestBean) this.beanFactory.getBean("testBean");
		assertTestBean(bean);
	}

	@Test
	public void testSimpleDecorator() throws Exception {
		TestBean bean = (TestBean) this.beanFactory.getBean("customisedTestBean");
		assertTestBean(bean);
	}

	@Test
	public void testProxyingDecorator() throws Exception {
		ITestBean bean = (ITestBean) this.beanFactory.getBean("debuggingTestBean");
		assertTestBean(bean);
		assertThat(AopUtils.isAopProxy(bean)).isTrue();
		Advisor[] advisors = ((Advised) bean).getAdvisors();
		assertThat(advisors.length).as("Incorrect number of advisors").isEqualTo(1);
		assertThat(advisors[0].getAdvice().getClass()).as("Incorrect advice class").isEqualTo(DebugInterceptor.class);
	}

	@Test
	public void testProxyingDecoratorNoInstance() throws Exception {
		String[] beanNames = this.beanFactory.getBeanNamesForType(ApplicationListener.class);
		assertThat(Arrays.asList(beanNames).contains("debuggingTestBeanNoInstance")).isTrue();
		assertThat(this.beanFactory.getType("debuggingTestBeanNoInstance")).isEqualTo(ApplicationListener.class);
		assertThatExceptionOfType(BeanCreationException.class).isThrownBy(() ->
				this.beanFactory.getBean("debuggingTestBeanNoInstance"))
			.satisfies(ex -> assertThat(ex.getRootCause()).isInstanceOf(BeanInstantiationException.class));
	}

	@Test
	public void testChainedDecorators() throws Exception {
		ITestBean bean = (ITestBean) this.beanFactory.getBean("chainedTestBean");
		assertTestBean(bean);
		assertThat(AopUtils.isAopProxy(bean)).isTrue();
		Advisor[] advisors = ((Advised) bean).getAdvisors();
		assertThat(advisors.length).as("Incorrect number of advisors").isEqualTo(2);
		assertThat(advisors[0].getAdvice().getClass()).as("Incorrect advice class").isEqualTo(DebugInterceptor.class);
		assertThat(advisors[1].getAdvice().getClass()).as("Incorrect advice class").isEqualTo(NopInterceptor.class);
	}

	@Test
	public void testDecorationViaAttribute() throws Exception {
		BeanDefinition beanDefinition = this.beanFactory.getBeanDefinition("decorateWithAttribute");
		assertThat(beanDefinition.getAttribute("objectName")).isEqualTo("foo");
	}

	@Test  // SPR-2728
	public void testCustomElementNestedWithinUtilList() throws Exception {
		List<?> things = (List<?>) this.beanFactory.getBean("list.of.things");
		assertThat(things).isNotNull();
		assertThat(things.size()).isEqualTo(2);
	}

	@Test  // SPR-2728
	public void testCustomElementNestedWithinUtilSet() throws Exception {
		Set<?> things = (Set<?>) this.beanFactory.getBean("set.of.things");
		assertThat(things).isNotNull();
		assertThat(things.size()).isEqualTo(2);
	}

	@Test  // SPR-2728
	public void testCustomElementNestedWithinUtilMap() throws Exception {
		Map<?, ?> things = (Map<?, ?>) this.beanFactory.getBean("map.of.things");
		assertThat(things).isNotNull();
		assertThat(things.size()).isEqualTo(2);
	}


	private void assertTestBean(ITestBean bean) {
		assertThat(bean.getName()).as("Invalid name").isEqualTo("Rob Harrop");
		assertThat(bean.getAge()).as("Invalid age").isEqualTo(23);
	}

	private Resource getResource() {
		return new ClassPathResource(NS_XML);
	}


	private final class DummySchemaResolver extends PluggableSchemaResolver {

		public DummySchemaResolver() {
			super(CLASS.getClassLoader());
		}

		@Override
		public InputSource resolveEntity(String publicId, String systemId) throws IOException {
			InputSource source = super.resolveEntity(publicId, systemId);
			if (source == null) {
				Resource resource = new ClassPathResource(TEST_XSD);
				source = new InputSource(resource.getInputStream());
				source.setPublicId(publicId);
				source.setSystemId(systemId);
			}
			return source;
		}
	}

}


/**
 * Custom namespace handler implementation.
 *	自定义名称空间处理器
 * @author Rob Harrop
 */
final class TestNamespaceHandler extends NamespaceHandlerSupport {

	@Override
	public void init() {
    // 注册节点为 testBean 的解析器
		registerBeanDefinitionParser("testBean", new TestBeanDefinitionParser());
    // 注册节点为 person 的解析器
		registerBeanDefinitionParser("person", new PersonDefinitionParser());
		
    // 注册 set 装饰器
		registerBeanDefinitionDecorator("set", new PropertyModifyingBeanDefinitionDecorator());
    // 注册 debug 装饰器
		registerBeanDefinitionDecorator("debug", new DebugBeanDefinitionDecorator());
    // 注册 nop 装饰器
		registerBeanDefinitionDecorator("nop", new NopInterceptorBeanDefinitionDecorator());
    // 注册 属性为 object-name 的装饰器
		registerBeanDefinitionDecoratorForAttribute("object-name", new ObjectNameBeanDefinitionDecorator());
	}

	// 节点为 testBean 的解析器
	private static class TestBeanDefinitionParser implements BeanDefinitionParser {

		@Override
		public BeanDefinition parse(Element element, ParserContext parserContext) {
			RootBeanDefinition definition = new RootBeanDefinition();
			definition.setBeanClass(TestBean.class);

			MutablePropertyValues mpvs = new MutablePropertyValues();
			mpvs.add("name", element.getAttribute("name"));
			mpvs.add("age", element.getAttribute("age"));
			definition.setPropertyValues(mpvs);

			parserContext.getRegistry().registerBeanDefinition(element.getAttribute("id"), definition);
			return null;
		}
	}

	// 节点为 person 的解析器
	private static final class PersonDefinitionParser extends AbstractSingleBeanDefinitionParser {

		@Override
		protected Class<?> getBeanClass(Element element) {
			return TestBean.class;
		}

		@Override
		protected void doParse(Element element, BeanDefinitionBuilder builder) {
			builder.addPropertyValue("name", element.getAttribute("name"));
			builder.addPropertyValue("age", element.getAttribute("age"));
		}
	}

	// set 装饰器
	private static class PropertyModifyingBeanDefinitionDecorator implements BeanDefinitionDecorator {

		@Override
		public BeanDefinitionHolder decorate(Node node, BeanDefinitionHolder definition, ParserContext parserContext) {
			Element element = (Element) node;
			BeanDefinition def = definition.getBeanDefinition();

			MutablePropertyValues mpvs = (def.getPropertyValues() == null) ? new MutablePropertyValues() : def.getPropertyValues();
			mpvs.add("name", element.getAttribute("name"));
			mpvs.add("age", element.getAttribute("age"));

			((AbstractBeanDefinition) def).setPropertyValues(mpvs);
			return definition;
		}
	}

	// debug 装饰器
	private static class DebugBeanDefinitionDecorator extends AbstractInterceptorDrivenBeanDefinitionDecorator {

		@Override
		protected BeanDefinition createInterceptorDefinition(Node node) {
			return new RootBeanDefinition(DebugInterceptor.class);
		}
	}

	// nop 装饰器
	private static class NopInterceptorBeanDefinitionDecorator extends AbstractInterceptorDrivenBeanDefinitionDecorator {

		@Override
		protected BeanDefinition createInterceptorDefinition(Node node) {
			return new RootBeanDefinition(NopInterceptor.class);
		}
	}

	// 属性为 object-name 的装饰器
	private static class ObjectNameBeanDefinitionDecorator implements BeanDefinitionDecorator {

		@Override
		public BeanDefinitionHolder decorate(Node node, BeanDefinitionHolder definition, ParserContext parserContext) {
			Attr objectNameAttribute = (Attr) node;
			definition.getBeanDefinition().setAttribute("objectName", objectNameAttribute.getValue());
			return definition;
		}
	}

}

```

通过运行结果可以看出这个装饰器可以针对与节点或者属性进行操作,相当于IO流中的设计模式一样,进行额外的增强.



# 三、小结

​	解析过了,也装饰过了,那就可以注册`BeanDefinitionHolder`对象了.
