describe 'task-test', ->
  should      = require 'should'
  common      = require './common'
  server      = null
  api         = null

  before (done) ->
    common.commonSetUp (err, res) ->
      should.not.exist err
      { options, server } = res
      server.start options, (err, apiObj) ->
        should.not.exist err
        api = apiObj
        done err

  after (done) ->
    server.stop (err) ->
      should.not.exist err
      common.commonTearDown (err) ->
        should.not.exist err
        server = null
        done err

  it 'tasks loaded successfully', (done) ->
    should.exist api.tasks
    api.tasks.tasks.should.have.property 'echo'

    input = 'Hello, Echo!'
    api.tasks.enqueue 'echo', input, ->
      setTimeout ->
        api.should.have.property 'trash', input
        done()
      , 2000