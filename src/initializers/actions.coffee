fs             = require 'fs'
path           = require 'path'
next           = require('../utils').next

actions = (api, cb) ->
  api.actions =
    preProcessors: []
    postProcessors: []
    map: {}

  # api.actions._start = (api, cb) ->
  #   next cb

  # api.actions._stop = (api, cb) ->
  #   next cb

  # api.actions.pre = ->
  #   ;

  # api.actions.post = ->
  #   ;

  api.actions.loadActionFile = (file) ->
    actionBase = path.basename(file).split('.')[0]
    try
      for key, innerFunc of require file
        if typeof innerFunc is 'function'
          actionName = [actionBase, key].join '.'
          if api.actions.map[actionName]?
            api.log.warn "Action (#{actionName}) already exist"
          else
            do (name = actionName, func = innerFunc) ->
              api.actions.map[name] = ->
                try
                  func.apply @, arguments
                catch e
                  [..., cb] = arguments
                  cb e if typeof cb is 'function'
    catch e
      api.log.error 'loading action file errors', e, file
      cb e

  api.actions.loadAllActions = do ->

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
              api.actions.loadActionFile requireKey
          else
            api.log.error file + 'is a type of file I cannot read'

    uniquefolders = {}
    uniquefolders[path.resolve __dirname, '../actions/'] = true
    uniquefolders[path.resolve api.project_root, 'actions/'] = true
    Object.keys(uniquefolders).forEach loadFolder

  next cb

module.exports.actions = actions