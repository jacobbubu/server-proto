var ConfigObj, EventEmitter, configObj, eql, extend, fs, inherits, next, path,
  __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

require('coffee-script/register');

fs = require('fs');

path = require('path');

EventEmitter = require('events').EventEmitter;

inherits = require('util').inherits;

eql = require('../utils').eql;

extend = require('../utils').extend;

next = require('../utils').next;

ConfigObj = (function() {
  function ConfigObj(api) {
    var e, self;
    self = this;
    self.options = api._startingOptions.config;
    self.options.file = path.resolve(api.project_root, self.options.file);
    self.fileTypes = ['.js', '.coffee', '.litcoffee'];
    EventEmitter.call(self);
    self.setMaxListeners(Infinity);
    try {
      api.config = self.loadConfig(api, self.options.file);
    } catch (_error) {
      e = _error;
      throw new Error("Bad config data - " + self.options.file + " - " + e);
      proces.exit(1);
    }
    if (self.options.watch) {
      self.fsWatcher = fs.watch(self.options.file, {
        persistent: true
      }, function(event) {
        var newConfig;
        if (event === 'change') {
          try {
            newConfig = self.loadConfig(api, self.options.file);
            if (!eql(api.config, newConfig)) {
              self.emit('change', newConfig);
              api.config = newConfig;
              return api.log.info("Config data changed - " + self.options.file);
            }
          } catch (_error) {
            e = _error;
            return api.log.error("Bad config data - " + self.options.file + " - " + e);
          }
        }
      });
    }
  }

  return ConfigObj;

})();

inherits(ConfigObj, EventEmitter);

ConfigObj.prototype.loadConfig = function(api, file) {
  var config, self, _ref;
  self = this;
  if (_ref = path.extname(file), __indexOf.call(this.fileTypes, _ref) >= 0) {
    if (require.cache[file] != null) {
      delete require.cache[file];
    }
    config = require(file).config;
    return extend(api._defaultConfig, config);
  } else {
    throw new Error("Config file type should be in " + self.fileTypes);
  }
};

ConfigObj.prototype._stop = function(api, cb) {
  var self;
  self = this;
  if (self.fsWatcher != null) {
    self.fsWatcher.close();
    self.fsWatcher = null;
  }
  return next(cb);
};

configObj = function(api, cb) {
  var file;
  file = path.resolve(api.project_root, api._startingOptions.config.file);
  if (!fs.existsSync(file)) {
    throw new Error("No config file found - " + file);
    proces.exit(1);
  }
  api.configObj = new ConfigObj(api);
  return next(cb);
};

module.exports.configObj = configObj;
