---
layout: post
title: "BasicAuth filter with JaxRS"
description: "Simple authorization with jaxrs"
category: develop
comments: true
tags: jaxrs javaee basic-auth
---

[Basic Auth][basic-auth] can be a simple way to secure your web services,
specially when it's combined with SSL, to implement this kind of security with
JaxRS, you need to create a `ContainerRequestFilter` and extract the header,
check for the user and throw a exception if the user is invalid.

In this example we will use an simple stub to handle the authorization, for
example, with this service:

{% highlight java %}

public class SecurityChecker {

    public void check(String user, String pass) {
        if (realCheck(user, pass)) return;
        else throw new WrongUsernameAndPasswordException();

    }

    private boolean realCheck(String user, String pass) {
        // the real check here!
    }
}

{% endhighlight %}

The exception can extend [WebApplicationException][web-app-ex] to handle the
parsing to text, and have a nice message when the combination of user and
password is wrong, for example:

{% highlight java %}

public class WrongUsernameAndPasswordException extends WebApplicationException {

    public WrongUsernameAndPasswordException() {
        super(Response.status(Response.Status.UNAUTHORIZED)
         .type(MediaType.TEXT_PLAIN)
         .entity("Wrong user/password combination")
         .build());
    }
}

{% endhighlight %}

When this two classes in order, we can create the security filter, we need the
`@Provider` and `@PreMatching` annotations to intercept the request before is
handled for our methods annotated with `@Path`, also we need to extends from
`ContainerRequestFilter`:

{% highlight java %}
@Provider
@Priority(Priorities.AUTHENTICATION)
@PreMatching
public class SecurityFilter implements ContainerRequestFilter {

   // We inject the checker service.
   @Inject SecurityChecker checker;

   @Override
   public void filter(ContainerRequestContext requestContext) throws IOException {

      // Extract the actual header
      String header = requestContext.getHeaderString("Authorization");

      // check if is not empty or null
      if (header == null || header.trim().isEmpty()) throw new WrongUsernameAndPasswordException();

      // The format is: "Basic: base64(user:pass)"
      String[] parts = header.split(" ", 2);

      // if after the split we don't has two parts, the header is wrong.
      if (parts.length < 2) throw new WrongUsernameAndPasswordException();

      // Extract the "base64(user:pass)" part and decode
      String userPass = new String(Base64.getDecoder().decode(parts[1]));

      // Split with ":" to get the user and the pass
      String[] userPassArray = userPass.split(":", 2);

      // if after the split don't has two parts, the header is wrong.
      if (userPassArray.length < 2) throw new WrongUsernameAndPasswordException();

      String user = userPassArray[0];
      String pass = userPassArray[1];
      checker.check(user, pass);
   }

}
{% endhighlight %}


[basic-auth]: https://en.wikipedia.org/wiki/Basic_access_authentication
[web-app-ex]: http://docs.oracle.com/javaee/7/api/javax/ws/rs/WebApplicationException.html
