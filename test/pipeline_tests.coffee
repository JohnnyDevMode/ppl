{assign} = require 'lodash'
pipeline = require '../src/pipeline'

describe 'Pipeline Tests', ->

  describe 'Promise', ->

    it 'should provide fulfill and reject', (done) ->
      new pipeline.Promise (fulfill, reject) ->
        fulfill.should.be.a 'function'
        reject.should.be.a 'function'
        done()

    it 'should handle fulfill', (done) ->
      expected = foo: 'bar'
      prom = new pipeline.Promise (fulfill, reject) ->
        fulfill expected
      prom.then (actual) ->
        actual.should.eql expected
        done()

    it 'should handle reject', (done) ->
      expected = 'some error'
      prom = new pipeline.Promise (fulfill, reject) ->
        reject expected
      prom.catch (actual) ->
        actual.should.eql expected
        done()

    it 'should handle reject with fulfill', (done) ->
      expected = 'some error'
      prom = new pipeline.Promise (fulfill, reject) ->
        reject expected
      prom
        .then ->
          done 'should not be called'
        .catch (actual) ->
          actual.should.eql expected
          done()

    it 'should handle catch for reject in then', (done) ->
      expected = 'some error'
      prom = new pipeline.Promise (fulfill, reject) ->
        fulfill foo: 'bar'
      prom
        .then ->
          Promise.reject expected
        .catch (actual) ->
          actual.should.eql expected
          done()

    it 'should handle then for promise in catch', (done) ->
      expected = for: 'bar'
      prom = new pipeline.Promise (fulfill, reject) ->
        reject 'some error'
      prom
        .catch (err) ->
          Promise.resolve expected
        .then (actual)->
          actual.should.eql actual
          done()


  describe 'pipes', ->

    describe 'linear', ->

      it 'should handle no segments', (done) ->
        context = {foo: 'bar'}
        pipeline
          .source context
          .then (result) ->
            result.should.equal context
            done()
          .catch done

      it 'should pipe with non promise func', (done) ->
        context = {foo: 'bar'}
        pipeline
          .source context
          .pipe (context) ->
            assign context, bar: 'baz'
          .then (result) ->
            result.should.eql foo: 'bar', bar: 'baz'
            result.should.eql context
            done()
          .catch done

      it 'should pipe with multiple non promise func', (done) ->
        context = {foo: 'bar'}
        pipeline
          .source context
          .pipe (context) ->
            assign context, bar: 'baz'
          .pipe (context) ->
            assign context, baz: 'qak'
          .then (result) ->
            result.should.eql foo: 'bar', bar: 'baz', baz: 'qak'
            result.should.eql context
            done()
          .catch done

      it 'should pipe with promise func', (done) ->
        context = {foo: 'bar'}
        pipeline
          .source context
          .pipe (context) ->
            Promise.resolve(assign context, bar: 'baz')
          .then (result) ->
            result.should.eql foo: 'bar', bar: 'baz'
            result.should.eql context
            done()
          .catch done

      it 'should pipe with multiple promise func', (done) ->
        context = {foo: 'bar'}
        pipeline
          .source context
          .pipe (context) ->
            Promise.resolve(assign context, bar: 'baz')
          .pipe (context) ->
            Promise.resolve(assign context, baz: 'qak')
          .then (result) ->
            result.should.eql foo: 'bar', bar: 'baz', baz: 'qak'
            result.should.eql context
            done()
          .catch done

      it 'should pipe with multiple mixed func', (done) ->
        context = {foo: 'bar'}
        pipeline
          .source context
          .pipe (context) ->
            Promise.resolve(assign context, bar: 'baz')
          .pipe (context) ->
            assign context, baz: 'qak'
          .then (result) ->
            result.should.eql foo: 'bar', bar: 'baz', baz: 'qak'
            result.should.eql context
            done()
          .catch done

      it 'should pipe with multiple funcs', (done) ->
        data = {foo: 'bar'}
        pipeline
          .source data
          .pipe [
              (context) -> Promise.resolve(assign context, bar: 'baz')
              (context) -> assign context, baz: 'qak'
          ]
          .then (result) ->
            result.should.eql foo: 'bar', bar: 'baz', baz: 'qak'
            result.should.eql data
            done()
          .catch done

      it 'should pipe with undefined func', (done) ->
        data = {foo: 'bar'}
        pipeline
          .source data
          .pipe undefined
          .then (result) ->
            result.should.eql data
            done()
          .catch done

      it 'should handle error', (done) ->
        context = {foo: 'bar'}
        err_msg = 'Some error occured'
        pipeline
          .source context
          .pipe (context) ->
            assign context, baz: 'qak'
          .pipe (context) ->
            Promise.reject err_msg
          .then (result) ->
            done 'Should have been an error'
          .catch (err) ->
            err.should.eql err_msg
            done()

      it 'should handle early error', (done) ->
        context = {foo: 'bar'}
        err_msg = 'Some error occured'
        pipeline
          .source context
          .pipe (context) ->
            Promise.reject err_msg
          .pipe (context) ->
            assign context, baz: 'qak'
          .then (result) ->
            done 'Should have been an error'
          .catch (err) ->
            err.should.eql err_msg
            done()

    describe 'split pipes', ->

      it 'should handle a basic split and join', (done) ->
        pipeline
          .source [1, 2, 3]
          .split()
          .join()
          .then (results) ->
            results.should.eql [1, 2, 3]
            done()
          .catch done

      it 'should handle a basic split and then', (done) ->
        source = [1, 2, 3]
        expected = source.length
        pipeline
          .source source
          .split()
          .then (result) ->
            index = source.length - expected
            result.should.eql source[index]
            done() if --expected == 0
          .catch done

      it 'should handle split with pipe', (done) ->
        pipeline
          .source [1, 2, 3]
          .split()
          .pipe (item) ->
            item + 10
          .join()
          .then (results) ->
            results.should.eql [11, 12, 13]
            done()
          .catch done

      it 'should handle split with multiple pipes', (done) ->
        pipeline
          .source [1, 2, 3]
          .split()
            .pipe (item) ->
              item + 10
            .pipe (item) ->
              item + 20
          .join()
          .then (results) ->
            results.should.eql [31, 32, 33]
            done()
          .catch done

      it 'should handle split with error', (done) ->
        err_msg = 'Some error occured'
        pipeline
          .source [1, 2, 3]
          .split()
          .pipe (item) ->
            Promise.reject(err_msg)
          .pipe (item) ->
            item + 20
          .join()
          .then (results) ->
            done 'Should have been an error'
          .catch (err) ->
            err_msg.should.eql err
            done()

      it 'should handle a mapped split and join', (done) ->
        pipeline
          .source stuff: [1, 2, 3]
          .split (data) -> data.stuff
          .join()
          .then (results) ->
            results.should.eql [1, 2, 3]
            done()
          .catch done

    describe '.map', ->

      it 'should handle map with single func', (done) ->
        pipeline
          .source [1, 2, 3]
          .map (item) -> item + 10
          .then (results) ->
            results.should.eql [11, 12, 13]
            done()
          .catch done

      it 'should handle multiple maps', (done) ->
        adder = (item) -> item + 10
        pipeline
          .source [1, 2, 3]
          .map adder
          .map adder
          .map adder
          .then (results) ->
            results.should.eql [31, 32, 33]
            done()
          .catch done

      it 'should handle multiple map func', (done) ->
        adder = (item) -> item + 10
        pipeline
          .source [1, 2, 3]
          .map [adder, adder, adder]
          .then (results) ->
            results.should.eql [31, 32, 33]
            done()
          .catch done

    describe '.context', ->

      it 'should default context', (done) ->
        pipeline
          .source {}
          .pipe (item) ->
            @.should.eql {}
            item
          .then (results) ->
            done()
          .catch done

      it 'should pipe context', (done) ->
        context = {foo: 'bar'}
        func = (item) ->
          context.should.eql @
          item
        pipeline
          .source {}
          .context context
          .pipe func
          .pipe func
          .then -> done()
          .catch done

      it 'should pipe context through split', (done) ->
        context = {foo: 'bar'}
        func = (item) ->
          context.should.eql @
          item
        pipeline
          .source {}
          .context context
          .pipe func
          .pipe ->
            [1, 2, 3]
          .split()
            .pipe func
            .pipe func
          .join()
          .pipe func
          .then -> done()
          .catch done
