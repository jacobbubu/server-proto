var redis, redisPackage;

redisPackage = require('redis');

redis = function(api, cb) {
  var next, _base;
  next = api.utils.next;

  /* server-proto will create the following stores within your redis database:
  
  ** Keys **
  
  - 'server-proto:cache' [] the common shared cache object
  - 'server-proto:stats' [] the common shared stats object
   */
  api.redis = {};
  if ((_base = api.config.redis).database == null) {
    _base.database = 0;
  }
  api.redis._start = function(api, cb) {
    return next(cb);
  };
  api.redis.initialize = function(cb) {
    api.redis.client = redisPackage.createClient(api.config.redis.port, api.config.redis.host, api.config.redis.options);
    api.redis.client.on('error', function(err) {
      return api.log.error('Redis Error:', err);
    });
    api.redis.client.on('connect', function() {
      return api.log.debug('connected to redis');
    });
    if ((api.config.redis.password != null) && api.config.redis.password !== '') {
      return api.redis.client.auth(api.config.redis.password, function() {
        return api.redis.client.select(api.config.redis.database, function(err) {
          if (err != null) {
            api.log.error('Error selecting database #' + api.config.redis.database + ' on redis.  exiting');
          }
          return next(cb);
        });
      });
    } else {
      return process.nextTick(function() {
        return api.redis.client.select(api.config.redis.database, function(err) {
          if (err != null) {
            api.log.error('Error selecting database #' + api.config.redis.database + ' on redis.  exiting');
          }
          return next(cb);
        });
      });
    }
  };
  return api.redis.initialize(function() {
    return next(cb);
  });
};

exports.redis = redis;
