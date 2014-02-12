next = require('../utils').next
clone = require('../utils').clone

stats = (api, cb) ->
  api.stats = {}
  api.stats.timer = null
  api.stats.pendingIncrements = {}

  api.stats._start = (api, cb) ->
    if api.config.stats.writeFrequency > 0
      api.stats.timer = setTimeout api.stats.writeIncrements, api.config.stats.writeFrequency
    next cb

  api.stats._stop = (api, cb) ->
    if api.stats.timer?
      clearTimeout api.stats.timer
      api.stats.timer = null
    next cb

  api.stats.increment = (key, count) ->
    count ?= 1
    count = parseFloat count
    api.stats.pendingIncrements[key] ?= 0
    api.stats.pendingIncrements[key] = api.stats.pendingIncrements[key] + count

  api.stats.writeIncrements = (cb) ->
    if api.stats.timer?
      clearTimeout api.stats.timer
      api.stats.timer = null
    # api.log.debug 'writing pending stats data', api.stats.pendingIncrements
    if api.config.stats.keys.length > 0 and Object.keys(api.stats.pendingIncrements).length > 0
      pendingIncrements = clone api.stats.pendingIncrements
      api.stats.pendingIncrements = {}
      multi = api.redis.client.multi()
      api.config.stats.keys.forEach (collection) ->
        for key, value of pendingIncrements
          multi.hincrby collection, key, value

      multi.exec (err) ->
        if err?
          api.log.error 'Stats errors - writeIncrements', err
        else
          api.stats.timer = setTimeout api.stats.writeIncrements, api.config.stats.writeFrequency
        next cb, err
    else
      api.stats.timer = setTimeout api.stats.writeIncrements, api.config.stats.writeFrequency
      next cb

  api.stats.get = (key, collection, cb) ->
    if typeof collection is 'function'
      cb = collection
      collection = null
    collection ?= api.config.stats.keys[0]
    api.redis.client.hget collection, key, (err, value) ->
      next cb, err, value

  api.stats.getAll = (collections, cb) ->
    if typeof collections is 'function'
      cb = collections
      collections = null
    collections ?= api.config.stats.keys

    results = {}
    if collections.length is 0
      next cb, null, results
    else
      multi = api.redis.client.multi()
      collections.forEach (collection) ->
        multi.hgetall collection
      multi.exec (err, data) ->
        if err?
          api.log.error 'Stats errors - getAll', err
          next cb, err
        else
          for i in [0...data.length]
            results[collections[i]] = data[i]
          next cb, null, results
  next cb

exports.stats = stats
