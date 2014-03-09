describe 'stats-test', ->
  os          = require 'os'
  should      = require 'should'
  async       = require 'async'
  common      = require './common'

  options     = null
  server      = null
  api         = null
  testKey     = null
  oldKeys     = null

  before (done) ->
    common.commonSetUp (err, res) ->
      should.not.exist err
      { options, server } = res
      server.start options, (err, apiObj) ->
        should.not.exist err
        api = apiObj
        oldKeys = api.config.stats.keys[0]
        done err

  after (done) ->
    api.config.stats.keys = oldKeys
    server.stop (err) ->
      should.not.exist err
      common.commonTearDown (err) ->
        should.not.exist err
        server = null
        done err

  describe 'single stats key', ->

    before (done) ->
      testKey = 'test:stats1'
      api.config.stats.keys = [testKey]
      done()

    after (done) ->
      api.redis.client.del testKey, ->
        done()

    it 'stats methods should exist', (done) ->
      api.stats.should.be.an.instanceOf Object
      api.stats.increment.should.be.an.instanceOf Function
      api.stats.get.should.be.an.instanceOf Function
      api.stats.getAll.should.be.an.instanceOf Function
      done()

    it 'incrementing enqueues items for later', (done) ->
      api.stats.increment 'thing', 1
      api.stats.increment 'thing'
      api.stats.increment 'Otherthing', -1

      api.stats.pendingIncrements['thing'].should.equal 2
      api.stats.pendingIncrements['Otherthing'].should.equal -1
      done()

    it 'buffered stats can be written', (done) ->
      api.stats.increment 'thing', 1
      api.stats.writeIncrements ->
        api.redis.client.hgetall testKey, (err, data) ->
          Number(data.thing).should.equal 3
          done()

    it 'stats can be read', (done) ->
      api.stats.increment 'thing', 1
      api.stats.writeIncrements ->
        api.stats.get 'thing', (err, data) ->
          Number(data).should.equal 4
          done()

    it 'stats can be read all at once', (done) ->
      api.stats.increment 'thing', 1
      api.stats.increment 'Otherthing', -1
      api.stats.writeIncrements ->
        api.stats.getAll (err, data) ->
          Number(data[testKey].thing).should.equal 5
          Number(data[testKey].Otherthing).should.equal -2
          done()

  describe 'multiple stats keys', ->

    before ->
      api.config.stats.keys = ['test:stats1', 'test:stats2']

    after (done) ->
      api.redis.client.del 'test:stats1', ->
        api.redis.client.del 'test:stats2', ->
          done()

    it 'buffered stats can be written (to multiple hashes)', (done) ->
      api.stats.increment 'somethingElse', 1
      api.stats.writeIncrements ->
        api.redis.client.hgetall 'test:stats1', (err, data1) ->
          api.redis.client.hgetall 'test:stats2', (err, data2) ->

            Number(data1.somethingElse).should.equal 1
            Number(data2.somethingElse).should.equal 1

            api.stats.getAll (err, data) ->
              Number(data['test:stats1'].somethingElse).should.equal 1
              Number(data['test:stats2'].somethingElse).should.equal 1
              done()