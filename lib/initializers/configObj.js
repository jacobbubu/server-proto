var ConfigObj, EventEmitter, configObj, eql, extend, fs, inherits, next, path, period,
  __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

require('coffee-script/register');

fs = require('fs');

path = require('path');

EventEmitter = require('events').EventEmitter;

inherits = require('util').inherits;

eql = null;

extend = null;

next = null;

period = 3000;

ConfigObj = (function() {
  function ConfigObj(api) {
    var self;
    self = this;
    self.options = api._startingOptions.config;
    self.file = path.resolve(api.project_root, self.options.file);
    self.fileTypes = ['.js', '.coffee', '.litcoffee'];
    self.watcherId = null;
    self.mtime = 0;
    EventEmitter.call(self);
    self.setMaxListeners(Infinity);
  }

  return ConfigObj;

})();

inherits(ConfigObj, EventEmitter);

ConfigObj.prototype.loadConfig = function(api, file, cb) {
  var self, _ref;
  self = this;
  if (_ref = path.extname(file), __indexOf.call(this.fileTypes, _ref) >= 0) {
    return fs.stat(file, function(err, stats) {
      var config, e;
      if (err != null) {
        return next(cb, err);
      }
      if (stats.isSymbolicLink()) {
        return fs.readlinkSync(file, function(err, realPath) {
          if (err != null) {
            return next(cb, err);
          }
          return self.loadConfig(api, realPath, cb);
        });
      } else if (stats.isFile()) {
        if (require.cache[file] != null) {
          delete require.cache[file];
        }
        try {
          config = require(file).config;
        } catch (_error) {
          e = _error;
          next(cb, ("" + file + " is not a valid config file-") + e);
          self.mtime = stats.mtime.getTime();
          return;
        }
        self.mtime = stats.mtime.getTime();
        return next(cb, null, extend(api._defaultConfig, config));
      } else {
        return next(cb, "" + file + " is not a valid config file");
      }
    });
  } else {
    return next(cb, "Config file type should be in " + self.fileTypes);
  }
};

ConfigObj.prototype.periodicCheck = function(api) {
  var checkDone, self;
  self = this;
  self.watcherId = null;
  checkDone = function() {
    return self.watcherId = setTimeout(function() {
      return self.periodicCheck(api);
    }, period);
  };
  return fs.stat(self.file, function(err, stats) {
    if (err != null) {
      api.log.error("reading " + self.file + " errors", err);
      return checkDone();
    }
    if (self.mtime !== stats.mtime.getTime()) {
      return self.loadConfig(api, self.file, function(err, config) {
        if (err != null) {
          api.log.error("bad config data - " + self.file + " - " + err);
        } else {
          if (!eql(api.config, config)) {
            self.emit('change', config);
            api.config = config;
            api.log.info("config data changed - " + self.file);
          }
        }
        return checkDone();
      });
    } else {
      return checkDone();
    }
  });
};

ConfigObj.prototype._stop = function(api, cb) {
  if (this.watcherId != null) {
    clearTimeout(this.watcherId);
    this.watcherId = null;
  }
  return next(cb);
};

configObj = function(api, cb) {
  var file, _ref;
  _ref = api.utils, eql = _ref.eql, extend = _ref.extend, next = _ref.next;
  file = path.resolve(api.project_root, api._startingOptions.config.file);
  if (!fs.existsSync(file)) {
    return next(cb, "No config file found - " + file);
  }
  api.configObj = new ConfigObj(api);
  return api.configObj.loadConfig(api, api.configObj.file, function(err, config) {
    if (err != null) {
      return next(cb, 'config file loading failed', err);
    } else {
      if (api.configObj.options.watch) {
        api.configObj.watcherId = setTimeout(function() {
          return api.configObj.periodicCheck(api);
        }, period);
      }
      api.config = config;
      return next(cb, null, config);
    }
  });
};

module.exports.configObj = configObj;
