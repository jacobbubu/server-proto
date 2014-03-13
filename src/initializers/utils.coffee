internalUtils = require '../utils'
noop = ->

utils = (api, cb) ->
  cb ?= noop
  api.utils = {}
  for k, v of internalUtils
    api.utils[k] = v

  cb()

module.exports.utils = utils