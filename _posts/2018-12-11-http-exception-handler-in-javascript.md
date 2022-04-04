---
layout: post
title: "Alternatives for handling uncaugh exception in javascript api clients"
description: "This post explores various options for handling uncaugh exceptions with javascript frameworks"
category: "develop"
tags: ["javascript", "http"]
---

Modern javascript http clients use promises or somethings similar (for this
post, angular Observables are similar enough, so this post also is relevant to
angular), and a common issue with this approach is that sometimes we want to
show a default message to the user when something went wrong

I am using [the fetch standard API][fetch] in this blog, but the same can be
achieve with similar libraries like the browser [axios][Axios] or the default
angular [http client][angular-http].

Let imagine we need to access a rest API, so we create a simple class to handle
all the logic and interactions with this API, like this:


{% highlight javascript %}
export class APICaller {

  constructor() {
  }

  handleError(response) {
    if (response.status >= 200 && response.status < 300)
      return response;
    const error = new Error(response.statusText);
    error.response = response;
    throw error;
  };

  doGet (url) {
    return fetch(url)
      .then(response => this.handleError(response))
      .then(okResponse => okResponse.json())
  };

  getTodoList() {
    return this.doGet(`https://jsonplaceholder.typicode.com/todos/`)
  }
  getTodo(todoId) {
    return this.doGet(`https://jsonplaceholder.typicode.com/todos/${todoId}`)
  }

}

{% endhighlight %}

This example uses the excellent (and free) [json placeholder example
API][json-placeholder] to handle a list of `todos`.

With this class, we can get the list using:

{% highlight javascript %}

const api = new APICaller();
api.getTodoList()
    .then(list => console.log(list));
{% endhighlight %}

This will print all the todos, if we want to handler the errors, we can simply
add a `catch` clause:

{% highlight javascript %}

const api = new APICaller();
api.getTodoList()
    .then(list => console.log(list))
    .catch(err => console.log('fail to load todos', err))
{% endhighlight %}

This is fairy easy and common in many modern web apps, but the problem 
is when we want to add a global error handler.

Let's suppose the server is down, we can check this like this:

{% highlight javascript %}

const api = new APICaller();
api.getTodoList()
  .then(list => console.log(list))
  .catch(err => {
    if (err.message === 'Failed to fetch') {
      console.log('the server is down');
   } else {
      console.log('unkknown error');
   }
})
{% endhighlight %}

This will work, but the problem is that the we don't want to check in every call
if the server is down, and also this will provoke that we will have duplicated
code everywhere, now we will see some options.

# First attempt, global handler in the `APICaller`

What if we check for this kind of errors in the `APICaller` class?, lets change
our `handleError` method, like this:

{% highlight javascript %}
  handleError(response) {
    if (response.status >= 200 && response.status < 300)
      return response;
    if (response.statusText === 'Failed to fetch') {
      console.log('the server is down');
    }
    const error = new Error(response.statusText);
    error.response = response;
    throw error;
  };
}

{% endhighlight %}

In this case we can remove the catch, and all the exception will be correctly
handled in our method, we can try to extend this will every other `statusText`
message.

{% highlight javascript %}
  handleError(response) {
    if (response.status >= 200 && response.status < 300)
      return response;
    switch(response.statusText) {
    case 'Failed to fetch':
      console.log('the server is down');
      break;
    case 'Unauthorized':
      console.log('you need to log in first');
      break;
    default:
      console.log('Server error');
      break;
    }

    const error = new Error(response.statusText);
    error.response = response;
    throw error;
  };

{% endhighlight %}

But what happens if we want to handle some exceptions in our code, and all the
others in the global handler?

Well this will not work, because if we try something like this:

{% highlight javascript %}
new APICaller().getTodoList()
  .then(list => console.log(list))
  .catch(err => {
    console.log('personalized message');
  })
{% endhighlight %}

The console will print two messages, first the global one and then the
`personalized message`, this is because the order of execution is like
this:

1. First is executed the fetch
2. If there is an error the global handler is called
3. Finally the custom `catch` is invoked

We can't change the behaviour of the second step we we are in the third, but, we
have some options!

# First approach, parameter in the call

We can change the method `getTodoList` so it accept and argument, and object
with options to our `APICaller`, for example, we can do this:

{% highlight javascript %}

  handleError(response, showError) {
    if (response.status >= 200 && response.status < 300)
      return response;

    if (showError) { /* here the switch */ }
    const error = new Error(response.statusText);
    error.response = response;
    throw error;
  };

  doGet (url, options) {
    return fetch(url)
      .then(response => this.handleError(response, options.showError))
      .then(okResponse => okResponse.json())
  };

  getTodoList(options) {
    return this.doGet(`https://jsonplaceholder.typicode.com/todos/`, options)
  }

  // usage:

  new APICaller().getTodoList({ showError: false })
    .then(list => console.log(list))
    .catch(err => {
      console.log('personalized message');
    })


{% endhighlight %}

This will work, and if we pass the second parameter, the global message will not
apear. **The real issue with this approach is that we need to add an extra
object to every single call**.

# Second approach, flag on the response

We can also use the fact that we can add arbitrary props to an exception, for
example, we can add a flag to the error when we catch it.

For this approach to work, we need to change the order of the execution, to
this:

1. First is executed the fetch
3. The custom `catch` is invoked
2. The global handler is executed

We can implement this approach fairy easy with the help the `setTimeout` method,
like this:

{% highlight javascript %}

  handleError(response) {
    if (response.status >= 200 && response.status < 300)
      return response;

    const error = new Error(response.statusText);
    error.response = response;

    setTimeout(() => {
       if (!error.handled) { /* here the switch */ }
    }, 100)
    
    throw error;
  };

  ... The rest unchanged

  // usage:

  new APICaller().getTodoList()
    .then(list => console.log(list))
    .catch(err => {
      err.handled = true;
      console.log('personalized message');
    })


{% endhighlight %}

This will work, and we have total control about the global error message, **the
issue it's that we need to change every single catch to touch that flag**. 

Another advantage of this method is that we can do some code completely unrelated
to the exception in the catch (cleanup for example) and if we don't assign the flag
the global error will be created.

If we forget that the global error message exists and don't set the flag, the
worst case scenario is that an extra message will be displayed.

This is my preferred way of handling this problem.


# Third approach, magic with proxies

If we don't like the flag, we can use another approach to show global messages
only if the user don't catch it, we can use [javascript proxies][proxy].

The mozilla documentation defines a proxy as:

{% highlight csharp %}
The Proxy object is used to define custom behavior for fundamental 
operations (e.g. property lookup, assignment, enumeration, function 
invocation, etc).
{% endhighlight %}

We can use this object to intercept usages of our exception and show the global
message only if the programmer don't use our exception, like this:

{% highlight javascript %}
  // APICaller.js

  buildProxyException(data) {
    let handled = false;
    const handler = {
      get: (obj, prop) => {
        handled = true;
        return data[prop];
      }
    };

    setTimeout(() => {
      if (!handled) {
        /* here the big switch */
      }
    }, 100);

    const proxy = new Proxy(data, handler);
    proxy.original = data;
    return proxy;
  };


  handleError(response) {
    if (response.status >= 200 && response.status < 300)
      return response;

    const error = new Error(response.statusText);
    error.response = response;

    throw this.buildProxyException(response);
  };

  ... The rest unchanged

  // usage without global error:

  new APICaller().getTodoList()
    .then(list => console.log(list))
    .catch(err => {
      if (err.code === 'MY_CUSTOM_CODE')
         console.log('personalized message');
    })

  // usage with global error:

  new APICaller().getTodoList()
    .then(list => console.log(list))
{% endhighlight %}

In this example, the `console.log` only will be executed if we use an property
of the error (in the example `err.code`).

This is the most magical approach, **the only issue is that we can't not longer
let the global handler manage the error once we use the Exception**.

What do you think? How do you handle the global messages?

[fetch]: https://developer.mozilla.org/en-US/docs/Web/API/Fetch_API
[axios]: https://github.com/axios/axios
[angular-http]: https://angular.io/guide/http
[json-placeholder]: https://jsonplaceholder.typicode.com/
[proxy]: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Proxy
