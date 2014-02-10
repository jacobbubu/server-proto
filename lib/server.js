var ServerProto, async, defaultOptions, extend, fs, hasFunc, next, path, _ref, _ref1;

fs = require('fs');

path = require('path');

async = require('async');

extend = require('./utils').extend;

next = require('./utils').next;

hasFunc = require('./utils').hasFunc;

defaultOptions = {
  config: {
    file: 'config.cson',
    watch: true
  },
  project_root: (_ref = process.env.project_root) != null ? _ref : (_ref1 = process.env.PROJECT_ROOT) != null ? _ref1 : process.cwd()
};

ServerProto = (function() {
  function ServerProto() {
    var self;
    self = this;
    self.initalizers = {};
    self.api = {
      running: false,
      initialized: false,
      shuttingDown: false
    };
  }

  ServerProto.prototype.initialize = function(options, cb) {
    var folder, initializerFolders, initializerMethods, orderedInitializers, self, _i, _len;
    if (cb == null) {
      options = {};
      cb = options;
    }
    self = this;
    self.startingOptions = self.api._startingOptions = extend(defaultOptions, options);
    self.api.project_root = self.startingOptions.project_root;
    self.api._defaultConfig = require('./default-config');
    initializerFolders = [__dirname + '/initializers/', path.resolve(self.api.project_root, 'initializers/')];
    initializerMethods = [];
    for (_i = 0, _len = initializerFolders.length; _i < _len; _i++) {
      folder = initializerFolders[_i];
      if (fs.existsSync(folder)) {
        fs.readdirSync(folder).sort().forEach(function(file) {
          var ext, initalizer, requireKey, _ref2;
          if (file[0] !== '.') {
            _ref2 = file.split('.'), initalizer = _ref2[0], ext = _ref2[1];
            if (ext === 'js' || ext === '.coffee' || ext === '.litcoffee' || ext === '.coffee.md') {
              requireKey = path.join(folder, file);
              if (require.cache[requireKey] != null) {
                delete require.cache[require.resolve(requireKey)];
              }
              initializerMethods.push(initalizer);
              return self.initalizers[initalizer] = require(requireKey)[initalizer];
            }
          }
        });
      }
    }
    orderedInitializers = {};
    ['config', 'logger'].forEach(function(i) {
      return orderedInitializers[i] = function(cb) {
        return self.initalizers[i](self.api, cb);
      };
    });
    initializerMethods.forEach(function(method) {
      if (typeof orderedInitializers[method] !== 'function') {
        return orderedInitializers[method] = function(cb) {
          return self.initalizers[method](self.api, cb);
        };
      }
    });
    orderedInitializers['_complete'] = function() {
      self.appName = self.api.config.configData.appName;
      self.api.initialized = true;
      return next(cb, null, self.api);
    };
    return async.series(orderedInitializers);
  };

  ServerProto.prototype.start = function(options, cb) {
    var doStart, self;
    self = this;
    doStart = function() {
      var obj, orderedStarters, starter, _ref2;
      orderedStarters = {};
      _ref2 = self.api;
      for (starter in _ref2) {
        obj = _ref2[starter];
        if (hasFunc(obj, '_start') && (orderedStarters[starter] == null)) {
          (function(name) {
            return orderedStarters[name] = function(cb) {
              return self.api[name]._start(self.api, function() {
                self.api.log.debug("initializer '" + name + "' started");
                return cb();
              });
            };
          })(starter);
        }
      }
      orderedStarters['_complete'] = function() {
        self.api.log.info("'" + self.appName + "' has been started");
        self.api.running = true;
        return next(cb, null, self.api);
      };
      return async.series(orderedStarters);
    };
    if (self.api.initialized) {
      return doStart();
    } else {
      return self.initialize(options, function(err) {
        return doStart();
      });
    }
  };

  ServerProto.prototype.stop = function(cb) {
    var obj, orderedTeardowns, self, terdown, _ref2;
    self = this;
    if (self.api.running) {
      self.api.shuttingDown = true;
      self.api.running = false;
      self.api.initialized = false;
      self.api.log.warn('shutting down open servers');
      orderedTeardowns = {};
      ['config'].forEach(function(terdown) {
        if (hasFunc(self.api[terdown], '_teardown')) {
          return (function(name) {
            return orderedTeardowns[name] = function(cb) {
              return self.api[name]._teardown(self.api, cb);
            };
          })(terdown);
        }
      });
      _ref2 = self.api;
      for (terdown in _ref2) {
        obj = _ref2[terdown];
        if (hasFunc(obj, '_teardown') && (orderedTeardowns[terdown] == null)) {
          (function(name) {
            return orderedTeardowns[name] = function(cb) {
              return self.api[name]._teardown(self.api, cb);
            };
          })(terdown);
        }
      }
      orderedTeardowns['_complete'] = function() {
        self.api.log.info("'" + self.appName + "' has been stopped");
        self.api.log.debug('***');
        delete self.api.shuttingDown;
        return next(cb);
      };
      return async.series(orderedTeardowns);
    } else if (self.api.shuttingDown) {

    } else {
      self.api.log.info('Cannot shut down (not running any servers)');
      return next(cb, null, self.api);
    }
  };

  return ServerProto;

})();

module.exports = ServerProto;
