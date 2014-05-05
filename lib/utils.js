var clone;

clone = function(obj) {
  var flags, key, newInstance;
  if ((obj == null) || typeof obj !== 'object') {
    return obj;
  }
  if (obj instanceof Date) {
    return new Date(obj.getTime());
  }
  if (obj instanceof RegExp) {
    flags = '';
    if (obj.global != null) {
      flags += 'g';
    }
    if (obj.ignoreCase != null) {
      flags += 'i';
    }
    if (obj.multiline != null) {
      flags += 'm';
    }
    if (obj.sticky != null) {
      flags += 'y';
    }
    return new RegExp(obj.source, flags);
  }
  newInstance = new obj.constructor();
  for (key in obj) {
    newInstance[key] = clone(obj[key]);
  }
  return newInstance;
};

module.exports = {
  next: function(cb, err, res) {
    if (typeof cb === 'function') {
      return cb(err, res);
    }
  },
  hasFunc: function(obj, func) {
    if (obj != null) {
      return typeof obj[func] === 'function' || typeof obj.__proto__[func] === 'function';
    } else {
      return false;
    }
  },
  listen: function() {
    var args, cb, server, _ref;
    args = Array.prototype.slice.call(arguments);
    server = args.splice(0, 1)[0];
    cb = (_ref = args.slice(-1)[0]) != null ? _ref : function() {};
    server.once('error', function(err) {
      if ((err.code != null) && err.code === 'EADDRINUSE') {
        return cb(err);
      }
    });
    return server.listen.apply(server, args);
  },
  clone: clone,
  errStack: function(err) {
    if ((err != null ? err.stack : void 0) != null) {
      return err.stack;
    } else {
      return err;
    }
  },
  extend: require('xtend'),
  eql: require('deep-equal'),
  Q: require('q'),
  uuid: (require('uuid')).v4,
  humanInterval: require('human-interval'),
  async: require('async'),
  _: require('lodash')
};
