---
layout:      post
title:       "Database audit with postgresql and flyway"
date:        2015-10-19 10:27
categories:  develop
comments:    true
tags:        flyway postgresql maven
---

Postgresql has a feature that allows you to listen to all changes in a table and
audit them, this feature is described in the [Audit Trigger
page][postgresql-audit].

If you use [Flyway][flyway] to handle your database migrations it can be tedious
to update your triggers at every change. Thankfully, flyway has
[callbacks][flyway-callbacks], with this callbacks you can execute arbitrarily
java code in various phases, a particular useful callback is the `afterMigrate`,
this callback is execute after every migration.

## Configuration ##

To implement this callback, you need to add flyway as a dependency, with maven:

{% highlight xml %}
<dependency>
    <groupId>org.flywaydb</groupId>
    <artifactId>flyway-core</artifactId>
    <version>3.2.1</version>
</dependency>
{% endhighlight %}

And create a class that implements `FlywayCallback`, for example, a simple
callback is:

{% highlight java %}
package test;

import org.flywaydb.core.api.callback.FlywayCallback;

public class AuditCallback implements FlywayCallback {

    // Other methods

    @Override
    public void afterMigrate(Connection connection) {

        System.out.println("afterMigrate");
    }

}
{% endhighlight %}

Finally, you need to add that callback in your configuration, for example, with
maven:

{% highlight xml %}
<plugin>
    <groupId>org.flywaydb</groupId>
    <artifactId>flyway-maven-plugin</artifactId>
    <version>3.2.1</version>
    <configuration>
        <url>jdbc:postgresql://localhost:5432/database</url>
        <!-- Here you put your callbacks, in order -->
        <callbacks>
            <callback>test.AuditCallback</callback>
        </callbacks>
    </configuration>
    <dependencies>
        <!-- This is necessary to create the connection-->
        <dependency>
            <groupId>postgresql</groupId>
            <artifactId>postgresql</artifactId>
            <version>9.1-901-1.jdbc4</version>
        </dependency>
    </dependencies>
</plugin>
{% endhighlight %}


## Actual callback ##

For the real callback, we need to get the tables we want to audit, that can be
done with reflexion and get all the `@Entity` classes, or you can use a query to
get all the database tables, for example, this query obtains all tables:

{% highlight sql %}

SELECT table_schema || '.' || table_name AS table
FROM information_schema.tables 
WHERE table_schema NOT IN ('pg_catalog', 'information_schema');

{% endhighlight %}

We can remove from this list some tables, for example the table `public.schema_version`
is used for flyway to manage the versions, also your audit table must not be
audited.

Finally, we need to add the trigger, since this callback is executed many
times, the trigger must be added only if it doesn't exists already. To
achieve this we need to remove the trigger first, this `SQL` achieves this:


{% highlight sql %}
DROP TRIGGER IF EXISTS table_audit ON schema.table;
CREATE TRIGGER table_audit
AFTER INSERT OR UPDATE OR DELETE ON schema.table
FOR EACH ROW EXECUTE PROCEDURE audit.if_modified_func();
{% endhighlight %}

You need to manipulate the result of the tables query to put the info in the
trigger query, if you run `mvn clean flyway:migrate`, you must see:


{% highlight bash %}
[INFO] Scanning for projects...
[INFO]                                                                         
[INFO] ------------------------------------------------------------------------
[INFO] Building project 1.0-SNAPSHOT
[INFO] ------------------------------------------------------------------------
[INFO] 
[INFO] --- maven-resources-plugin:2.6:resources (default-resources) @ project ---
[INFO] Using 'UTF-8' encoding to copy filtered resources.
[INFO] Copying 9 resources
[INFO] 
[INFO] --- maven-compiler-plugin:3.1:compile (default-compile) @ project ---
[INFO] Nothing to compile - all classes are up to date
[INFO] 
[INFO] --- flyway-maven-plugin:3.2.1:migrate (default-cli) @ project ---
[INFO] Flyway 3.2.1 by Boxfuse
[INFO] Database: jdbc:postgresql://localhost:5432/newproject (PostgreSQL 9.3)
[INFO] Validated 4 migrations (execution time 00:00.014s)
[INFO] Current version of schema "public": 1.3
[INFO] Schema "public" is up to date. No migration necessary.

Updating audit info

[INFO] ------------------------------------------------------------------------
[INFO] BUILD SUCCESS
[INFO] ------------------------------------------------------------------------
[INFO] Total time: 2.776 s
[INFO] Finished at: 2015-10-19T11:22:42-03:00
[INFO] Final Memory: 35M/382M
[INFO] ------------------------------------------------------------------------
{% endhighlight %}

You can get the full example in [this gist][gist-link].


[postgresql-audit]:  http://wiki.postgresql.org/wiki/Audit_trigger
[flyway]:            http://flywaydb.org/
[flyway-callbacks]:  http://flywaydb.org/documentation/callbacks.html
[gist-link]:         https://gist.github.com/aVolpe/f12566b5ec7266144354
