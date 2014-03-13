var stats;

stats = function(api, cb) {
  var clone, next, _ref;
  _ref = api.utils, next = _ref.next, clone = _ref.clone;
  api.stats = {};
  api.stats.timer = null;
  api.stats.pendingIncrements = {};
  api.stats._start = function(api, cb) {
    if (api.config.stats.writeFrequency > 0) {
      api.stats.timer = setTimeout(api.stats.writeIncrements, api.config.stats.writeFrequency);
    }
    return next(cb);
  };
  api.stats._stop = function(api, cb) {
    if (api.stats.timer != null) {
      clearTimeout(api.stats.timer);
      api.stats.timer = null;
    }
    return next(cb);
  };
  api.stats.increment = function(key, count) {
    var _base;
    if (count == null) {
      count = 1;
    }
    count = parseFloat(count);
    if ((_base = api.stats.pendingIncrements)[key] == null) {
      _base[key] = 0;
    }
    return api.stats.pendingIncrements[key] = api.stats.pendingIncrements[key] + count;
  };
  api.stats.writeIncrements = function(cb) {
    var multi, pendingIncrements;
    if (api.stats.timer != null) {
      clearTimeout(api.stats.timer);
      api.stats.timer = null;
    }
    if (api.config.stats.keys.length > 0 && Object.keys(api.stats.pendingIncrements).length > 0) {
      pendingIncrements = clone(api.stats.pendingIncrements);
      api.stats.pendingIncrements = {};
      multi = api.redis.client.multi();
      api.config.stats.keys.forEach(function(collection) {
        var key, value, _results;
        _results = [];
        for (key in pendingIncrements) {
          value = pendingIncrements[key];
          _results.push(multi.hincrby(collection, key, value));
        }
        return _results;
      });
      return multi.exec(function(err) {
        if (err != null) {
          api.log.error('Stats errors - writeIncrements', err);
        } else {
          api.stats.timer = setTimeout(api.stats.writeIncrements, api.config.stats.writeFrequency);
        }
        return next(cb, err);
      });
    } else {
      api.stats.timer = setTimeout(api.stats.writeIncrements, api.config.stats.writeFrequency);
      return next(cb);
    }
  };
  api.stats.get = function(key, collection, cb) {
    if (typeof collection === 'function') {
      cb = collection;
      collection = null;
    }
    if (collection == null) {
      collection = api.config.stats.keys[0];
    }
    return api.redis.client.hget(collection, key, function(err, value) {
      return next(cb, err, value);
    });
  };
  api.stats.getAll = function(collections, cb) {
    var multi, results;
    if (typeof collections === 'function') {
      cb = collections;
      collections = null;
    }
    if (collections == null) {
      collections = api.config.stats.keys;
    }
    results = {};
    if (collections.length === 0) {
      return next(cb, null, results);
    } else {
      multi = api.redis.client.multi();
      collections.forEach(function(collection) {
        return multi.hgetall(collection);
      });
      return multi.exec(function(err, data) {
        var i, _i, _ref1;
        if (err != null) {
          api.log.error('Stats errors - getAll', err);
          return next(cb, err);
        } else {
          for (i = _i = 0, _ref1 = data.length; 0 <= _ref1 ? _i < _ref1 : _i > _ref1; i = 0 <= _ref1 ? ++_i : --_i) {
            results[collections[i]] = data[i];
          }
          return next(cb, null, results);
        }
      });
    }
  };
  return next(cb);
};

exports.stats = stats;
