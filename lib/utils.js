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
  extend: require('xtend'),
  eql: require('deep-equal')
};
