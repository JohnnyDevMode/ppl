
##
#
#  Promise like pipeline implementation that supports standard piping and splitting and joining multiple child pipelines.
#
##

# utils
head = (array) ->
  array[0]

tail = (array) ->
  array.slice(1)

# Segment States
State =
  Pending: 'pending'
  Fulfilled: 'fulfilled'
  Rejected: 'rejected'


##
# Base segment in the pipeline.  Functions as a Promise but allows piping and splitting.
##
class Segment

  constructor: (@_context={}) ->
    @_state = State.Pending
    @_wait_queue = []

  context: (@_context) ->
    @

  pipe: (func) ->
    if Array.isArray func
      next = head func
      return @ unless next?
      @_pipe(next).pipe tail func
    else if func == undefined
      @_pass()
    else
      @_pipe func

  then: (fulfill, reject) ->
    @_pipe fulfill, reject

  done: (fulfill, reject) ->
    @then fulfill, reject

  catch: (reject) ->
    @_pipe undefined, reject

  split: (map_func) ->
    if map_func?
      @pipe(map_func).split()
    else
      @_await new SplitSegment(@_context)

  map: (func) ->
    if func == undefined
      @_pass()
    else
      @split().pipe(func).join()

  _await: (segment) ->
    switch @_state
      when State.Pending then @_wait_queue.push segment
      when State.Fulfilled then segment._proceed_fulfill @_result
      when State.Rejected then segment._proceed_reject @_error
    segment

  _proceed_fulfill: (data) ->
    @_fulfill data

  _proceed_reject: (error) ->
    @_reject error

  _fulfill: (@_result) ->
    switch @_state
      when State.Rejected then throw 'Pipeline segment cannot be fulfilled, already rejected'
      when State.Fulfilled then throw 'Pipeline segment cannot be fulfilled, already fulfilled'
    @_state = State.Fulfilled
    segment._proceed_fulfill @_result for segment in @_wait_queue

  _reject: (@_error) ->
    throw 'Pipeline segment already rejected!' if @_state == State.Rejected
    @_state = State.Rejected
    segment._proceed_reject @_error for segment in @_wait_queue

  _pipe: (fulfill, reject) ->
    @_await new FuncSegment(fulfill, reject, @_context)

  _pass: -> @_await new Segment @_context


class SourceSegment extends Segment

  constructor: (data, context) ->
    super context
    @_fulfill data

class FuncSegment extends Segment

  constructor: (@fulfill_func, @reject_func, context) ->
    super(context)

  _proceed_fulfill: (data) ->
    return @_fulfill data unless @fulfill_func?
    result = @fulfill_func.apply @_context, [data]
    if result?.then?
      result
        .then (data) => @_fulfill data
        .catch (error) => @_reject error
    else
      @_fulfill result

  _proceed_reject: (error) ->
    return @_reject error unless @reject_func?
    result = @reject_func.apply @_context, [error]
    if result?.then?
      result
        .then (data) => @_fulfill data
        .catch (error) => @_reject error
    else
      @_reject result

class SplitSegment extends Segment

  constructor: (context) ->
    super context

  join: ->
    @_await new Segment @_context

  _pipe: (fulfill, reject) ->
    @_await new EachSegment(fulfill, reject, @_context)

class EachSegment extends SplitSegment

  constructor: (@fulfill_func, @reject_func, context) ->
    super context

  _proceed_fulfill: (data) ->
    throw 'Can only split on Array context!' unless Array.isArray(data)
    results = []
    data = data.slice()
    process = =>
      current = data.shift()
      return @_fulfill results unless current?
      segment = new FuncSegment @fulfill_func, @reject_func, @_context
      segment.then (result) ->
        results.push result
        process()
      segment.catch (err) => @_reject err
      segment._proceed_fulfill current
    process()


class Promise extends Segment

  constructor: (callback) ->
    super()
    callback(
      (data) => @_fulfill data
      (err) => @_reject err
    )

module.exports =

    Promise: Promise

    source: (data) ->
      new SourceSegment data
