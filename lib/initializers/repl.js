var repl, replify;

replify = require('replify');

repl = function(api, cb) {
  var next;
  next = api.utils.next;
  api.repl = {};
  api.repl._start = function(api, cb) {
    api.repl.replServer = replify(api.config.appName, api);
    return next(cb);
  };
  api.repl._stop = function(api, cb) {
    api.repl.replServer.close();
    return next(cb);
  };
  return next(cb);
};

exports.repl = repl;
