require 'coffee-script/register'

fs           = require 'fs'
path         = require 'path'
EventEmitter = require('events').EventEmitter
inherits     = require('util').inherits
eql          = require('../utils').eql
extend       = require('../utils').extend
next         = require('../utils').next

class ConfigObj
  constructor: (api) ->
    self = @
    self.options = api._startingOptions.config
    self.options.file = path.resolve api.project_root, self.options.file
    self.fileTypes = ['.js', '.coffee', '.litcoffee']
    EventEmitter.call self
    self.setMaxListeners Infinity
    try
      api.config = self.loadConfig api, self.options.file
    catch e
      throw new Error "Bad config data - #{self.options.file} - #{e}"
      proces.exit 1

    if self.options.watch
      self.fsWatcher = fs.watch self.options.file, { persistent: true }, (event) ->
        if event is 'change'
          try
            newConfig = self.loadConfig api, self.options.file
            if not eql(api.config, newConfig)
              self.emit 'change', newConfig
              api.config = newConfig
              api.log.info "Config data changed - #{self.options.file}"
          catch e
            api.log.error "Bad config data - #{self.options.file} - #{e}"

inherits ConfigObj, EventEmitter

ConfigObj.prototype.loadConfig = (api, file) ->
  self = @
  if path.extname(file) in @fileTypes
    if require.cache[file]?
      delete require.cache[file]
    config = require(file).config
    extend api._defaultConfig, config
  else
    throw new Error "Config file type should be in #{self.fileTypes}"

ConfigObj.prototype._stop = (api, cb) ->
  self = @
  if self.fsWatcher?
    self.fsWatcher.close()
    self.fsWatcher = null
  next cb

configObj = (api, cb) ->
  file = path.resolve api.project_root, api._startingOptions.config.file
  if not fs.existsSync file
    throw new Error "No config file found - #{file}"
    proces.exit 1

  api.configObj = new ConfigObj api
  next cb

module.exports.configObj = configObj