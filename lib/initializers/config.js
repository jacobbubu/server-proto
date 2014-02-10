var CSON, Config, EventEmitter, config, eql, extend, fs, inherits, next, path;

fs = require('fs');

path = require('path');

CSON = require('cson');

EventEmitter = require('events').EventEmitter;

inherits = require('util').inherits;

eql = require('../utils').eql;

extend = require('../utils').extend;

next = require('../utils').next;

Config = (function() {
  function Config(api) {
    var configData, e, self;
    self = this;
    self.options = api._startingOptions.config;
    self.options.file = path.resolve(api.project_root, self.options.file);
    EventEmitter.call(self);
    self.setMaxListeners(Infinity);
    try {
      configData = CSON.parseFileSync(self.options.file);
    } catch (_error) {
      e = _error;
      throw new Error("Bad config data - " + self.options.file);
      proces.exit(1);
    }
    self.configData = extend(api._defaultConfig, configData);
    if (self.options.watch) {
      self.fsWatcher = fs.watch(self.options.file, {
        persistent: true
      }, function(event) {
        if (event === 'change') {
          return CSON.parseFile(self.options.file, function(err, data) {
            if (err != null) {
              return api.log.error("Bad config data - " + self.options.file, err);
            } else {
              configData = extend(api._defaultConfig, data);
              if (!eql(self.configData, configData)) {
                self.emit('change', configData);
                self.configData = configData;
                return api.log.info("Config data changed - " + self.options.file);
              }
            }
          });
        }
      });
    }
  }

  return Config;

})();

inherits(Config, EventEmitter);

Config.prototype._teardown = function(api, cb) {
  var self;
  self = this;
  if (self.fsWatcher != null) {
    self.fsWatcher.close();
    self.fsWatcher = null;
  }
  return next(cb);
};

config = function(api, cb) {
  var file;
  file = path.resolve(api.project_root, api._startingOptions.config.file);
  if (!fs.existsSync(file)) {
    throw new Error("No config file found - " + file);
    proces.exit(1);
  }
  api.config = new Config(api);
  return next(cb);
};

module.exports.config = config;
