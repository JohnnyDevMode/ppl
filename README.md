# ppl (Promise Pipeline)
> Promise implementation with advanced flow control capabilities.

## Getting Started

Install ppl:

```shell
npm install ppl --save
```

## Overview

The ultra high-level description of `ppl` is another Promise implementation.  `ppl` adds a number of useful additions to the default Promise behaviors.  The additions allow you to support a lot of different flow patterns.  The additions will be described below, but thinking of this thing as a toolset for creating data pipes that can be split, mapped, joined and passed around while continuing to be Promise compatible at every turn.

Should you use `ppl` as your normal Promise implementation if you don't need any advanced flow control?  Nope. It would be another library to manage without little value.  So when should you use it?  You should use it when you want to create complex functional flows and want to switch data cardinality while still maintaining the Promise like result and failure handling. It may also come in handy when you want to create promise chains with predictable `this` context management.

## Usage

### Import `ppl`

``` coffeescript
pipeline = require 'ppl'
```

### Creating a pipeline

You have a couple options for creating pipelines.  The suggested option to create a pipeline with `.source` with some seed data.  You can also `.resolve` (just and alias for source), or you can use the good  ol' promise constructor.

*Using a source:*
``` coffeescript
pl = pipeline.source {some: 'data'}
```

*Using resolve:*
``` coffeescript
pl = pipeline.resolve {some: 'data'}
```

*Using the constructor:*
``` coffeescript
pl = new pipeline (fulfill, reject) ->
  fulfill {some: 'data'}
```

Hmmm.  That looks familiar...
``` coffeescript
Promise = require 'ppl'
pl = new Promise (fulfill, reject) ->
  fulfill {some: 'data'}
```

### Creating pipe segments

One of the most common tasks when working with a pipeline is to create pipe segment.  A segment is a function that will act on the data flowing through the pipe.  At any point in the pipeline you can `.pipe` to another function.  This is similar to how `.then` works in a traditional Promise.  There are a couple difference called out below, but it is generally safe to assume you can use `.pipe` and `.then` interchangeably. The goal usage for the library would be to use `.pipe` for intermediate steps and use `.then` or `.done` for final step in the change, but this is just a preference for how the code reads.

Each pipe segment will receive incoming data and is expected return outgoing data on completion.  The outgoing data from a segment is used as the incoming data for the next segment in the pipeline.

*A basic pipe:*
``` coffeescript
data = 1
pipeline
  .source data
  .pipe (data)-> data + 1
  .then (data) -> console.log data # 2
```

The example above is very much just promise behavior with the exception of the function execution context (covered below) and the face that the  `.pipe` method does not support a reject callback like `.then`.  

*A multi step pipeline:*

Pretty much what you expected.  Right?

``` coffeescript
data = 1
func1 = (data) data + 1
func2 = (data) data + 10
func3 = (data) data + 100

pipeline
  .source data
  .pipe func1
  .pipe func2
  .pipe func3
  .then (data) -> console.log data # 112
```

Unlike `.then` the `.pipe` method also supports an array of functions as a parameter.  Each function in the array becomes an additional segment in the pipeline and maintains execution order.  This just helps keep things tidy and reduces the number of lines of code.

``` coffeescript
# functionally equivalent to the last example

data = 1
func1 = (data) data + 1
func2 = (data) data + 10
func3 = (data) data + 100
pipeline
  .source data
  .pipe [func1, func2, func3]
  .then (data) -> console.log data # 112
```

*Error handling:*

Much like traditional promises, errors can be piped through to an instance of the `.catch` method.  Any error that occurs in processing the pipeline will propagate down the pipeline until is handled by a `.catch` or it runs out of segments.

``` coffeescript
data = 1
pipeline
  .source data
  .pipe (data)-> Promise.reject 'Some Error'
  .then (data) -> # Not called
  .catch (err) -> console.log err # 'Some Error'
```

``` coffeescript
data = 1
pipeline
  .source data
  .pipe (data)-> data + 1
  .pipe (data)-> data + 1
  .pipe (data)-> data + 1
  .pipe (data)-> Promise.reject 'Some Error'
  .pipe (data)->  # Not called
  .then (data) -> # Not called
  .catch (err) -> console.log err # 'Some Error'
```

### Splitting pipelines

One of the powerful additions `ppl` provides is the concept of splitting pipelines into multiple pipes when processing array data.  As an example you may have a segment that returns an array of items and you want those items to be manipulated by a series of functions before continuing down the standard pipeline.  With traditional Promise implementations you would need to write your functions to iterate over the data and return the results in each segment.  So the segment function itself needs to deal with the array.  This isn't the end of the world, but could get tedious. It also doesn't allow you to reuse segments that are assumed to act on a single item when working with arrays.  

This is where the `.split` and `.map` functionally comes in handy.  You can split the pipeline and apply segments that are intended to run on a single item.  When you are done processing on single items, you can join back to the parent pipeline and continue working with the array in the data flow.

*Basic split and join:*
``` coffeescript

data = [1, 2, 3, 4]
pipeline
  .source data
  .pipe (data) ->
    console.log data # [1, 2, 3, 4]
    data
  .split()
  .pipe (item) ->
    console.log item # 1 # 2 # 3 # 4
    item + 1
  .pipe (item) ->
    console.log item # 2 # 3 # 4 # 5
    item + 1
  .join()
  .then (data) ->
    console.log data # [3, 4, 5, 6]

```

*Multi-level split and join:*
``` coffeescript

data = [
  {items: [1, 2, 3]}
  {items: [1, 2, 3]}
  {items: [1, 2, 3]}
]
total = 0
pipeline
  .source data
  .split()
  .pipe (item) ->
    item.items
  .split()
  .pipe (item) ->
    console.log item # 1 # 2 # 3 # 1 # 2 # 3 # 1 # 2 # 3
    total += item
  .join()
  .join()
  .then ->
    console.log total # [3, 4, 5, 6]

```

### Setting the context

Every pipeline has a context for executing functions while processing the pipe.  By default this is set to an empty object.  Segments in the pipeline can use this object as they see fit.  This is useful for acting as a shared context for storing shared state throughout the processing.  It is also super useful for piping to detached object functions, but still running them in the context of their object.  

*Setting the context:*
``` coffeescript
context = some: 'context'
pipeline
  .source req
  .context context
```

*Using the context:*

``` coffeescript
context =
  some: 'context'
  func: ->
    'bar'
pipeline
  .source req
  .context context
  .then (req) ->
    @foo = @func()
    console.log @  # { some: 'context', foo: 'bar' }
```

It is  possible to change the context at any point in the pipeline.

*Changing context:*

``` coffeescript
context1 = some: 'context'
context2 = some: 'other context'
pipeline
  .source req
  .context context1
  .pipe -> console.log @  # { some: 'context'}
  .context context2
  .pipe -> console.log @  # { some: 'other context'}
```
