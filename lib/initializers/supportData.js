var InnerEvents, events, fs, path, supportData, util;

fs = require('fs');

path = require('path');

events = require('events');

util = require('util');

InnerEvents = (function() {
  function InnerEvents() {
    events.EventEmitter.call(this);
  }

  return InnerEvents;

})();

util.inherits(InnerEvents, events.EventEmitter);

supportData = function(api, cb) {
  var async, e, errStack, humanInterval, interval, next, _, _ref, _ref1, _ref2;
  _ref = api.utils, next = _ref.next, _ = _ref._, humanInterval = _ref.humanInterval, errStack = _ref.errStack, async = _ref.async;
  api.supportData = {};
  interval = (_ref1 = (_ref2 = api.config.supportData) != null ? _ref2.interval : void 0) != null ? _ref1 : '30 seconds';
  if (typeof interval === 'string') {
    api.supportData.interval = humanInterval(interval);
  }
  api.supportData._store = {};
  api.supportData.events = new InnerEvents;
  api.supportData.getData = function(api, key) {
    var _ref3;
    return (_ref3 = api.supportData._store[key]) != null ? _ref3.data : void 0;
  };
  api.supportData.getObject = function(api, key) {
    return api.supportData._store[key];
  };
  api.supportData.periodicCheck = function() {
    return setTimeout(function() {
      var keys;
      keys = Object.keys(api.supportData._store);
      return async.each(keys, function(key, cb) {
        var value;
        value = api.supportData._store[key];
        return fs.stat(value.file, function(err, stats) {
          var e, mtime;
          if (err != null) {
            api.log.error("support data(" + key + ") file missing.", err, value.file);
            return cb(err);
          } else {
            mtime = stats.mtime.getTime();
            if (value.mtime !== mtime) {
              delete require.cache[value.file];
              try {
                value.data = require(value.file);
                api.log.debug("support data(" + key + ") changed.");
                api.supportData.events.emit(key, value.data);
              } catch (_error) {
                e = _error;
                api.log.error("support data(" + key + ") file errors.", errStack(e, value.file));
              }
              value.mtime = mtime;
            }
            return cb();
          }
        });
      }, function(err) {
        return api.supportData.periodicCheck();
      });
    }, api.supportData.interval);
  };
  api.supportData.loadDataFile = function(file, stats) {
    var e, key, value;
    key = path.basename(file).split('.')[0];
    try {
      value = {
        file: file,
        key: key,
        data: require(file),
        mtime: stats.mtime.getTime()
      };
      return api.supportData._store[key] = value;
    } catch (_error) {
      e = _error;
      api.log.error('loading support data errors', file);
      throw e;
    }
  };
  api.supportData.loadAllData = function() {
    var folders, loadFolder, _ref3;
    loadFolder = function(folder) {
      if (fs.existsSync(folder)) {
        return fs.readdirSync(folder).forEach(function(file) {
          var ext, fullFilePath, realPath, stats;
          fullFilePath = path.join(folder, file);
          stats = fs.statSync(fullFilePath);
          if (stats.isDirectory()) {
            return loadFolder(fullFilePath);
          } else if (stats.isSymbolicLink()) {
            realPath = fs.readlinkSync(fullFilePath);
            return loadFolder(realPath);
          } else if (stats.isFile()) {
            ext = path.extname(file);
            if (ext === '.js' || ext === '.coffee' || ext === '.litcoffee' || ext === '.json') {
              return api.supportData.loadDataFile(fullFilePath, stats);
            }
          } else {
            return api.log.error(file + 'is a type of file I cannot read');
          }
        });
      }
    };
    folders = [path.resolve(__dirname, '../../supportData/'), path.resolve(api.project_root, '../supportData/')];
    if (((_ref3 = api.config.supportData) != null ? _ref3.folder : void 0) != null) {
      folders.push(path.resolve(api.project_root, api.config.supportData.folder));
    }
    return _.uniq(folders).forEach(loadFolder);
  };
  try {
    api.supportData.loadAllData();
    api.supportData.periodicCheck();
    return next(cb);
  } catch (_error) {
    e = _error;
    return next(cb, errStack(e));
  }
};

module.exports.supportData = supportData;
