---
layout: post
title: "Using Hibernate 5.2 with Wilfly 10 in Docker"
description: "Using the recently released Hibernate 5.2 with Wildfly 10 in a Docker container"
category: "open-data"
tags: javaee docker hibernate wildfly
---
{% include JB/setup %}

The 1st of June [Hibernate 5.2][hibernate-release] was released, this release
has some interesting features, like the consolidation of JPA in the core, and
support for java 8 API's.

Following the [Hibernate official update guide][hibernate-official-upate], we
need to replace the jars in the `wildfly/modules` folder.

In this blog, we will use the base docker image of Wildfly, with the tag
10.0.0.Final.

First, we create a simple Dockerfile:

```bash
FROM jboss/wildfly:10.0.0.Final
MAINTAINER Arturo Volpe <arturovolpe@gmail.com>
```

First, we need to get all the jars in the right place, the jars are available in
[Maven Central][maven-central-hibernate], so we add to our  this

```bash
RUN cd $JBOSS_HOME/modules/system/layers/base/org/hibernate/main && \
    curl -O http://central.maven.org/maven2/org/hibernate/hibernate-core/5.2.0.Final/hibernate-core-5.2.0.Final.jar && \
    curl -O http://central.maven.org/maven2/org/hibernate/hibernate-envers/5.2.0.Final/hibernate-envers-5.2.0.Final.jar

RUN cd $JBOSS_HOME/modules/system/layers/base/org/hibernate/infinispan/main/ && \
    curl -O http://central.maven.org/maven2/org/hibernate/hibernate-infinispan/5.2.0.Final/hibernate-infinispan-5.2.0.Final.jar && \
```

This will download the 5.2 jars in the correct place (we need to replace
hibernate-orm, envers, and infinispan).

The next step is remove the references and the jars of the previous release (for
the base image, hibernate 5.0.7)

```bash
# Replace hibernate, hibernate-envers
RUN sed -i.bak "s/5.0.7/5.2.0/" module.xml && \
    sed -i.bak "/entitymanager/d" module.xml && \
    sed -i.bak "/java8/d" module.xml && \
    rm *.bak

# Replace infinispan
RUN rm *5.0.7.Final.jar && \
    sed -i.bak "s/5.0.7/5.2.0/" module.xml && \
    rm *.bak
```

And we are done, with this, hibernate by default must provide the `5.2.0.Final`
version of Hibernate.

To use this, we can do something like this:

```java
@PersistenceContext
EntityManager em;

public Session getSession() {
    return em.unwrap(Session.class);
}
```

[docker]: https://www.docker.com://www.docker.com/
[wildfly]: http://wildfly.org/
[hibernate-release]: http://in.relation.to/2016/06/01/hibernate-orm-520-final-release/
[hibernate-official-upate]: https://docs.jboss.org/author/display/WFLY10/JPA+Reference+Guide#JPAReferenceGuide-UsingtheHibernate5.xJPApersistenceprovider
[maven-central-hibernate]: http://mvnrepository.com/artifact/org.hibernate/hibernate-core
