fs             = require 'fs'
path           = require 'path'
events       = require 'events'
util         = require 'util'

class InnerEvents
  constructor: ->
    events.EventEmitter.call @

util.inherits InnerEvents, events.EventEmitter

supportData = (api, cb) ->
  { next, _, humanInterval, errStack, async } = api.utils

  api.supportData = {}
  interval = api.config.supportData?.interval ? '30 seconds'
  api.supportData.interval = humanInterval(interval) if typeof interval is 'string'
  api.supportData._store = {}
  api.supportData.events = new InnerEvents

  api.supportData.getData = (api, key) ->
    api.supportData._store[key]?.data

  api.supportData.getObject = (api, key) ->
    api.supportData._store[key]

  api.supportData.periodicCheck = ->
    setTimeout ->
      keys = Object.keys api.supportData._store
      async.each keys
      , (key, cb) ->
        value = api.supportData._store[key]
        fs.stat value.file, (err, stats) ->
          if err?
            api.log.error "support data(#{key}) file missing.", err, value.file
            cb err
          else
            mtime = stats.mtime.getTime()
            if value.mtime isnt mtime
              delete require.cache[value.file]
              try
                value.data = require value.file
                api.log.debug "support data(#{key}) changed."
                api.supportData.events.emit key, value.data
              catch e
                api.log.error "support data(#{key}) file errors.", errStack e, value.file
              value.mtime = mtime
            cb()
      , (err) ->
        api.supportData.periodicCheck()

    , api.supportData.interval

  api.supportData.loadDataFile = (file, stats) ->
    key = path.basename(file).split('.')[0]
    try
      value =
        file: file
        key: key
        data: require file
        mtime: stats.mtime.getTime()
      api.supportData._store[key] = value
    catch e
      api.log.error 'loading support data errors', file
      throw e

  api.supportData.loadAllData = ->

    loadFolder = (folder) ->
      if fs.existsSync folder
        fs.readdirSync(folder).forEach (file) ->
          fullFilePath = path.join folder, file
          stats = fs.statSync fullFilePath
          if stats.isDirectory()
            loadFolder fullFilePath
          else if stats.isSymbolicLink()
            realPath =fs.readlinkSync fullFilePath
            loadFolder realPath
          else if stats.isFile()
            ext = path.extname file
            if ext in ['.js', '.coffee', '.litcoffee', '.json']
              api.supportData.loadDataFile fullFilePath, stats
          else
            api.log.error file + 'is a type of file I cannot read'

    folders = [
      path.resolve __dirname, '../../supportData/'
      path.resolve api.project_root, '../supportData/'
    ]
    if api.config.supportData?.folder?
      folders.push path.resolve api.project_root, api.config.supportData.folder
    _.uniq(folders).forEach loadFolder

  try
    api.supportData.loadAllData()
    api.supportData.periodicCheck()
    next cb
  catch e
    next cb, errStack e

module.exports.supportData = supportData
