redisPackage = require 'redis'
next         = require('../utils').next

redis = (api, cb) ->

  ### server-proto will create the following stores within your redis database:

  ** Keys **

  - 'server-proto:cache' [] the common shared cache object
  - 'server-proto:stats' [] the common shared stats object
  ###

  api.redis = {}
  api.config.redis.database ?= 0

  api.redis._start = (api, cb) ->
    next cb

  api.redis.initialize = (cb) ->
    api.redis.client = redisPackage.createClient api.config.redis.port, api.config.redis.host, api.config.redis.options
    api.redis.client.on 'error', (err) ->
      api.log.error 'Redis Error:', err

    api.redis.client.on 'connect', ->
      api.log.debug 'connected to redis'

    if api.config.redis.password? and api.config.redis.password isnt ''
      api.redis.client.auth api.config.redis.password, ->
        api.redis.client.select api.config.redis.database, (err) ->
          if err?
            api.log.error 'Error selecting database #' + api.config.redis.database + ' on redis.  exiting'
          next cb
    else
      process.nextTick ->
        api.redis.client.select api.config.redis.database, (err) ->
          if err?
            api.log.error 'Error selecting database #' + api.config.redis.database + ' on redis.  exiting'
          next cb

  api.redis.initialize ->
    next cb

exports.redis = redis