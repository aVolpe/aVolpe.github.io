---
layout: post
title: "Simple Atom reader with Ionic"
description: "Simple example of a rss feed reader with Ionic"
category: "ionic"
tags: [ "ionic", "rss" ]
---
{% include JB/setup %}

[Atom][atom-wiki] is a simple web feed format that handle the post data in XML,
various CMS, and static site generators use it to allow third party software
(like [feedly][Feedly]) to notify it's users when the site add more content.

The first problem to work with Atom and a JavaScript framework like Ionic, is
that parse a XML is not as trivial as parse a Json File, to parse the XML you
need some glue code.

The following snippet convert a ATOM Xml to a javascript object with some
properties:

{% highlight javascript %}
var parser = new DOMParser();
var xml = parser.parseFromString(data.data, 'text/xml');

var entryData = xml.getElementsByTagName('entry');
var posts = [];

for (var i = 0; i < entryData.length; i++) {
  posts.push({
    id          : getFirstNode(entryData[i], 'id').innerHTML,
    title       : getFirstNode(entryData[i], 'title').innerHTML,
    content     : getFirstNode(entryData[i], 'content').innerHTML,
    image       : getImageLink(entryData[i], 'thumbnail', 'media')
  });
}
{% endhighlight %}

The trick is to use the `DOMParser` to parse the `XML` data, and then you can
use it like any dom element (`getDocumentById`, `getElementsByTagName`, etc).

This snippet use two simple functions to extract the data from the Dom Element,

{% highlight javascript %}
function getFirstNode(parent, nodeName, nameSpace) {
   if (!nameSpace)
      return parent.getElementsByTagName(nodeName)[0];
   return parent.getElementsByTagName(nodeName, nameSpace)[0];
}

function getImageLink(parent, nodeName, nameSpace) {
   var node = getFirstNode(parent, nodeName, nameSpace);
   if (node)
      return node.getAttribute('url');
   return null;
}
{% endhighlight %}

This example, produces a Json like this:

{% highlight json %}
[
  {
    "id": "http://avolpe.github.io/ionic/2016/02/10/simple-atom-reader-with-ionic",
    "title": "Simple Atom reader with Ionic",
    "description": "Simple example of a rss feed reader with Ionic"
  }
]
{% endhighlight %}

## About CORSS problems

When you use a external Atom XML file (for example, a Atom file from a wordpress
blog), you will get a [CORS]  exception (that means, the file author don't allow
third party *webpages* access their content). In a real device you don't have
this problem, because you are not a `webpage`.

To fix this issue, you need to create a `Ionic Proxy`, to achieve this, add
something like this in your `ionic.project` file:

{% highlight csharp %}
"proxies" : [ {
   "path"     : "/rssData",
   "proxyUrl" : "http://avolpe.github.io"
} ]
{% endhighlight %}

And call to `/rssData/atom.xml` instead of the real URL. Read more about  [ionic
proxies here][ionic-proxy]

## Example with a Ionic List

If you use the previous code with a Ionic List, you can achieve a nice looking
view of your rss, something like this:

![Screenshot]({{ site.url }}/assets/ionic_atom.jpg){: .center-image}

With this html:

{% highlight html %}
{{ "{{ entry.image " }}}}
 <ion-list>
   <ion-item ng-repeat="entry in entries" class="item-avatar">
     <img ng-src="{{ "{{ entry.image " }}}}" />
     <h2>{{ "{{ entry.title"}} }}</h2>
     <p>{{ "{{ entry.url"}} }}</p>
   </ion-item>
 </ion-list>
{% endhighlight %}


[atom-wiki]: https://en.wikipedia.org/wiki/Atom_(standard)
[feedly]: https://feedly.com
[cors]: https://developer.mozilla.org/en-US/docs/Web/HTTP/Access_control_CORS
[ionic-proxy]: https://github.com/driftyco/ionic-proxy-example
