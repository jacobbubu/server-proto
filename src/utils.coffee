clone = (obj) ->
  if not obj? or typeof obj isnt 'object'
    return obj

  if obj instanceof Date
    return new Date(obj.getTime())

  if obj instanceof RegExp
    flags = ''
    flags += 'g' if obj.global?
    flags += 'i' if obj.ignoreCase?
    flags += 'm' if obj.multiline?
    flags += 'y' if obj.sticky?
    return new RegExp(obj.source, flags)

  newInstance = new obj.constructor()

  for key of obj
    newInstance[key] = clone obj[key]

  return newInstance

module.exports =
  next: (cb, err, res) ->
    cb err, res if typeof cb is 'function'

  hasFunc: (obj, func) ->
    if obj?
      typeof obj[func] is 'function' or typeof obj.__proto__[func] is 'function'
    else
      false

  listen: () ->
    args = Array.prototype.slice.call arguments
    server = args.splice(0, 1)[0]
    cb = args.slice(-1)[0] ? ->

    server.once 'error', (err) ->
      if err.code? and err.code is 'EADDRINUSE'
        cb err

    server.listen.apply server, args

  clone:          clone
  errStack:       (err) -> if err?.stack? then err.stack else err
  extend:         require 'xtend'
  eql:            require 'deep-equal'
  Q:              require 'q'
  uuid:           (require 'uuid').v4
  humanInterval:  require 'human-interval'
  async:          require 'async'
  _:              require 'lodash'
