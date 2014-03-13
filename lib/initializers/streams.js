var fs, next, path, streams;

fs = require('fs');

path = require('path');

next = require('../utils').next;

streams = function(api, cb) {
  next = api.utils.next;
  api.streams = {};
  api.streams.map = {};
  api.streams.loadStreamFile = function(file) {
    var e, innerFunc, streamName, _ref, _results;
    try {
      _ref = require(file);
      _results = [];
      for (streamName in _ref) {
        innerFunc = _ref[streamName];
        if (typeof innerFunc === 'function') {
          if (api.streams.map[streamName] != null) {
            _results.push(api.log.warn("Stream (" + streamName + ") already exist"));
          } else {
            _results.push((function(name, func) {
              return api.streams.map[name] = function() {
                var e;
                try {
                  return func.apply(this, arguments);
                } catch (_error) {
                  e = _error;
                  cb = arguments[arguments.length - 1];
                  if (typeof cb === 'function') {
                    return cb(e);
                  }
                }
              };
            })(streamName, innerFunc));
          }
        } else {
          _results.push(void 0);
        }
      }
      return _results;
    } catch (_error) {
      e = _error;
      api.log.error('loading stream file errors', e, file);
      return cb(e);
    }
  };
  api.streams.loadAllStreams = (function() {
    var loadFolder, uniquefolders;
    loadFolder = function(folder) {
      if (fs.existsSync(folder)) {
        return fs.readdirSync(folder).forEach(function(file) {
          var ext, fullFilePath, realPath, requireKey, stats;
          fullFilePath = path.join(folder, file);
          stats = fs.statSync(fullFilePath);
          if (stats.isDirectory()) {
            return loadFolder(fullFilePath);
          } else if (stats.isSymbolicLink()) {
            realPath = fs.readlinkSync(fullFilePath);
            return loadFolder(realPath);
          } else if (stats.isFile()) {
            ext = path.extname(file);
            if (ext === '.js' || ext === '.coffee' || ext === '.litcoffee') {
              requireKey = fullFilePath;
              return api.streams.loadStreamFile(requireKey);
            }
          } else {
            return api.log.error(file + 'is a type of file I cannot read');
          }
        });
      }
    };
    uniquefolders = {};
    uniquefolders[path.resolve(__dirname, '../streams/')] = true;
    uniquefolders[path.resolve(api.project_root, 'streams/')] = true;
    return Object.keys(uniquefolders).forEach(loadFolder);
  })();
  return next(cb);
};

module.exports.streams = streams;
