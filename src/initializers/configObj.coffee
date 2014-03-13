require 'coffee-script/register'

fs           = require 'fs'
path         = require 'path'
EventEmitter = require('events').EventEmitter
inherits     = require('util').inherits

eql = null; extend = null; next = null
period = 3000

class ConfigObj
  constructor: (api) ->
    self = @
    self.options = api._startingOptions.config
    self.file = path.resolve api.project_root, self.options.file
    self.fileTypes = ['.js', '.coffee', '.litcoffee']
    self.watcherId = null
    self.mtime = 0
    EventEmitter.call self
    self.setMaxListeners Infinity

inherits ConfigObj, EventEmitter

ConfigObj.prototype.loadConfig = (api, file, cb) ->
  self = @
  if path.extname(file) in @fileTypes
    fs.stat file, (err, stats) ->
      return next cb, err if err?

      if stats.isSymbolicLink()
        fs.readlinkSync file, (err, realPath) ->
          return next cb, err if err?
          self.loadConfig api, realPath, cb
      else if stats.isFile()
        if require.cache[file]?
          delete require.cache[file]
        try
          config = require(file).config
        catch e
          next cb, "#{file} is not a valid config file-" + e
          # skip reading bad file
          self.mtime = stats.mtime.getTime()
          return
        self.mtime = stats.mtime.getTime()
        next cb, null, extend(api._defaultConfig, config)
      else
        next cb, "#{file} is not a valid config file"
  else
    next cb, "Config file type should be in #{self.fileTypes}"

ConfigObj.prototype.periodicCheck = (api) ->
  self = @
  self.watcherId = null
  checkDone = ->
    self.watcherId = setTimeout ->
      self.periodicCheck api
    , period

  fs.stat self.file, (err, stats) ->
    if err?
      api.log.error "reading #{self.file} errors", err
      return checkDone()

    if self.mtime isnt stats.mtime.getTime()
      self.loadConfig api, self.file, (err, config) ->
        if err?
          api.log.error "bad config data - #{self.file} - #{err}"
        else
          if not eql(api.config, config)
            self.emit 'change', config
            api.config = config
            api.log.info "config data changed - #{self.file}"
        checkDone()
    else
      checkDone()

ConfigObj.prototype._stop = (api, cb) ->
  if @watcherId?
    clearTimeout @watcherId
    @watcherId = null
  next cb

configObj = (api, cb) ->
  { eql, extend, next } = api.utils

  file = path.resolve api.project_root, api._startingOptions.config.file
  if not fs.existsSync file
    return next cb, "No config file found - #{file}"

  api.configObj = new ConfigObj api
  api.configObj.loadConfig api, api.configObj.file, (err, config) ->
    if err?
      return next cb, 'config file loading failed', err
    else
      if api.configObj.options.watch
        api.configObj.watcherId = setTimeout ->
          api.configObj.periodicCheck api
        , period
      api.config = config
      next cb, null, config

module.exports.configObj = configObj