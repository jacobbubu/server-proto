var ConsoleBackend, Minilog, fs, logger, path;

fs = require('fs');

path = require('path');

Minilog = require('minilog');

ConsoleBackend = require('minilog').backends.console;

logger = function(api, cb) {
  var eql, extend, next, _ref;
  _ref = api.utils, next = _ref.next, eql = _ref.eql, extend = _ref.extend;
  api.logger = {
    enabled: false,
    _init: function() {
      api.logger.enable();
      return api.configObj.on('change', api.logger._configListener);
    },
    enable: function() {
      var config, e, message, myFilter, options, stream;
      if (api.logger.enabled) {
        return;
      }
      try {
        config = api.config.logger;
        logger = Minilog(config.scope);
        Minilog.unpipe();
        if (config.console != null) {
          options = extend({
            theme: 'formatMinilog',
            'filter-name': '.*',
            'filter-level': 'debug'
          }, config.console);
          if (options.theme in ConsoleBackend) {
            myFilter = new Minilog.Filter();
            myFilter.deny(new RegExp(options['filter-name']), options['filter-level']);
            Minilog.pipe(myFilter).pipe(ConsoleBackend[options.theme]).pipe(ConsoleBackend);
          } else {
            throw new Error("Formatter '" + options.theme + "' does not exist");
          }
        }
        if (config.file != null) {
          options = extend({
            'filter-name': '.*',
            'filter-level': 'debug'
          }, config.file);
          myFilter = new Minilog.Filter();
          myFilter.deny(new RegExp(options['filter-name']), options['filter-level']);
          stream = fs.createWriteStream(path.resolve(api.project_root, config.file));
          stream.on('error', function(err) {
            if (api.log != null) {
              return api.log.error('Write log file errors', err);
            }
          });
          Minilog.pipe(myFilter).pipe(stream);
        }
        api.log = logger;
        return api.logger.enabled = true;
      } catch (_error) {
        e = _error;
        message = 'Build api.log errors';
        if (api.log != null) {
          api.log.error(message, e);
        } else {
          console.error(message, e);
        }
        return process.exit(1);
      }
    },
    disable: function() {
      if (api.logger.enabled) {
        logger = Minilog();
        Minilog.unpipe();
        api.log = logger;
        return api.logger.enabled = false;
      }
    },
    _configListener: function(data) {
      var newConfig;
      newConfig = data.logger;
      if (!(eql(newConfig, api.config.logger))) {
        return api.logger._buildLogger(newConfig);
      }
    },
    _stop: function(api, cb) {
      api.configObj.removeListener('change', api.logger._configListener);
      return next(cb);
    }
  };
  api.logger._init();
  return next(cb);
};

module.exports.logger = logger;
