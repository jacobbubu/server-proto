fs             = require 'fs'
path           = require 'path'
Minilog        = require 'Minilog'
ConsoleBackend = require('Minilog').backends.console
next           = require('../utils').next
eql            = require('../utils').eql
extend         = require('../utils').extend

logger = (api, cb) ->

  api.logger =
    enabled: false
    _init: ->
      api.logger.enable()
      api.configObj.on 'change', api.logger._configListener

    enable: ->
      return if api.logger.enabled
      try
        config = api.config.logger
        logger = Minilog config.scope
        Minilog.unpipe()

        if config.console?
          options = extend { theme: 'formatMinilog', 'filter-name': '.*', 'filter-level': 'debug' }, config.console
          if options.theme of ConsoleBackend
            myFilter = new Minilog.Filter()
            myFilter.deny (new RegExp options['filter-name']), options['filter-level']
            Minilog.pipe myFilter
              .pipe ConsoleBackend[options.theme]
              .pipe ConsoleBackend
          else
            throw new Error "Formatter '#{options.theme}' does not exist"

        if config.file?
          options = extend { 'filter-name': '.*', 'filter-level': 'debug' }, config.file
          myFilter = new Minilog.Filter()
          myFilter.deny (new RegExp options['filter-name']), options['filter-level']
          stream = fs.createWriteStream path.resolve(api.project_root, config.file)
          stream.on 'error', (err) ->
            api.log.error 'Write log file errors', err if api.log?

          Minilog.pipe(myFilter).pipe stream
        api.log = logger
        api.logger.enabled = true
      catch e
        message = 'Build api.log errors'
        if api.log?
          api.log.error message, e
        else
          console.error message, e
        process.exit 1

    disable: ->
      if api.logger.enabled
        logger = Minilog()
        Minilog.unpipe()
        api.log = logger
        api.logger.enabled = false

    _configListener: (data) ->
      newConfig = data.logger
      if not (eql newConfig, api.config.logger)
        api.logger._buildLogger newConfig

    _stop: (api, cb) ->
      api.configObj.removeListener 'change', api.logger._configListener
      next cb

  api.logger._init()
  next cb

module.exports.logger = logger