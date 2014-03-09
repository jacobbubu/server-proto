replify = require('replify')
next    = require('../utils').next

repl = (api, cb) ->

  api.repl = {}
  api.repl._start = (api, cb) ->
    api.repl.replServer = replify api.config.appName, api
    next cb

  api.repl._stop = (api, cb) ->
    api.repl.replServer.close()
    next cb

  next cb

exports.repl = repl