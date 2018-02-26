---
layout: post
title: "Metric collection using ionic and fabric"
description: "How to collect info about your hybrid app "
category: ionic
comments: true
tags: ['ionic', 'fabric', 'typescript']
---


# Fabric

[Fabric][fabric] is a group of tools that are very useful for various common
task in an typical mobile app development, in this blog we will explore various
parts of fabric including **Crashlytics**, **Beta** and **Answers**.

First you need to create an account and a organization (various apps are grouped
in an organization), and then go to [Organizations page][fabric-orgs], you need
to copy the `API key` and the `Build Secret` to install all the tools and
plugins that we will cover.

# Cordova plugin

The [fabric plugin][plugin] by `Sarriaroman` is a very useful and easy to use
plugin that will allow the integration of the fabric tools.

{% highlight bash %}
ionic cordova plugin add cordova-fabric-plugin \
               --variable FABRIC_API_KEY=$API_KEY \
               --variable FABRIC_API_SECRET=$BUILD_SECRET
{% endhighlight %}

For the official installation process go to [plugin installation
page][plugin-install]

*Note: This plugins works only in a mobile device, when you are using the
browser to test the app the plugin will not be available.*

*Note: You will have one 'aplication' per platform, this means that you don't
need to identify any of your request because the data for every platform will be
stored and handled independently.*

# Ionic integration

If you are using Ionic 2, 3 or later, then maybe you want TypeScript
integration, to achieve this, you need to add to your `tsconfig.json` the
following:

{% highlight json %}
  ...
  "files": [
    "plugins/cordova-fabric-plugin/typings/cordova-fabric-plugin.d.ts"
  ],
  ...
{% endhighlight %}

*Note: For an example of how to use this typings you can go to [the typings
examples][plugin-examples].*

# Crashlytics

Crashlytics is a very useful tool to report **crash** and other events (like not
fatal crashes and errors).

{% highlight typescript %}
if (window['fabric']) {
   fabric.Crashlytics.sendNonFatalCrash(message);
}
{% endhighlight %}

*The first check is to prevent to use the plugin in the browser.*

## Store user data

To add metadata to your reports you need to use various specific methods to
store the info, the main method is `setXXXValueForKey` (XXXX can be `String`, `Int`,
`Bool` or `Float`), but there are other specific methods to store user data:

* `setUserName`
* `setUserEmail`
* `setUserIdentifier`

When the user login you can store this data, and when the user log outs we need
to set the values of this keys to `null`.

# Answers

In a similar way, we can use the tool `Answers`, which is a tool to store
various events and to keep a track of actions of the user, for example we can
track successful logins, track a shopping cart, start of game levels, etc (you
can create your custom events too).

You can create a simple `AnswerProvider` to abstract the plugin and has an
single access point to `Answers`

First, let create the provider:

{% highlight bash %}
ionic g provider answer
{% endhighlight %}

And edit the constructor (we don't need the `HttpClient` that comes by default
with every provider):

{% highlight typescript %}
constructor(public platform: Platform) {

    platform.ready().then(
        () => {
            if (window['fabric'])
                this.answers = fabric.Answers;
            else
                this.answers = null;
        }
    )

}
{% endhighlight %}

And then add methods for our usage, for example to store and payment event:

{% highlight typescript %}
public endPurchase(item: string, 
                  itemType: string, 
                  itemId: string, 
                  currency = 'USD', 
                  success = true, 
                  amount = 0) {
    if (!this.answers) return;
    this.answers.sendPurchase(amount, currency, success, item, itemType, itemId);

}
{% endhighlight %}

*Note: The `if(!this.answers)` must be in every single method of this provider,
and you can accept your objects and handle the logic to translate your events
and the types of events in `Answers`*

**I will update this blog with more information about the various tools, including _beta_ and _firebase_**

[fabric]: https://fabric.io/home
[fabric-orgs]: https://fabric.io/settings/organizations/595da15f0a4e98bc1d000131
[plugin]: https://github.com/sarriaroman/FabricPlugin
[plugin-install]: https://github.com/sarriaroman/FabricPlugin#install
[plugin-examples]: https://github.com/sarriaroman/FabricPlugin/blob/master/typings/cordova-fabric-plugin-tests.ts
