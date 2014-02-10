fs           = require 'fs'
path         = require 'path'
CSON         = require 'cson'
EventEmitter = require('events').EventEmitter
inherits     = require('util').inherits
eql          = require('../utils').eql
extend       = require('../utils').extend
next         = require('../utils').next

class Config
  constructor: (api) ->
    self = @
    self.options = api._startingOptions.config
    self.options.file = path.resolve api.project_root, self.options.file
    EventEmitter.call self
    self.setMaxListeners Infinity
    try
      configData = CSON.parseFileSync self.options.file
    catch e
      throw new Error "Bad config data - #{self.options.file}"
      proces.exit 1

    self.configData = extend api._defaultConfig, configData
    if self.options.watch
      self.fsWatcher = fs.watch self.options.file, { persistent: true }, (event) ->
        if event is 'change'
          CSON.parseFile self.options.file, (err, data) ->
            if err?
              api.log.error "Bad config data - #{self.options.file}", err
            else
              configData = extend api._defaultConfig, data
              if not eql(self.configData, configData)
                self.emit 'change', configData
                self.configData = configData
                api.log.info "Config data changed - #{self.options.file}"

inherits Config, EventEmitter

Config.prototype._teardown = (api, cb) ->
  self = @
  if self.fsWatcher?
    self.fsWatcher.close()
    self.fsWatcher = null
  next cb

config = (api, cb) ->
  file = path.resolve api.project_root, api._startingOptions.config.file
  if not fs.existsSync file
    throw new Error "No config file found - #{file}"
    proces.exit 1

  api.config = new Config api
  next cb

module.exports.config = config