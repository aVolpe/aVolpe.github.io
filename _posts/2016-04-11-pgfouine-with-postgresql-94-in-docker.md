---
layout: post
title: "pgFouine with postgreSQL 9.4 in Docker"
description: "Simple pgFouine configuration for a dockerized postgresql"
category: develop
tags: [ postgresql, pgFouine, docker ]
---
{% include JB/setup %}

To configure pgfouine you need two things, change the log configuration of
postgresql and has a working syslog log. Unfortunately the default
[image](docker-image) for postgreSQL has a data volume pointing to the
`/var/lib/postgresql` directory, and the default configuration file is in
`/var/lib/postgresql/data/postgresql.conf`. All that come after a `VOLUME`
definition is override at runtime, so you can't not change the default file in
the build process.

In the source repo, the issues
[#105](https://github.com/docker-library/postgres/issues/105), and the merge
[#127](https://github.com/docker-library/postgres/pull/127) allows a user to 
expand the configuration through the `.sample` file, allows to understand the problem.

My solution (with a working docker) is the main topic of this entry!.

First we need a working postgresql configuration file, for example we can get
one from a container

{% highlight bash %}
 docker cp HASH:/var/lib/postgresql/data/postgresql.conf
{% endhighlight %}

Now, we need to configure postgres to log all to syslog:
    1. Log all, to do this, change this line
      `#log_destination = 'stderr'`
      To this:
      `log_destination = 'syslog'`
    1. Uncomment the following lines:
      `syslog_facility = 'LOCAL0'`
      `syslog_ident = 'postgres'`
    1. Set the parameter `log_min_duration_statement` to 0 (to log all), this can
      be furted tunned to log only the expensive queries.
    1. Set the `log_line_prefix` to `log_line_prefix = '%t [%p]: [%l-1] '`

Now, we need to use this configuration file in the postgreSQL instance, for
this, we extract the [docker-entrypoint.sh](docker-entrypoint) from the repo,
and change it to copy the configuration file in every startup:

  1. Add to your Dockerfile `ADD postgresql.conf /postgresql.conf`
  1. When the scripts ask if the parameter is `postgres`:
{% highlight bash %}
echo 'Copying configuration file'
gosu root cp /postgresql.conf /var/lib/postgresql/data/postgresql.conf
{% endhighlight %}

With this, we have postgresql configured to use rsyslog as the log facility, now
we need to install `rsyslog`, add the installation steps to the
Dockerfile:

{% highlight bash %}
RUN apt-get update && apt-get install -y rsyslog # to install rsyslog
RUN echo "local0.* -/var/log/postgresql/postgresql.log" > /etc/rsyslog.d/50-default.conf # to log all to /var/log/postgresql*
RUN update-rc.d rsyslog enable # to enable the rsyslog service
{% endhighlight %}

With the current configuration, postgresql floods the `/var/log/messages` and
`/var/log/syslog`, to prevent this, we need to configure syslog to ignore the
`local0` when logging to messages or syslog. We need to change the configuration
file, we can go with `sed` and replace, or grab a working file for our container
(if you execute docker at this moment, you will get a container with syslog,
with a good default config file to grab), and modify the lines:

{% highlight configuration %}
# In some part, in my case the line  62
*.*;auth,authpriv.none -/var/log/syslog
# In other part, in my case the line 94
mail,news.none -/var/log/messages
{% endhighlight %}

And replace with:
{% highlight configuration %}
*.*;auth,authpriv.none,local0 -/var/log/syslog
local0,mail,news.none -/var/log/messages
{% endhighlight %}

And add this file to the docker, add this to the Dockerfile
{% highlight bash %}
ADD ./rsyslog.conf /etc/rsyslog.conf
{% endhighlight %}

Now, you can run it!, to check if everything works fine, you can execute:

{% highlight bash %}
docker exec HASH tail -f /var/log/postgresql/postgresql.log

{% endhighlight %}

P.D.: I has a problem with the syslog service, it will not start at the startup,
so I change the `docker-entrypoint.sh` to start the service, see the final
docker-entrypoint [here](gist).


This is my final Dockerfile:

{% gist avolpe/4dca6190b5a47bc72d80d2cd01ebd3d2 Dockerfile %}

The final files can be found in [this gists](gist).

[basic-auth]: https://en.wikipedia.org/wiki/Basic_access_authentication
[gist]: http://127.0.0.1:4000/develop/2016/04/11/pgfouine-with-postgresql-94-in-docker
[docker-image]: https://hub.docker.com/_/postgres/
[docker-entrypoint]: https://github.com/docker-library/postgres/blob/8e867c8ba0fc8fd347e43ae53ddeba8e67242a53/9.4/docker-entrypoint.sh
