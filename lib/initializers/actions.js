var actions, fs, path;

fs = require('fs');

path = require('path');

actions = function(api, cb) {
  var e, errStack, next, _, _ref;
  _ref = api.utils, next = _ref.next, _ = _ref._, errStack = _ref.errStack;
  api.actions = {
    preProcessors: [],
    postProcessors: [],
    map: {}
  };
  api.actions.loadActionFile = function(file) {
    var actionBase, actionName, e, innerFunc, key, _ref1, _results;
    actionBase = path.basename(file).split('.')[0];
    try {
      _ref1 = require(file);
      _results = [];
      for (key in _ref1) {
        innerFunc = _ref1[key];
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
    } catch (_error) {
      e = _error;
      api.log.error('loading action file errors', file);
      throw e;
    }
  };
  api.actions.loadAllActions = function() {
    var loadFolder;
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
              return api.actions.loadActionFile(requireKey);
            }
          } else {
            return api.log.error(file + 'is a type of file I cannot read');
          }
        });
      }
    };
    return _.uniq([path.resolve(__dirname, '../actions/'), path.resolve(api.project_root, 'actions/')]).forEach(loadFolder);
  };
  try {
    api.actions.loadAllActions();
    return next(cb);
  } catch (_error) {
    e = _error;
    return next(cb, errStack(e));
  }
};

module.exports.actions = actions;
