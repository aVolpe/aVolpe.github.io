---
layout: post
title: "Dropwizard Metrics with JaxRS"
description: "How to integrate the metrics library to a Standar Java EE 8
application"
category: "develop"
tags: jax-rs,metrics
---

[Dropwizard Metrics][metrics] is a Java library that provides tools to measure
an application.

Dropwizard offer various tools that help you with distinct metrics, like gauges,
counters, histograms and other.

The library has two phases, the first is the recollection of data and the second
is the reporting of the collected data to a data collector, in this post we will
integrate the recollection of data to an existing standard Java EE application.

First we need to create a `MetricRegistry` instance that will allows us to
create the various objects than implement the metric recollection, this registry
can be stored in a Application Bean if you are using CDI, or in an Singleton
bean if you are using only EJB.

This class can look like:

{% highlight java %}
@ApplicationScoped
public class Registry {

    private MetricRegistry metricRegistry;

    @PostConstruct
    public void init() {

        metricRegistry = new MetricRegistry();

        configureListeners();
    }

    public Counter counter(Class<?> clazz, String resource) {
        return metricRegistry.counter(MetricRegistry.name(clazz, resource));
    }

    public Timer timer(Class<?> clazz, String resource) {
        return metricRegistry.timer(MetricRegistry.name(clazz, resource));
    }

    private void configureListeners() {
        // in this part we can configure the data recollection tools, like        
        // the ConsoleReporter or the GraphiteReporter
    }
{% endhighlight %}

In this example we provide only two collectors, you can implement the others in
a similar way.

# Simple usage

Now, we can use this bean, suppose we has a redis connection managed by
[Jedis][jedis], Jedis provides us with a class called `JedisPool` that
is a pool of jedis instances.

This pool can have multiple jedis instances inside, and we are interested in the
number of instances that are used, and how many instances are available at any
moment, for this we can use metrics.

So we create a class that has a `@Produces` the jedis instances, something like
this:

{% highlight java %}
@ApplicationScoped
public class JedisProvider {

    @Inject
    private MetricRegistry metricRegistry;

    /**
     * Our pool
     */
    private JedisPool jedisPool;

    /**
     * Our metrics counter
     */
    private Counter counter;

    @PostConstruct
    public void init() {

        JedisPoolConfig jedisConfig = new JedisPoolConfig();
        jedisPool = new JedisPool(jedisConfig, "localhost", "5432");

        counter = registry.counter(getClass(), "redis");
    }

    @Produces
    public Jedis build() {
        counter.inc();
        return provider.getResource();
    }
    
    public void close(@Disposes Jedis jedis) {
        counter.dec();
        jedis.close();
    }
{% endhighlight %}

With this, every time a new `@Inject Jedis jedis` is processed, the counter will
increase, and after the bean has been used, the counter will decrement.

For this example we can also use [gauges][gauges].


# Using JaxRS request and response filters

[Metrics][metrics] provide a interesting measure, the Timer. This measure
has a annotation called `@Timed`, unfortunately I was unable to find any
implementation that works will JaxRS (and Resteasy, there is an [Jersey][jersey]
implementation, but use custom Jersey function and classes).

We can create our custom `@Timed` annotation, and annotate it with
`@NameBinding`, so we can use it as a binding annotation and is available to us
in the JaxRS filters.

The annotation looks like:

{% highlight java %}
@NameBinding
@Retention(RetentionPolicy.RUNTIME)
@Target({ ElementType.TYPE, ElementType.METHOD })
public @interface Timed {
}
{% endhighlight %}

And we can implement a simple JaxRS filter like this:


{% highlight java %}
@Provider
@Priority(Priorities.USER)
@Timed
public class MetricsFilter implements ContainerRequestFilter, ContainerResponseFilter {

    @Context
    private ResourceInfo resourceInfo;

    @Inject
    private Registry registry;

    @Inject
    private HttpServletRequest servletRequest;


    @Override
    public void filter(ContainerRequestContext requestContext) throws IOException {

        Timer timer = registry.timer(
            resourceInfo.getResourceClass(), 
            resourceInfo.getResourceMethod().getName());
        Timer.Context counter = timer.time();
        servletRequest.setAttribute("timer.context", counter);
    }

    @Override
    public void filter(
             ContainerRequestContext requestContext, 
             ContainerResponseContext responseContext) 
        throws IOException {

        Timer.Context tc = (Timer.Context) servletRequest.getAttribute("timer.context");
        if (tc != null) {
            tc.stop();
            servletRequest.removeAttribute("timer.context");
        }

    }
}
{% endhighlight %}

This will intercept every petition to a class (or method) annotated with
`@Timed`, and it will create a timer that will measure the duration of the
request.

Important notes:

1. If we don't use the `@PreMatching` annotation, this will be invoked after
   JaxRS find outs what method to invoke, so the time to find the correct method
   is not calculated.
2. This will not use any client side information, and only rely on the time that
   our methods take to execute
3. This will store the `Context` object in the servlet request, if we don't want
   to populate our request, and later calculate the time.

We can use this like this:

{% highlight java %}
    @Timed
    public Response authenticateUser(String email, String password, User.Type type) {
       // do important work
    }
{% endhighlight %}

[metrics]: http://metrics.dropwizard.io
[gauges]: http://metrics.dropwizard.io/3.2.2/getting-started.html#gauges
[jedis]:https://github.com/xetorthio/jedis
[jersey]:http://metrics.dropwizard.io/2.2.0/manual/jersey/
