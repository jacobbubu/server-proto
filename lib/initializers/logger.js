var ConsoleBackend, Minilog, eql, extend, fs, logger, next, path;

fs = require('fs');

path = require('path');

Minilog = require('Minilog');

ConsoleBackend = require('Minilog').backends.console;

next = require('../utils').next;

eql = require('../utils').eql;

extend = require('../utils').extend;

logger = function(api, cb) {
  api.logger = {
    _init: function() {
      api.logger._buildLogger(api.config.configData.logger);
      return api.config.on('change', api.logger._configListener);
    },
    _buildLogger: function(config) {
      var e, message, myFilter, options, stream;
      try {
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
        return api.log = logger;
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
    _configListener: function(data) {
      var newConfig;
      newConfig = data.logger;
      if (!(eql(newConfig, api.config.configData.logger))) {
        return api.logger._buildLogger(newConfig);
      }
    },
    _teardown: function(api, cb) {
      api.config.removeListener('change', api.logger._configListener);
      return next(cb);
    }
  };
  api.logger._init();
  return next(cb);
};

module.exports.logger = logger;
