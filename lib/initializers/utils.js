var internalUtils, noop, utils;

internalUtils = require('../utils');

noop = function() {};

utils = function(api, cb) {
  var k, v;
  if (cb == null) {
    cb = noop;
  }
  api.utils = {};
  for (k in internalUtils) {
    v = internalUtils[k];
    api.utils[k] = v;
  }
  return cb();
};

module.exports.utils = utils;
