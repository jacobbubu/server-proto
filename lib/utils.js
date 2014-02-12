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
  clone: clone,
  extend: require('xtend'),
  eql: require('deep-equal')
};
