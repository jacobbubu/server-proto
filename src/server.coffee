fs      = require 'fs'
path    = require 'path'
async   = require 'async'
extend  = require('./utils').extend
next    = require('./utils').next
hasFunc = require('./utils').hasFunc

defaultOptions =
  config:
    file: 'config.coffee'
    watch: true
  project_root: process.env.project_root ? (process.env.PROJECT_ROOT ? process.cwd())

class ServerProto
  constructor: ->
    self = @
    self.initalizers = {}
    self.api =
      running: false
      initialized: false
      shuttingDown: false

  initialize: (options, cb) ->
    if not cb?
      options = {}
      cb = options
    self = @
    self.startingOptions = self.api._startingOptions = extend defaultOptions, options
    self.api.project_root = self.startingOptions.project_root
    self.api._defaultConfig = require './default-config'

    initializerFolders = [
      __dirname + '/initializers/'
      path.resolve self.api.project_root, 'initializers/'
    ]

    initializerMethods = []
    for folder in initializerFolders
      if fs.existsSync folder
        fs.readdirSync(folder).sort().forEach (file) ->
          if file[0] isnt '.'
            ext = path.extname file
            initalizer = path.basename file, ext
            if ext in ['.js', '.coffee', '.litcoffee']
              requireKey = path.join folder, file
              if require.cache[requireKey]?
                delete require.cache[require.resolve requireKey]
              initializerMethods.push initalizer
              self.initalizers[initalizer] = require(requireKey)[initalizer]

    #  run initializers in order
    orderedInitializers = {}
    [
      # 'utils'
      'configObj'
      'logger'
      'pids'
      # 'exceptions'
      'stats'
      'redis'
      'resque'
      'tasks'
    ].forEach (i) ->
      orderedInitializers[i] = (cb) -> self.initalizers[i] self.api, cb

    initializerMethods.forEach (method) ->
      if typeof orderedInitializers[method] isnt 'function'
        orderedInitializers[method] = (cb) ->
          # self.api.log 'running custom initalizer: ' + method, 'info'
          self.initalizers[method] self.api, cb

    orderedInitializers['_complete'] = () ->
      self.appName = self.api.config.appName
      self.api.initialized = true
      next cb, null, self.api

    async.series orderedInitializers

  start: (options, cb) ->
    self = @

    doBeforeStart = (cb) ->
      orderedStarters = {}
      for starter, obj of self.api
        if hasFunc(obj, '_beforeStart') and not orderedStarters[starter]?
          do (name = starter) ->
            orderedStarters[name] = (cb) ->
              self.api[name]._beforeStart self.api, ->
                self.api.log.debug "initializer '#{name}' beforeStart has been run"
                next cb

      orderedStarters['_complete'] =  ->
        next cb
      async.series orderedStarters

    doStart = ->
      doBeforeStart ->
        orderedStarters = {}
        for starter, obj of self.api
          if hasFunc(obj, '_start') and not orderedStarters[starter]?
            do (name = starter) ->
              orderedStarters[name] = (cb) ->
                self.api[name]._start self.api, ->
                  self.api.log.debug "initializer '#{name}' started"
                  next cb

        orderedStarters['_complete'] =  ->
          self.api.log.info "'#{self.appName}' has been started"
          self.api.running = true
          next cb, null, self.api
        async.series orderedStarters

    if self.api.initialized
      doStart()
    else
      self.initialize options, (err) ->
        doStart()

  stop: (cb) ->
    self = @
    if self.api.running
      self.api.shuttingDown = true
      self.api.running = false
      self.api.initialized = false
      self.api.log.warn 'shutting down open servers and stopping running tasks'

      orderedTeardowns = {}
      [
        'tasks'
        'resque'
        'configObj'
      ].forEach (stop) ->
        if hasFunc self.api[stop], '_stop'
          do (name = stop) ->
            orderedTeardowns[name] = (cb) ->
              self.api[name]._stop self.api, cb

      for stop, obj of self.api
        if hasFunc(obj, '_stop') and not orderedTeardowns[stop]?
          do (name = stop) ->
            orderedTeardowns[name] = (cb) ->
              self.api[name]._stop self.api, cb

      orderedTeardowns['_complete'] =  ->
        self.api.pids.clearPidFile()
        self.api.log.info "'#{self.appName}' has been stopped"
        self.api.log.debug '***'
        delete self.api.shuttingDown
        next cb

      async.series orderedTeardowns

    else if self.api.shuttingDown
      # double sigterm; ignore it
    else
      self.api.log.info 'cannot shut down (not running any servers)'
      next cb, null, self.api

module.exports = ServerProto