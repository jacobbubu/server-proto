fs      = require 'fs'
path    = require 'path'
async   = require 'async'
{ extend, next, hasFunc, Q }  = require './utils'

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

    stockedFolder = path.resolve __dirname, 'initializers/'
    appFolder = path.resolve self.api.project_root, 'initializers/'
    initializerFolders = [
      stockedFolder
    ]
    if stockedFolder isnt appFolder
      initializerFolders.push appFolder

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
      'utils'
      'configObj'
      'logger'
      'pids'
      # 'exceptions'
      'stats'
      'redis'
      'resque'
      'tasks'
    ].forEach (i) ->
      orderedInitializers[i] = (cb) ->
        self.initalizers[i] self.api, cb

    initializerMethods.forEach (method) ->
      if typeof orderedInitializers[method] isnt 'function'
        orderedInitializers[method] = (cb) ->
          try
            self.initalizers[method] self.api, (err, res) ->
              return cb err if err?
              next cb null, res
          catch e
            next cb e

    async.series orderedInitializers, (err) ->
      if err?
        next cb, err
      else
        self.appName = self.api.config.appName
        self.api.initialized = true
        next cb, null, self.api

  start: (options, cb) ->
    self = @

    doBeforeStart = (cb) ->
      orderedStarters = {}
      for starter, obj of self.api
        if hasFunc(obj, '_beforeStart') and not orderedStarters[starter]?
          do (name = starter) ->
            orderedStarters[name] = (cb) ->
              Q.nfcall self.api[name]._beforeStart, self.api
              .then ->
                self.api.log.debug "initializer '#{name}' beforeStart has been run"
                cb()
              .catch (err) ->
                cb err

      async.series orderedStarters
      , (err) ->
        if err?
          next cb, err
        else
          next cb

    doStart = (cb)->
        orderedStarters = {}
        for starter, obj of self.api
          if hasFunc(obj, '_start') and not orderedStarters[starter]?
            do (name = starter) ->
              orderedStarters[name] = (cb) ->
                self.api.log.debug "initializer '#{name}' is starting..."
                Q.nfcall self.api[name]._start, self.api
                .then ->
                  self.api.log.debug "initializer '#{name}' started"
                  cb()
                .catch (err) ->
                  cb err

        async.series orderedStarters
        , (err) ->
          if err?
            next cb, err
          else
            self.api.log.info "'#{self.appName}' has been started"
            self.api.running = true
            if process.send?
              process.send { name: self.api.config.appName, status: 'started' }
            next cb, null, self.api

    if self.api.initialized
      doStart cb
    else
      self.initialize options, (err) ->
        if err?
          next cb, err
        else
          doStart cb

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
              Q.nfcall self.api[name]._stop, self.api
              .then ->
                cb()
              .catch (err) ->
                cb err

      async.series orderedTeardowns
      , (err) ->
        if err?
          next cb, err
        else
          self.api.pids.clearPidFile()
          self.api.log.info "'#{self.appName}' has been stopped"
          self.api.log.debug '***'
          delete self.api.shuttingDown
          next cb

    else if self.api.shuttingDown
      # double sigterm; ignore it
      next cb
    else
      console.log 'cannot shut down (not running any servers)'
      next cb, null, self.api

module.exports = ServerProto