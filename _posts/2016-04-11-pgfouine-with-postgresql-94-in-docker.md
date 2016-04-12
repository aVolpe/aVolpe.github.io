---
layout: post
title: "pgFouine with postgreSQL 9.4 in Docker"
description: "Simple pgFouine configuration for a dockerized postgresql"
category: develop
tags: [ postgresql, pgFouine, docker ]
---
{% include JB/setup %}

[pgFouine](pgfouine) is a log analyzer for PostgreSQL, it uses the postgreSQL
log to create charts and statistics about the usage of a database, provides a
useful visualization of the most expensive, common and heavy queries.

To configure pgfouine you need two things, change the log configuration of
postgresql and has a working syslog log. Unfortunately the default
[image](docker-image) for postgreSQL has a data volume pointing to the
`/var/lib/postgresql` directory, and the default configuration file is in
`/var/lib/postgresql/data/postgresql.conf`. Everything after a `VOLUME`
command is override at runtime, so you can't not change the default file in
the build process, this means that a simple Dockerfile is not enough.

In the source repo, the issues
[#105](https://github.com/docker-library/postgres/issues/105), and the merge
[#127](https://github.com/docker-library/postgres/pull/127) allows a user to
expand the configuration through the `.sample` file, this can be a good option,
in this entry we use another way, changing the only postgrseql configuration
file, and configuring a full rsyslog.


First we need a working postgresql configuration file, for example we can get
one from a container

{% highlight bash %}
 docker cp HASH:/var/lib/postgresql/data/postgresql.conf
{% endhighlight %}

Now, we need to configure postgres to log all to syslog:

1. Set the log method. Change 
    `#log_destination = 'stderr'`
  to:
    `log_destination = 'syslog'`
1. Uncomment the following lines:
  `syslog_facility = 'LOCAL0'`
  `syslog_ident = 'postgres'`
1. Set the parameter `log_min_duration_statement` to `0` (to log all), this can
  be further tuned to log only the expensive queries.
1. Set the `log_line_prefix` to `log_line_prefix = '%t [%p]: [%l-1] '`, this is
   recommended by the pgFouine team.

This configuration is all that pgFouine needs from the postgreSQL log system,
now, we need to use this configuration file in the postgreSQL instance, To allow
us to change the configuration file, we need to get the
[docker-entrypoint.sh](docker-entrypoint) from the repo, and change it to copy
the configuration file in every startup:

  1. Add to your Dockerfile `ADD postgresql.conf /postgresql.conf`
  1. When the scripts ask if the parameter is `postgres` (see this [gist](gists)
     for more details):
{% highlight bash %}
echo 'Copying configuration file'
gosu root cp /postgresql.conf /var/lib/postgresql/data/postgresql.conf
{% endhighlight %}

With this, we have postgreSQL in a docker container configured to use rsyslog as
the log facility. Now we need to install `rsyslog`, add the installation steps
to the Dockerfile:

{% highlight bash %}
# to install rsyslog
RUN apt-get update && apt-get install -y rsyslog 
# to log all to /var/log/postgresql
RUN echo "local0.* -/var/log/postgresql/postgresql.log" > /etc/rsyslog.d/50-default.conf 
# to enable the rsyslog service*
RUN update-rc.d rsyslog enable 
{% endhighlight %}

With the current configuration, postgreSQL floods the `/var/log/messages` and
`/var/log/syslog`, to prevent this (this step is optional), we need to configure
syslog to ignore the `local0` (the configured facility) when logging to
`messages` or `syslog`. To change the configuration file, we can go with `sed`
and replace, or grab a working file for our container (if you execute docker at
this moment, you will get a container with syslog, with a good default config
file to grab), and modify the lines (the config file is in `/etc/rsyslog.conf`):

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

Then, we add the configuration file to the proper location in our Dockerfile:
{% highlight bash %}
ADD ./rsyslog.conf /etc/rsyslog.conf
{% endhighlight %}

Now, you can run it!, to check if everything works fine, you can execute:

{% highlight bash %}
docker exec HASH tail -f /var/log/postgresql/postgresql.log

And see the log from the postgreSQL! (be careful, is very verbose).

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
[pgfouine]: http://pgfouine.projects.pgfoundry.org/tsung.html
