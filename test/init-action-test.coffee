describe 'action-test', ->
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

  it 'default action exists', (done) ->
    should.exist api.actions
    should.exist api.actions.map
    api.actions.map.should.have.property 'calculator.add'
    api.actions.map.should.have.property 'calculator.substract'
    done()