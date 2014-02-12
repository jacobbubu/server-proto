var actions, fs, next, path;

fs = require('fs');

path = require('path');

next = require('../utils').next;

actions = function(api, cb) {
  api.actions = {
    preProcessors: [],
    postProcessors: [],
    map: {}
  };
  api.actions.loadActionFile = function(file) {
    var actionBase, actionName, innerFunc, key, _ref, _results;
    actionBase = path.basename(file).split('.')[0];
    _ref = require(file);
    _results = [];
    for (key in _ref) {
      innerFunc = _ref[key];
      if (typeof innerFunc === 'function') {
        actionName = [actionBase, key].join('.');
        if (api.actions.map[actionName] != null) {
          _results.push(api.log.warn("Action (" + actionName + ") already exist"));
        } else {
          _results.push((function(name, func) {
            return api.actions.map[name] = function() {
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
          })(actionName, innerFunc));
        }
      } else {
        _results.push(void 0);
      }
    }
    return _results;
  };
  api.actions.loadAllActions = (function() {
    var loadFolder, uniquefolders;
    loadFolder = function(folder) {
      if (fs.existsSync(folder)) {
        return fs.readdirSync(folder).forEach(function(file) {
          var action, ext, fullFilePath, realPath, requireKey, stats;
          fullFilePath = path.join(folder, file);
          stats = fs.statSync(fullFilePath);
          if (stats.isDirectory()) {
            return loadFolder(fullFilePath);
          } else if (stats.isSymbolicLink()) {
            realPath = fs.readlinkSync(fullFilePath);
            return loadFolder(realPath);
          } else if (stats.isFile()) {
            ext = path.extname(file);
            action = path.basename(file, ext);
            if (ext === '.js' || ext === '.coffee' || ext === '.litcoffee') {
              requireKey = fullFilePath;
              return api.actions.loadActionFile(requireKey);
            }
          } else {
            return api.log.error(file + 'is a type of file I cannot read');
          }
        });
      }
    };
    uniquefolders = {};
    uniquefolders[path.resolve(__dirname, '../actions/')] = true;
    uniquefolders[path.resolve(api.project_root, 'actions/')] = true;
    return Object.keys(uniquefolders).forEach(loadFolder);
  })();
  return next(cb);
};

module.exports.actions = actions;
