fs        = require 'fs'
path      = require 'path'
{ next }  = require '../utils'

streams = (api, cb) ->
  api.streams = {}
  api.streams.map = {}

  api.streams.loadStreamFile = (file) ->
    try
      for streamName, innerFunc of require file
        if typeof innerFunc is 'function'
          if api.streams.map[streamName]?
            api.log.warn "Stream (#{streamName}) already exist"
          else
            do (name = streamName, func = innerFunc) ->
              api.streams.map[name] = ->
                try
                  func.apply @, arguments
                catch e
                  [..., cb] = arguments
                  cb e if typeof cb is 'function'
    catch e
      api.log.error 'loading stream file errors', e, file
      cb e

  api.streams.loadAllStreams = do ->

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
            if ext in ['.js', '.coffee', '.litcoffee']
              requireKey = fullFilePath
              api.streams.loadStreamFile requireKey
          else
            api.log.error file + 'is a type of file I cannot read'

    uniquefolders = {}
    uniquefolders[path.resolve __dirname, '../streams/'] = true
    uniquefolders[path.resolve api.project_root, 'streams/'] = true
    Object.keys(uniquefolders).forEach loadFolder

  next cb

module.exports.streams = streams