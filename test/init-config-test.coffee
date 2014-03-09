describe 'config-test', ->
  os          = require 'os'
  fs          = require 'fs'
  path        = require 'path'
  should      = require 'should'
  async       = require 'async'
  common      = require './common'

  options             = null
  server              = null
  apiObj              = null
  configFile          = null
  originalFileContent = null
  test_config_item    = null

  before (done) ->
    common.commonSetUp (err, res) ->
      should.not.exist err
      { options, server } = res
      configFile = options.config.file
      originalFileContent = fs.readFileSync configFile, {encoding: 'utf8'}
      done err

  after (done) ->
    fs.writeFileSync configFile, originalFileContent, {encoding: 'utf8'}
    common.commonTearDown (err) ->
      should.not.exist err
      done err

  it 'initialize config', (done) ->
    test_config_item = ('' + Math.random()).slice 2, 10
    add = "config.test_config_item = '#{test_config_item}'"
    fs.writeFile configFile, originalFileContent + os.EOL + add, {encoding: 'utf8'}, (err) ->
      should.not.exist err
      server.start options, (err, api) ->
        should.not.exist err
        api.config.test_config_item.should.eql test_config_item
        server.stop done

  it 'change config file', (done) ->
    server.start options, (err, api) ->
      should.not.exist err
      api.configObj.on 'change', (data) ->
        data.test_config_item.should.eql test_config_item
        server.stop done

      setTimeout ->
        test_config_item = ('' + Math.random()).slice 2, 10
        add = "config.test_config_item = '#{test_config_item}'"
        fs.writeFile configFile, originalFileContent + os.EOL + add, {encoding: 'utf8'}, (err) ->
          should.not.exist err
      , 1000