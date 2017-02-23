server      = new (require '../index')
mkdirp      = require 'mkdirp'
cp          = require 'cp'
path        = require 'path'

options =
  config:
    file: path.resolve __dirname, './tmp/config-tmp.coffee'
    watch: true
  project_root: __dirname

module.exports.commonSetUp = (done) ->
  mkdirp __dirname + '/tmp', (err) ->
    return done err if err?
    cp __dirname + '/config.coffee', __dirname + '/tmp/config-tmp.coffee', (err) ->
      return done err if err?
      done null, { server: server, options: options}

module.exports.commonTearDown = (done) ->
  done()
