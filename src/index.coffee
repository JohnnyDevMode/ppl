{head, tail} = require './utils'

as_promise = (thing, data, context={}) ->
  if thing?.then?
    thing
  else if typeof thing is 'function'
    prom = new FuncSegment thing, undefined
    prom._context = context
    prom._proceed_fulfill data
    prom
  else
    Pipeline.resolve thing

# Segment States
State =
  Pending: 'pending'
  Fulfilled: 'fulfilled'
  Rejected: 'rejected'

##
# Base segment in the pipeline.  Functions as a Promise but allows piping and splitting.
##
class Segment

  constructor: ->
    @_context= {}
    @state = State.Pending

  context: (@_context) -> @

  pipe: (func) ->
    if Array.isArray func
      return @_pass() if func.length == 0
      @pipe(head(func)).pipe tail func
    else if func == undefined
      @_pass()
    else
      @_pipe func

  then: (fulfill, reject) -> @_pipe fulfill, reject

  done: (fulfill, reject) -> @then fulfill, reject

  catch: (reject) -> @_pipe undefined, reject

  split: (map_func) ->
    return @pipe(map_func).split() if map_func?
    @extend new SplitSegment()

  map: (func) ->
    return @_pass() if func == undefined
    @split().pipe(func).join()

  all: (items) -> @extend new AllSegment(items)

  race: (items) -> @extend new RaceSegment(items)

  join: (join_func) ->
    return @_split_head.join join_func if @_split_head?
    @_pipe join_func

  extend: (segment) -> @_extend segment

  _extend: (segment) ->
    # console.log "#{@constructor.name} - extending with: #{segment.constructor.name} - state: #{@state}"
    @next_segment = segment
    segment.prev_segment = @
    segment._context = @_context
    segment._split_head = @_split_head
    switch @state
      when State.Fulfilled then segment._proceed_fulfill @_result
      when State.Rejected then segment._proceed_reject @_error
    segment

  toString: -> "#{@constructor.name} (state: #{@state}, result: #{@_result}, error: #{@_error})"

  _proceed_fulfill: (data) -> @_fulfill data

  _proceed_reject: (error) -> @_reject error

  _fulfill: (@_result) ->
    switch @state
      when State.Rejected then throw 'Pipeline segment cannot be fulfilled, already rejected'
      when State.Fulfilled then throw 'Pipeline segment cannot be fulfilled, already fulfilled'
    @state = State.Fulfilled
    @next_segment?._proceed_fulfill @_result

  _reject: (@_error) ->
    throw 'Pipeline segment already rejected!' if @state == State.Rejected
    @state = State.Rejected
    @next_segment?._proceed_reject @_error

  _pipe: (fulfill, reject) -> @extend new FuncSegment(fulfill, reject)

  _pass: -> @extend new Segment()

  _clone: ->
    clone = new @constructor()
    clone._context = @_context
    clone.extend @next_segment._clone() if @next_segment?
    clone

  _first: ->
    current = @
    while current?
      prev = current.prev_segment
      return current unless prev?
      current = prev
    @

  _last: ->
    current = @
    while current?
      next = current.next_segment
      return current unless next?
      current = next
    @

  _dump_pipeline: ->
    out = "Pipeline\n"
    current = @_first()
    while current?
      if current == @
        out += "|* #{current}\n"
      else
        out += "|  #{current}\n"
      current = current.next_segment
    out

class FuncSegment extends Segment

  constructor: (@fulfill_func, @reject_func) ->
    super()

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

  _clone: ->
    clone = super()
    clone.fulfill_func = @fulfill_func
    clone.reject_func = @reject_func
    clone

class SplitSegment extends Segment

  constructor: ->
    super()
    @child_pipes = []
    @joined = false

  extend: (segment) ->
    # console.log "#{@constructor.name} - template set as: #{segment.constructor.name} - state: #{@state}"
    @template = segment
    segment._context = @_context
    segment._split_head = @
    segment

  _proceed_fulfill: (@incoming) ->
    # console.log "Split fiulfill: #{@id}"
    # console.log "Data: ", incoming
    throw 'Can only split on Array context!' unless Array.isArray(@incoming)
    @_process_children() if @joined

  _process_children: ->
    # console.log "Split process : #{@id}"
    # console.log "Data : ", @incoming
    for item in @incoming
      segment = Pipeline.source(item).context @_context
      segment = segment.extend(@template._clone()) if @template?
      @child_pipes.push segment._last()
    @_fulfill @incoming

  join: (join_func) ->
    # console.log "Split join : #{@id}"
    segment = @_extend new JoinSegment(@)
    segment = segment.pipe join_func if join_func?
    @joined = true
    @_process_children() if @incoming?
    segment

  _clone: ->
    clone = new SplitSegment()
    clone._context = @_context
    clone.template = @template._clone() if @template?
    if @next_segment and @next_segment.constructor.name == 'JoinSegment'
      join = @next_segment._clone()
      clone._extend join
      clone.joined = true
      join.split_segment = clone
    clone

class JoinSegment extends Segment

  constructor: (@split_segment) ->
    super()

  _proceed_fulfill: (data) ->
    # console.log "Join fiulfill: #{@split.id}"
    # console.log "Data: ", data
    results = []
    pipes = @split_segment.child_pipes
    process = =>
      pipe = pipes.shift()
      return @_fulfill results unless pipe?
      pipe.then (result) ->
        results.push result
        process()
      pipe.catch (err) => @_reject err
    process()

class AllSegment extends Segment

  constructor: (@items) ->
    super()

  _proceed_fulfill: (data) ->
    results = []
    promises = (as_promise(item, data, @_context) for item in @items)
    process = =>
      promise = promises.shift()
      return @_fulfill results unless promise?
      promise.then (result) ->
        results.push result
        process()
      promise.catch (err) => @_reject err
    process()

  _clone: ->
    clone = super()
    clone.items = @item
    clone

class RaceSegment extends Segment

  constructor: (@items) ->
    super()

  _proceed_fulfill: (data) ->
    results = []
    promises = (as_promise(item, data, @_context) for item in @items)
    return @_fulfill undefined unless promises?.length
    complete = false
    for promise in promises
      promise
        .then (result) =>
          return if complete
          complete = true
          @_fulfill result
        .catch (err) =>
          return if complete
          complete = true
          @_reject err

  _clone: ->
    clone = super()
    clone.items = @item
    clone

class Pipeline extends Segment

  constructor: (callback) ->
    super()
    callback(
      (data) => @_fulfill data
      (err) => @_reject err
    )

  @source: (data) ->
    segment = new Segment()
    segment._fulfill data
    segment

  @resolve: (data) -> @source data

  @reject: (error) ->
    segment = new Segment()
    segment._reject error
    segment

  @all: (items) ->
    segment = new AllSegment items
    segment._proceed_fulfill()
    segment

  @race: (items) ->
    segment = new RaceSegment items
    segment._proceed_fulfill()
    segment

module.exports = Pipeline
