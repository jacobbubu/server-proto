fs     = require 'fs'
path   = require 'path'
common = require './common'
assert = require('referee').assert
refute = require('referee').refute
buster = require 'bustermove'
CSON   = require 'cson'

server = null
configItem = test_config_item: 0
options =
  config:
    file: path.resolve __dirname, './init-config-test/config1.cson'
    watch: true

buster.testCase 'batch()',
  'setUp':(done) ->
    common.commonSetUp.call @, ( ->
      configItem.test_config_item = +new Date
      fs.writeFileSync options.config.file, CSON.stringifySync configItem
      server = new common.ServerProto
      done()
      ).bind @
  'tearDown': (done) ->
    common.commonTearDown.call @, ( ->
      server = null
      done()
      ).bind @

  'initialize config': (done) ->
    server.start options, (err, api) ->
      refute err
      assert.defined api.config.configData.appName
      assert.equals api.config.configData.test_config_item, configItem.test_config_item
      server.stop()
      done()

  'change event': (done) ->
    server.start options, (err, api) ->
      refute err
      api.config.on 'change', (data) ->
        assert.defined api.config.configData.appName
        assert.equals data.test_config_item, configItem.test_config_item
        server.stop()
        done()

      setTimeout ->
        configItem.test_config_item = +new Date
        fs.writeFileSync options.config.file, CSON.stringifySync configItem
      , 10
