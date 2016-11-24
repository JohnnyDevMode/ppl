
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

as_promise = (thing, data, context={}) ->
  if thing?.then?
    thing
  else if typeof thing is 'function'
    prom = new FuncSegment thing, undefined, context
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

  constructor: (@_context={}) ->
    @state = State.Pending
    @next_segment = undefined

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
    return @pipe(map_func).split() if map_func?
    @extend new SplitSegment @_context

  map: (func) ->
    return @_pass() if func == undefined
    @split().pipe(func).join()

  all: (items) -> @extend new AllSegment(items, @_context)

  race: (items) -> @extend new RaceSegment(items, @_context)

  join: (join_func) ->
    if @_split_head?
       @_split_head.join join_func
    else
      @_pipe join_func

  extend: (segment) ->
    @_extend segment

  _extend: (segment) ->
    # console.log "#{@constructor.name} - extending with: #{segment.constructor.name} - state: #{@state}"
    @next_segment = segment
    switch @state
      when State.Fulfilled then segment._proceed_fulfill @_result
      when State.Rejected then segment._proceed_reject @_error
    segment._split_head = @_split_head
    segment

  _proceed_fulfill: (data) ->
    @_fulfill data

  _proceed_reject: (error) ->
    @_reject error

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

  _pipe: (fulfill, reject) ->
    @extend new FuncSegment(fulfill, reject, @_context)

  _pass: -> @extend new Segment @_context

  _clone: ->
    clone = new @constructor()
    clone._context = @_context
    clone.extend @next_segment._clone() if @next_segment?
    clone

  _last: ->
    current = @
    while current?
      next = current.next_segment
      return current unless next?
      current = next
    @

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

  _clone: ->
    clone = super()
    clone.fulfill_func = @fulfill_func
    clone.reject_func = @reject_func
    clone

splitCnt = 0
class SplitSegment extends Segment

  constructor: (context) ->
    super context
    @id = splitCnt++
    # console.log "Split: #{@id}"
    @_split_head = @
    @child_pipes = []
    @joined = false

  extend: (segment) ->
    # console.log "#{@constructor.name} - template set as: #{segment.constructor.name} - state: #{@state}"
    @template = segment
    segment._split_head = @
    segment

  _proceed_fulfill: (@incoming) ->
    # console.log "Split fiulfill: #{@id}"
    # console.log "Data: ", incoming
    throw 'Can only split on Array context!' unless Array.isArray(incoming)
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
    join_seg = new JoinSegment @, @_context
    if join_func?
      segment = @_extend(join_seg).pipe join_func
    else
      segment = @_extend join_seg
    @joined = true
    @_process_children() if @incoming?
    segment

  _clone: ->
    clone = new SplitSegment @_context
    clone.id = @id
    clone.template = @template._clone() if @template?
    if @next_segment and @next_segment.constructor.name == 'JoinSegment'
      join = @next_segment._clone()

      clone._extend join
      clone.joined = true
      join.split_segment = clone
    clone

class JoinSegment extends Segment

  constructor: (@split_segment, context) ->
    super context

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

  constructor: (@items, context) ->
    super context

  _proceed_fulfill: (data) ->
    results = []
    promises = (as_promise(item, data, context) for item in @items)
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

  constructor: (@items, context) ->
    super context

  _proceed_fulfill: (data) ->
    results = []
    promises = (as_promise(item, data, context) for item in @items)
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
