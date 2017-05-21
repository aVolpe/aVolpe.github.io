---
layout: post
title: "Using Hibernate Spatial with Wildfly 9/10"
description: "How to configure Wildfly 9 or 10 to use a datasource with hibernate spatial types"
category: hibernate
tags: javaee hibernate wildfly
---

[Hibernate Spatial][hibernate-spatial] is a project that allows hiberante (and
JPA) to use Spatial facilities provided by database vendor's (like
[postgis][postgis]).

If we are using a database provided datasource, we need to add the necessary
dependencies to the hibernate module in Wildfly.

# Dependencies

First we need hibernate spatial and all of its dependencies, by default, it's
depends on [GeoLatte][geolatte] and [VididSolutions JTS][jts]. Also, geolatte
depends on slf4j.

To add this dependencies, we need to downloads the desired jars, for this guide,
I will use Hibernate Spatial 5.0.7, JTS 1.13, and Geolatte 1.0.1, as Wildfly 10.0.0.Final currently ships with Hibernate 5.0.7, and JTS 1.13 and Geolatte 1.0.1 are transitive dependencies for Hibernate Spatial 5.0.7.

You can get the jars from:

* [Hibernate Spatial](http://central.maven.org/maven2/org/hibernate/hibernate-spatial/5.0.7.Final/hibernate-spatial-5.0.7.Final.jar)
* [JTS](http://central.maven.org/maven2/com/vividsolutions/jts/1.13/jts-1.13.jar)
* [GeoLatte](http://central.maven.org/maven2/org/geolatte/geolatte-geom/1.0.1/geolatte-geom-1.0.1.jar)

You can also download the dependencies directly through the Maven CLI:

```sh
mvn dependency:copy -Dartifact=org.hibernate:hibernate-spatial:5.0.7.Final:jar -DoutputDirectory=.
mvn dependency:copy -Dartifact=org.geolatte:geolatte-geom:1.0.1:jar -DoutputDirectory=.
mvn dependency:copy -Dartifact=com.vividsolutions:jts:1.13:jar -DoutputDirectory=.
```

If you are using another version of Hibernate, you need to check the Hibernate
`pom.xml` and use the correct versions.

# Installation

Download the three jars to `$JBOSS_PATH/modules/system/layers/base/org/hibernate/main`,
and modify the file `module.xml` that is in the same path.

In the `<resources>` tag, add:

```xml
<resource-root path="hibernate-spatial-5.0.7.Final.jar"/>
<resource-root path="jts-1.13.jar"/>
<resource-root path="geolatte-geom-1.0.1.jar"/>
```

And in the `dependencies` tag, add:

```xml
<module name="org.slf4j"/>
```

Also if you are using postgresql, you need to add in the dependencies tag:

```xml
<module name="org.postgresql"/>
```

And this is all.

# Test 

Add to your pom:

```xml
<dependency>
  <groupId>org.hibernate</groupId>
  <artifactId>hibernate-spatial</artifactId>
  <scope>provided</scope>
  <version>5.0.7.Final</version>
</dependency>
```

And create a entity like:

```java
import javax.persistence.*;

import com.vividsolutions.jts.geom.Geometry;


@Entity
public class Place extends BaseEntity {

  @NotNull
  private Geometry location;

   // getters and setters
}
```

Now, we can create a query like:

```sql
SELECT
  distance(p.location, :userLocation)
FROM Place p
ORDER BY
  distance(p.location, :userLocation) ASC
```

And it will be translated to (if we are using postgresql) to:

```sql
SELECT st_distance(place0_.location, ?)
FROM place place0_
ORDER BY st_distance(place0_.location, ?)
```




[hibernate-spatial]: http://www.hibernatespatial.org/
[postgis]: http://postgis.net/
[geolatte]: https://github.com/GeoLatte/
[jts]: http://www.vividsolutions.com/jts/JTSHome.htm
