---
layout: post
title: "Currency evolution in Paraguay"
description: "Plot from data extracted from https://www.bcp.gov.py/webapps/web/cotizacion/monedas-mensual"
category: "open data"
tags: open-data visualization
---
{% include JB/setup %}

The Central Bank of Paraguay publish the most relevant currency quotes every
month in their [Cotización Referencia Mensual][central-bank] page.

The page has two options to get the data, a `pdf` per month and year, or a `ajax
request` per month and year. Because the pdf option require manual labor to
extract and process the data, I choose the ajax way.

The request is very simple, something like this:


{% highlight js %}
var request = {
  url       : "https : //www.bcp.gov.py/webapps/web/cotizacion/monedas-mensual",
  form_data : {
    anho : YEAR,
    mes  : MES
  }
}
{% endhighlight %}

With this simple [python script][gist-scrapper] I can get all the quotes from
2001. 

To get the updated data, execute:

{% highlight shell %}
python3 scrapper.js > full_data.csv
{% endhighlight %}

This script generates a `csv` with one line per quote per month and per year, so
you need to convert the data to use a service la [Plot.ly][plot-ly]. For
example, I use LibreOffice with the PivotTable feature to group the data by
currency and year, and then plot the data:

<iframe width="800" height="800" frameborder="0" scrolling="yes"
src="https://plot.ly/~avolpe/23.embed"></iframe>

Note that the plot don't show all the available currencies, to show an specific
currency, click the name in the right menu.

[central-bank]: https://www.bcp.gov.py/webapps/web/cotizacion/monedas-mensual
[gist-scrapper]: https://gist.github.com/aVolpe/8d2b4ffd29d990105ec5
[plot-ly]: http://plot.ly/~avolpe
