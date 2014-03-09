describe 'pid-test', ->
  fs          = require 'fs'
  path        = require 'path'
  should      = require 'should'
  async       = require 'async'
  common      = require './common'

  options             = null
  server              = null
  api                 = null

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

  it 'check pid file', (done) ->
    pidFile = path.join api.config.pid, api.config.appName + '.pid'
    data = fs.readFileSync pidFile, { encoding: 'ascii' }
    process.pid.should.equal Number data
    done()
