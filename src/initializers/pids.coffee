fs   = require 'fs'
path = require 'path'
next = require('../utils').next

pids = (api, cb) ->
  { next } = api.utils

  api.pids = {}
  api.pids.pid = process.pid
  api.pids.title = api.config.appName
  api.pids.file = path.join api.config.pid, api.pids.title + '.pid'

  try fs.mkdirSync(api.config.pid, '0777') catch e

  api.pids.writePidFile = ->
    fs.writeFileSync api.pids.file, api.pids.pid.toString(), { encoding: 'ascii' }

  api.pids.readPidFile = ->
    try
      pid = fs.readFileSync api.pids.file, { encoding: 'ascii' }
      pid = Number pid
    catch e
      if e.code is 'ENOENT'
        pid = 0
      else
        api.log.error 'read pidfile failed', e
        process.exit 1
    pid

  api.pids.clearPidFile = () ->
    try
      fs.unlinkSync  api.pids.file
    catch e
      api.log.error 'unable to remove pidfile', e

  api.pids._start = (api, cb) ->
    # pid = api.pids.readPidFile()
    # if pid isnt 0
    #   api.log.error "#{api.pids.title}'s pidfile exists, exit now. #(#{pid})"
    #   process.exit 0

    try
      api.pids.writePidFile()
    catch e
      api.log.error 'write pid file failed', e
      process.exit 1
    api.log.info 'pid:', process.pid
    next cb

  next cb

exports.pids = pids
