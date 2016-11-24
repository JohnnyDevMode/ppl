{assign} = require 'lodash'
Pipeline = require '../src'
Promise = Pipeline # just for fun....

describe 'Pipeline Tests', ->

  it 'I will just leave this here', (done) ->
    data = [
      {items: [1, 2, 3]}
      {items: [1, 2, 3]}
      {items: [1, 2, 3]}
    ]
    total = 0
    ps1 = 0
    ps2 = 0
    Pipeline
      .source data
      .split()
      .pipe (item) ->
        ps1++
        console.log "Items1: %j", item
        item.items
      .split()
      .pipe (item) ->
        ps2++
        console.log "Items2:", item
        total += item
        item
      .join()
      .pipe (data) ->
        console.log "data: ", data
        data
      .join()
      .then (result) ->
        ps1.should.eql 3
        ps2.should.eql 9
        total.should.eql 18
        done()

  describe 'Promise', ->

    describe '#resolve', ->

      it 'should immediately resolve', (done) ->
        expected = foo: 'bar'
        Promise
          .resolve expected
          .then (actual) ->
            actual.should.eql actual
            done()
          .catch done

      it 'should resolve later', (done) ->
        expected = foo: 'bar'
        prom = Promise.resolve(expected)
        later = ->
          prom
            .then (actual) ->
              actual.should.eql actual
              done()
            .catch done
        setTimeout later, 10

    describe '#source', ->

      it 'should immediately resolve', (done) ->
        expected = foo: 'bar'
        Promise
          .source expected
          .then (actual) ->
            actual.should.eql actual
            done()
          .catch done

      it 'should resolve later', (done) ->
        expected = foo: 'bar'
        prom = Promise.source(expected)
        later = ->
          prom
            .then (actual) ->
              actual.should.eql actual
              done()
            .catch done
        setTimeout later, 10

    describe '#reject', ->

      it 'should immediately reject', (done) ->
        expected = 'some error'
        Promise
          .reject expected
          .then ->
            done 'should not be called'
          .catch (actual) ->
            actual.should.eql actual
            done()

      it 'should reject later', (done) ->
        expected = foo: 'bar'
        prom = Promise.resolve(expected)
        later = ->
          prom
            .then (actual) ->
              actual.should.eql actual
              done()
            .catch done
        setTimeout later, 10


    describe 'constructed', ->

      it 'should provide fulfill and reject', (done) ->
        new Promise (fulfill, reject) ->
          fulfill.should.be.a 'function'
          reject.should.be.a 'function'
          done()

      it 'should handle fulfill', (done) ->
        expected = foo: 'bar'
        prom = new Promise (fulfill, reject) ->
          fulfill expected
        prom.then (actual) ->
          actual.should.eql expected
          done()

      it 'should handle reject', (done) ->
        expected = 'some error'
        prom = new Promise (fulfill, reject) ->
          reject expected
        prom.catch (actual) ->
          actual.should.eql expected
          done()

      it 'should handle reject with fulfill', (done) ->
        expected = 'some error'
        prom = new Promise (fulfill, reject) ->
          reject expected
        prom
          .then ->
            done 'should not be called'
          .catch (actual) ->
            actual.should.eql expected
            done()

      it 'should handle catch for reject in then', (done) ->
        expected = 'some error'
        prom = new Promise (fulfill, reject) ->
          fulfill foo: 'bar'
        prom
          .then ->
            Promise.reject expected
          .catch (actual) ->
            actual.should.eql expected
            done()

      it 'should handle then for promise in catch', (done) ->
        expected = for: 'bar'
        prom = new Promise (fulfill, reject) ->
          reject 'some error'
        prom
          .catch (err) ->
            Promise.resolve expected
          .then (actual)->
            actual.should.eql actual
            done()

    describe '#all', ->

      it 'should handle empty promise list', (done) ->
        Promise.all []
          .then (data) ->
            expect(data).to.eql []
            done()
          .catch done

      it 'should handle simple item', (done) ->
        Promise.all [ 1 ]
          .then (data) ->
            expect(data).to.eql [1]
            done()
          .catch done

      it 'should handle simple items', (done) ->
        Promise.all [ 1, 2, 3 ]
          .then (data) ->
            expect(data).to.eql [1, 2, 3]
            done()
          .catch done

      it 'should handle function', (done) ->
        Promise.all [ -> 1 ]
          .then (data) ->
            expect(data).to.eql [1]
            done()
          .catch done

      it 'should handle functions', (done) ->
        Promise.all [
            -> 1
            -> 2
            -> 3
        ]
          .then (data) ->
            expect(data).to.eql [1, 2, 3]
            done()
          .catch done

      it 'should handle promise', (done) ->
        Promise.all [ Promise.resolve(1) ]
          .then (data) ->
            expect(data).to.eql [1]
            done()
          .catch done

      it 'should handle promises', (done) ->
        Promise.all [ Promise.resolve(1), Promise.resolve(2), Promise.resolve(3) ]
          .then (data) ->
            expect(data).to.eql [1, 2, 3]
            done()
          .catch done

      it 'should handle mix', (done) ->
        Promise.all [
          1
          -> 2
          Promise.resolve(3)
        ]
          .then (data) ->
            expect(data).to.eql [1, 2, 3]
            done()
          .catch done

      it 'should handle error', (done) ->
        expected = 'some error'
        Promise.all [ Promise.resolve(1), Promise.reject(expected), Promise.resolve(3) ]
          .then (data) ->
            done 'should not be called'
          .catch (actual) ->
            actual.should.eql expected
            done()

  describe '#race', ->

    it 'should handle empty promise list', (done) ->
      Promise.race []
        .then (data) ->
          expect(data).to.eql undefined
          done()
        .catch done

    it 'should handle simple item', (done) ->
      Promise.race [ 1 ]
        .then (data) ->
          expect(data).to.eql 1
          done()
        .catch done

    it 'should handle function', (done) ->
      Promise.race [ -> 1 ]
        .then (data) ->
          expect(data).to.eql 1
          done()
        .catch done

    it 'should handle promise', (done) ->
      Promise.race [ Promise.resolve(1) ]
        .then (data) ->
          expect(data).to.eql 1
          done()
        .catch done

    it 'should return first complete', (done) ->
      Promise.race [
        new Promise (fulfill, reject) ->
          complete = ->
            fulfill 1
          setTimeout complete, 10
        new Promise (fulfill, reject) ->
          complete = ->
            fulfill 2
          setTimeout complete, 2
        new Promise (fulfill, reject) ->
          complete = ->
            fulfill 3
          setTimeout complete, 6
      ]
        .then (data) ->
          expect(data).to.eql 2
          done()
        .catch done

    it 'should handle error', (done) ->
      expected  = 'some error'
      Promise.race [
         new Promise (fulfill, reject) ->
           complete = ->
             fulfill 1
           setTimeout complete, 10
         new Promise (fulfill, reject) ->
           complete = ->
             reject expected
           setTimeout complete, 2
         new Promise (fulfill, reject) ->
           complete = ->
             fulfill 3
           setTimeout complete, 6
      ]
        .then (data) ->
          done 'should not be called'
        .catch (actual) ->
          actual.should.eql expected
          done()

  describe 'pipes', ->

    describe 'linear', ->

      it 'should handle no segments', (done) ->
        data = {foo: 'bar'}
        Pipeline
          .source data
          .then (result) ->
            result.should.equal data
            done()
          .catch done

      it 'should pipe with non promise func', (done) ->
        data = {foo: 'bar'}
        Pipeline
          .source data
          .pipe (context) ->
            assign context, bar: 'baz'
          .then (result) ->
            result.should.eql foo: 'bar', bar: 'baz'
            result.should.eql data
            done()
          .catch done

      it 'should pipe with multiple non promise func', (done) ->
        data = {foo: 'bar'}
        Pipeline
          .source data
          .pipe (context) ->
            assign context, bar: 'baz'
          .pipe (context) ->
            assign context, baz: 'qak'
          .then (result) ->
            result.should.eql foo: 'bar', bar: 'baz', baz: 'qak'
            result.should.eql data
            done()
          .catch done

      it 'should pipe with promise func', (done) ->
        data = {foo: 'bar'}
        Pipeline
          .source data
          .pipe (context) ->
            Promise.resolve(assign context, bar: 'baz')
          .then (result) ->
            result.should.eql foo: 'bar', bar: 'baz'
            result.should.eql data
            done()
          .catch done

      it 'should pipe with multiple promise func', (done) ->
        data = {foo: 'bar'}
        Pipeline
          .source data
          .pipe (context) ->
            Promise.resolve(assign context, bar: 'baz')
          .pipe (context) ->
            Promise.resolve(assign context, baz: 'qak')
          .then (result) ->
            result.should.eql foo: 'bar', bar: 'baz', baz: 'qak'
            result.should.eql data
            done()
          .catch done

      it 'should pipe with multiple mixed func', (done) ->
        data = {foo: 'bar'}
        Pipeline
          .source data
          .pipe (context) ->
            Promise.resolve(assign context, bar: 'baz')
          .pipe (context) ->
            assign context, baz: 'qak'
          .then (result) ->
            result.should.eql foo: 'bar', bar: 'baz', baz: 'qak'
            result.should.eql data
            done()
          .catch done

      it 'should pipe with multiple funcs', (done) ->
        data = {foo: 'bar'}
        Pipeline
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
        Pipeline
          .source data
          .pipe undefined
          .then (result) ->
            result.should.eql data
            done()
          .catch done

      it 'should handle error', (done) ->
        data = {foo: 'bar'}
        err_msg = 'Some error occured'
        Pipeline
          .source data
          .pipe (data) ->
            assign data, baz: 'qak'
          .pipe (data) ->
            Promise.reject err_msg
          .then (result) ->
            done 'Should have been an error'
          .catch (err) ->
            err.should.eql err_msg
            done()

      it 'should handle early error', (done) ->
        data = {foo: 'bar'}
        err_msg = 'Some error occured'
        Pipeline
          .source data
          .pipe (data) ->
            Promise.reject err_msg
          .pipe (data) ->
            assign context, baz: 'qak'
          .then (result) ->
            done 'Should have been an error'
          .catch (err) ->
            err.should.eql err_msg
            done()

    describe 'split pipes', ->

      it 'should handle a basic split and join', (done) ->
        Pipeline
          .source [1, 2, 3]
          .split()
          .join()
          .then (results) ->
            results.should.eql [1, 2, 3]
            done()
          .catch done

      it 'should handle a basic split and join with late resolve', (done) ->
        Pipeline
          .source [1, 2, 3]
          .pipe (data) ->
            new Promise (fulfill, reject) ->
              next = ->
                fulfill data
              setTimeout next, 20
          .split()
          .join()
          .then (results) ->
            results.should.eql [1, 2, 3]
            done()
          .catch done

      it 'should handle split with pipe', (done) ->
        Pipeline
          .source [1, 2, 3]
          .split()
          .pipe (item) ->
            console.log item
            item + 10
          .join()
          .then (results) ->
            results.should.eql [11, 12, 13]
            done()
          .catch done

      it 'should handle split with pipe and late resolved', (done) ->
        Pipeline
          .source [1, 2, 3]
          .pipe (data) ->
            new Promise (fulfill, reject) ->
              next = ->
                fulfill data
              setTimeout next, 20
          .split()
          .pipe (item) ->
            console.log item
            item + 10
          .join()
          .then (results) ->
            results.should.eql [11, 12, 13]
            done()
          .catch done

      it 'should handle split with multiple pipes', (done) ->
        Pipeline
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

      it 'should handle split with multiple pipes and late resolve', (done) ->
        Pipeline
          .source [1, 2, 3]
          .pipe (data) ->
            new Promise (fulfill, reject) ->
              next = ->
                fulfill data
              setTimeout next, 100
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
        Pipeline
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
        Pipeline
          .source stuff: [1, 2, 3]
          .split (data) -> data.stuff
          .join()
          .then (results) ->
            results.should.eql [1, 2, 3]
            done()
          .catch done

      it 'should handle a split and mapped  join', (done) ->
        Pipeline
          .source [1, 2, 3]
          .split()
          .join (data) -> stuff: data
          .then (results) ->
            results.should.eql stuff: [1, 2, 3]
            done()
          .catch done

    describe '.map', ->

      it 'should handle map with single func', (done) ->
        Pipeline
          .source [1, 2, 3]
          .map (item) -> item + 10
          .then (results) ->
            results.should.eql [11, 12, 13]
            done()
          .catch done

      it 'should handle multiple maps', (done) ->
        adder = (item) -> item + 10
        Pipeline
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
        Pipeline
          .source [1, 2, 3]
          .map [adder, adder, adder]
          .then (results) ->
            results.should.eql [31, 32, 33]
            done()
          .catch done

    describe '.all', ->

      it 'should handle all with no funcs', (done) ->
        Pipeline
          .source 1
          .all []
          .then (results) ->
            results.should.eql []
            done()
          .catch done

      it 'should handle all with single func', (done) ->
        Pipeline
          .source 1
          .all [(item) -> item + 10]
          .then (results) ->
            results.should.eql [11]
            done()
          .catch done

      it 'should handle all with multiple funcs', (done) ->
        Pipeline
          .source 1
          .all [
            (item) -> item + 10
            (item) -> item + 20
            (item) -> item + 30
          ]
          .then (results) ->
            results.should.eql [11, 21, 31]
            done()
          .catch done

    describe '.race', ->

      it 'should handle all with no funcs', (done) ->
        Pipeline
          .source 1
          .race []
          .then (results) ->
            expect(results).to.eql undefined
            done()
          .catch done

      it 'should handle race with single func', (done) ->
        Pipeline
          .source 1
          .race [(item) -> item + 10]
          .then (results) ->
            results.should.eql 11
            done()
          .catch done

      it 'should handle race with multiple funcs', (done) ->
        Pipeline
          .source 1
          .race [
            (item) ->
              new Promise (fulfill, reject) ->
                complete = ->
                  fulfill item  + 1
                setTimeout complete, 10
            (item) ->
              new Promise (fulfill, reject) ->
                complete = ->
                  fulfill item + 2
                setTimeout complete, 2
            (item) ->
              new Promise (fulfill, reject) ->
                complete = ->
                  fulfill item  + 3
                setTimeout complete, 10
          ]
          .then (results) ->
            console.log 'Here'
            results.should.eql 3
            done()
          .catch done

    describe '.context', ->

      it 'should default context', (done) ->
        Pipeline
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
        Pipeline
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
        prom = Pipeline
          .source {}
          .context context
          .pipe func
          .pipe -> [1, 2, 3]
          .split()
          .pipe func
          .pipe func
          .join()
          .pipe func
          .then -> done()
          .catch done
