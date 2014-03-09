var fs, getParams, next, path, tasks;

fs = require('fs');

path = require('path');

next = require('../utils').next;

getParams = function(taskName, params, queue, cb) {
  if (typeof queue === 'function') {
    cb = queue;
    queue = this.tasks[taskName].queue;
  } else if (typeof params === 'function') {
    cb = params;
    queue = this.tasks[taskName].queue;
    params = {};
  }
  return {
    params: params,
    queue: queue,
    cb: cb
  };
};

tasks = function(api, cb) {
  api.tasks = {
    tasks: {},
    jobs: {},
    _start: function(api, cb) {
      if (api.config.tasks.scheduler) {
        return api.tasks.enqueueAllRecurrentJobs(function() {
          return next(cb);
        });
      } else {
        return next(cb);
      }
    },
    load: function(fullFilePath) {
      var collection, i, loadMessage, self, task, _results;
      self = api.tasks;
      loadMessage = function(loadedTaskName) {
        return api.log.debug('task loaded:', loadedTaskName + ',', fullFilePath);
      };
      collection = require(fullFilePath);
      _results = [];
      for (i in collection) {
        task = collection[i];
        if (self.validateTask(task)) {
          api.tasks.tasks[task.name] = task;
          api.tasks.jobs[task.name] = self.jobWrapper(task.name);
          _results.push(loadMessage(task.name));
        } else {
          _results.push(void 0);
        }
      }
      return _results;
    },
    jobWrapper: function(taskName) {
      var pluginOptions, plugins, self, task, _ref, _ref1;
      self = api.tasks;
      task = api.tasks.tasks[taskName];
      plugins = (_ref = task.plugins) != null ? _ref : [];
      pluginOptions = (_ref1 = task.pluginOptions) != null ? _ref1 : [];
      if (task.frequency > 0) {
        if (plugins.indexOf('jobLock') < 0) {
          plugins.push('jobLock');
        }
        if (plugins.indexOf('queueLock') < 0) {
          plugins.push('queueLock');
        }
        if (plugins.indexOf('delayQueueLock') < 0) {
          plugins.push('delayQueueLock');
        }
      }
      return {
        'plugins': plugins,
        'pluginOptions': pluginOptions,
        'perform': function() {
          var args, error;
          args = Array.prototype.slice.call(arguments);
          cb = args.pop();
          error = null;
          if (args.length === 0) {
            args.push({});
          }
          args.push(function(res) {
            return self.enqueueRecurrentJob(taskName, function() {
              return cb(error, res);
            });
          });
          args.splice(0, 0, api);
          return api.tasks.tasks[taskName].run.apply(null, args);
        }
      };
    },
    validateTask: function(task) {
      var fail;
      fail = function(msg) {
        return api.log.error(msg + '; exiting.');
      };
      if (typeof task.name !== 'string' || task.name.length < 1) {
        fail("a task is missing 'task.name'");
        return false;
      } else if (typeof task.description !== 'string' || task.description.length < 1) {
        fail("Task " + task.name + " is missing 'task.description'");
        return false;
      } else if (typeof task.frequency !== 'number') {
        fail("Task " + task.name + " has no frequency");
        return false;
      } else if (typeof task.queue !== 'string') {
        fail("Task " + task.name + " has no queue");
        return false;
      } else if (typeof task.run !== 'function') {
        fail("Task " + task.name + " has no run method");
        return false;
      } else {
        return true;
      }
    },
    loadFolder: function(taskPath) {
      var self;
      self = api.tasks;
      if (taskPath == null) {
        taskPath = path.resolve(api.project_root, 'tasks');
      }
      if (fs.existsSync(taskPath)) {
        return fs.readdirSync(taskPath).forEach(function(file) {
          var ext, fullFilePath, realPath, stats;
          fullFilePath = path.join(taskPath, file);
          if (file[0] !== '.') {
            stats = fs.statSync(fullFilePath);
            if (stats.isDirectory()) {
              return self.loadFolder(fullFilePath);
            } else if (stats.isSymbolicLink()) {
              realPath = fs.readlinkSync(fullFilePath);
              return self.loadFolder(realPath);
            } else if (stats.isFile()) {
              ext = path.extname(file);
              if (ext === '.js' || ext === '.coffee' || ext === '.litcoffee') {
                return api.tasks.load(fullFilePath);
              }
            } else {
              return api.log.warn(file + ' is a type of file I cannot read');
            }
          }
        });
      } else {
        return api.log.debug('no tasks folder found, skipping');
      }
    },
    enqueue: function(taskName, params, queue, cb) {
      var res;
      res = getParams.call(api.tasks, taskName, params, queue, cb);
      return api.resque.queue.enqueue(res.queue, taskName, res.params, res.cb);
    },
    enqueueAt: function(timestamp, taskName, params, queue, cb) {
      var res;
      res = getParams.call(api.tasks, taskName, params, queue, cb);
      return api.resque.queue.enqueueAt(timestamp, res.queue, taskName, res.params, res.cb);
    },
    enqueueIn: function(time, taskName, params, queue, cb) {
      var res;
      res = getParams.call(api.tasks, taskName, params, queue, cb);
      return api.resque.queue.enqueueIn(time, res.queue, taskName, res.params, res.cb);
    },
    del: function(q, taskName, args, count, cb) {
      return api.resque.queue.del(q, taskName, args, count, cb);
    },
    delDelayed: function(q, taskName, args, cb) {
      return api.resque.queue.delDelayed(q, taskName, args, cb);
    },
    enqueueRecurrentJob: function(taskName, cb) {
      var self, task;
      self = api.tasks;
      task = self.tasks[taskName];
      if (task.frequency <= 0) {
        return next(cb);
      } else {
        return self.del(task.queue, taskName, {}, function() {
          return self.delDelayed(task.queue, taskName, {}, function() {
            return self.enqueueIn(task.frequency, taskName, function() {
              api.log.debug('re-enqueued recurrent job', taskName);
              return next(cb);
            });
          });
        });
      }
    },
    enqueueAllRecurrentJobs: function(cb) {
      var loadedTasks, self, started, task, taskName;
      self = api.tasks;
      started = 0;
      loadedTasks = [];
      for (taskName in self.tasks) {
        task = self.tasks[taskName];
        if (task.frequency > 0) {
          started++;
          (function(taskName) {
            return self.enqueue(taskName, function(err, toRun) {
              if (toRun) {
                api.log.info('enqueuing periodic task:', taskName);
                loadedTasks.push(taskName);
              }
              started--;
              if (started === 0) {
                return next(cb(loadedTasks));
              }
            });
          })(taskName);
        }
      }
      if (started === 0) {
        return next(cb(loadedTasks));
      }
    },
    stopRecurrentJob: function(taskName, cb) {
      var removedCount, self, task;
      self = api.tasks;
      task = self.tasks[taskName];
      if (task.frequency <= 0) {
        return next(cb);
      } else {
        removedCount = 0;
        return self.del(task.queue, task.name, {}, 1, function(err, count) {
          removedCount = removedCount + count;
          return self.delDelayed(task.queue, task.name, {}, function(err, timestamps) {
            removedCount = removedCount + timestamps.length;
            return next(cb, err, removedCount);
          });
        });
      }
    },
    details: function(cb) {
      var details, self;
      self = api.tasks;
      details = {
        queues: {}
      };
      return api.resque.queue.queues(function(err, queues) {
        var started;
        if (queues.length === 0) {
          return next(cb, null, details);
        } else {
          started = 0;
          return queues.forEach(function(queue) {
            started++;
            return api.resque.queue.length(queue, function(err, length) {
              details['queues'][queue] = {
                length: length
              };
              started--;
              if (started === 0) {
                return next(cb, null, details);
              }
            });
          });
        }
      });
    }
  };
  api.tasks.loadFolder();
  return next(cb);
};

exports.tasks = tasks;
