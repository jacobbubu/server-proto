var fs, next, path, pids;

fs = require('fs');

path = require('path');

next = require('../utils').next;

pids = function(api, cb) {
  var e;
  api.pids = {};
  api.pids.pid = process.pid;
  api.pids.title = api.config.appName;
  api.pids.file = path.join(api.config.pid, api.pids.title + '.pid');
  try {
    fs.mkdirSync(api.config.pid, '0777');
  } catch (_error) {
    e = _error;
  }
  api.pids.writePidFile = function() {
    return fs.writeFileSync(api.pids.file, api.pids.pid.toString(), {
      encoding: 'ascii'
    });
  };
  api.pids.readPidFile = function() {
    var pid;
    try {
      pid = fs.readFileSync(api.pids.file, {
        encoding: 'ascii'
      });
      pid = Number(pid);
    } catch (_error) {
      e = _error;
      if (e.code === 'ENOENT') {
        pid = 0;
      } else {
        api.log.error('read pidfile failed', e);
        process.exit(1);
      }
    }
    return pid;
  };
  api.pids.clearPidFile = function() {
    try {
      return fs.unlinkSync(api.pids.file);
    } catch (_error) {
      e = _error;
      return api.log.error('unable to remove pidfile', e);
    }
  };
  api.pids._start = function(api, cb) {
    try {
      api.pids.writePidFile();
    } catch (_error) {
      e = _error;
      api.log.error('write pid file failed', e);
      process.exit(1);
    }
    api.log.info('pid:', process.pid);
    return next(cb);
  };
  return next(cb);
};

exports.pids = pids;
