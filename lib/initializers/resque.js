var NR, clone, next, os, resque;

os = require('os');

NR = require('node-resque');

next = require('../utils').next;

clone = require('../utils').clone;

resque = function(api, cb) {
  api.resque = {
    queue: null,
    workers: [],
    scheduler: null,
    connectionDetails: api.config.tasks.redis != null ? clone(api.config.tasks.redis) : {},
    _start: function(api, cb) {
      var self;
      self = this;
      return self.startQueue(function() {
        return self.startScheduler(function() {
          return self.startWorkers(function() {
            return next(cb);
          });
        });
      });
    },
    _stop: function(api, cb) {
      var self;
      self = this;
      return self.stopScheduler(function() {
        return self.stopWorkers(function() {
          return self.queue.end(function() {
            return next(cb);
          });
        });
      });
    },
    startQueue: function(cb) {
      var self;
      self = this;
      return self.queue = new NR.queue({
        connection: self.connectionDetails
      }, api.tasks.jobs, function() {
        return next(cb);
      });
    },
    startScheduler: function(cb) {
      var self;
      self = this;
      if (api.config.tasks.scheduler) {
        return self.scheduler = new NR.scheduler({
          connection: self.connectionDetails,
          timeout: api.config.tasks.timeout
        }, function() {
          self.scheduler.on('start', function() {
            return api.log.info('resque scheduler started');
          });
          self.scheduler.on('end', function() {
            return api.log.info('resque scheduler ended');
          });
          self.scheduler.on('working_timestamp', function(timestamp) {
            return api.log.debug('resque scheduler working timestamp', timestamp);
          });
          self.scheduler.on('transferred_job', function(timestamp, job) {
            return api.log.debug('resque scheduler enqueuing job', timestamp, job);
          });
          self.scheduler.start();
          return process.nextTick(function() {
            return next(cb);
          });
        });
      } else {
        return next(cb);
      }
    },
    stopScheduler: function(cb) {
      var self;
      self = this;
      if (self.scheduler == null) {
        return next(cb);
      } else {
        return self.scheduler.end(function() {
          delete self.scheduler;
          return next(cb);
        });
      }
    },
    startWorkers: function(cb) {
      var i, self, started, _results;
      self = this;
      i = 0;
      started = 0;
      if ((api.config.tasks.queues == null) || api.config.tasks.queues.length === 0) {
        return next(cb);
      } else {
        _results = [];
        while (i < api.config.tasks.queues.length) {
          (function(i) {
            var name, timeout, worker;
            timeout = api.config.tasks.timeout;
            name = os.hostname() + ':' + process.pid + '+' + (i + 1);
            return worker = new NR.worker({
              connection: self.connectionDetails,
              name: name,
              queues: api.config.tasks.queues[i],
              timeout: timeout
            }, api.tasks.jobs, function() {
              worker.on('start', function() {
                return api.log.info('resque worker #' + (i + 1) + ' started (queues: ' + worker.options.queues + ')');
              });
              worker.on('end', function() {
                return api.log.info('resque worker #' + (i + 1) + ' ended');
              });
              worker.on('cleaning_worker', function(worker, pid) {
                return api.log.info('resque cleaning old worker ', worker);
              });
              worker.on('job', function(queue, job) {
                return api.log.debug('resque worker #' + (i + 1) + ' working job', queue, job);
              });
              worker.on('success', function(queue, job, result) {
                return api.log.info('resque worker #' + (i + 1) + ' job success', queue, [job != null ? job["class"] : void 0, result]);
              });
              worker.on('error', function(queue, job, error) {
                return api.log.error('resque worker #' + (i + 1) + ' job failed', queue, [job != null ? job["class"] : void 0, error]);
              });
              worker.workerCleanup();
              worker.start();
              self.workers[i] = worker;
              started++;
              if (started === api.config.tasks.queues.length) {
                return next(cb);
              }
            });
          })(i);
          _results.push(i++);
        }
        return _results;
      }
    },
    stopWorkers: function(cb) {
      var ended, self;
      self = this;
      if (self.workers.length === 0) {
        return next(cb);
      } else {
        ended = 0;
        return self.workers.forEach(function(worker) {
          api.log.debug('stopping worker:', worker.name);
          return worker.end(function() {
            ended++;
            if (ended === self.workers.length) {
              self.workers = [];
              return next(cb);
            }
          });
        });
      }
    }
  };
  return next(cb);
};

exports.resque = resque;
