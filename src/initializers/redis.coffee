redis = (api, cb) ->

  { next, _ } = api.utils
  ### server-proto will create the following stores within your redis database:

  ** Keys **

  - 'server-proto:cache' [] the common shared cache object
  - 'server-proto:stats' [] the common shared stats object
  ###

  api.redis = {}
  redisConfig = _.defaults api.config.redis, {
    fake: true
  }
  redisConfig.fake = !!redisConfig.fake
  if !redisConfig.fake
    redisConfig.database ?= 0

  api.redis.config = redisConfig

  redisConfig.redisPackage = if redisConfig.fake then require('fakeredis') else require('redis')

  api.redis._start = (api, cb) ->
    next cb

  api.redis.initialize = (cb) ->
    if redisConfig.fake
      api.redis.client = redisConfig.redisPackage.createClient { fast: true }
      api.log.info 'connected to fakeredis'
      next cb
    else
      api.redis.client = redisConfig.redisPackage.createClient redisConfig.port, redisConfig.host, api.config.redis.options
      api.redis.client.on 'error', (err) ->
        api.log.error 'Redis Error:', err

      api.redis.client.on 'connect', ->
        api.log.info 'connected to redis', api.config.redis.host, api.config.redis.port

      if redisConfig.password? and redisConfig.password isnt ''
        api.redis.client.auth redisConfig.password, ->
          api.redis.client.select redisConfig.database, (err) ->
            if err?
              api.log.error 'Error selecting database #' + api.config.redis.database + ' on redis.  exiting'
            next cb
      else
        process.nextTick ->
          api.redis.client.select redisConfig.database, (err) ->
            if err?
              api.log.error 'Error selecting database #' + api.config.redis.database + ' on redis.  exiting'
            next cb

  api.redis.initialize ->
    next cb

exports.redis = redis