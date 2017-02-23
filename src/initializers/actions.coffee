fs             = require 'fs'
path           = require 'path'

actions = (api, cb) ->
  { next, _, errStack } = api.utils

  api.actions =
    preProcessors: []
    postProcessors: []
    map: {}

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
      api.log.error 'loading action file errors', file
      throw e

  api.actions.loadAllActions = ->

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

    _.uniq([
      path.resolve __dirname, '../actions/'
      path.resolve api.project_root, 'actions/'
    ]).forEach loadFolder

  try
    api.actions.loadAllActions()
    next cb
  catch e
    next cb, errStack e

exports.actions = actions
