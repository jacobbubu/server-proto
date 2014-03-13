os    = require 'os'
NR    = require 'node-resque'

resque = (api, cb) ->
  { next, clone } = api.utils
  api.resque =
    queue: null
    workers: []
    scheduler: null
    connectionDetails: if api.config.tasks.redis? then clone api.config.tasks.redis else {}

    _start: (api, cb) ->
      self = api.resque
      self.startQueue ->
        self.startScheduler ->
          self.startWorkers ->
            next cb

    _stop: (api, cb) ->
      self = api.resque
      self.stopScheduler ->
        self.stopWorkers ->
          self.queue.end ->
            next cb

    startQueue: (cb) ->
      self = api.resque
      self.queue = new NR.queue { connection: self.connectionDetails }, api.tasks.jobs, ->
        next cb

    startScheduler: (cb) ->
      self = api.resque
      if api.config.tasks.scheduler
        self.scheduler = new NR.scheduler { connection: self.connectionDetails, timeout: api.config.tasks.timeout }, ->
          self.scheduler.on 'start',                            -> api.log.info  'resque scheduler started'
          self.scheduler.on 'end',                              -> api.log.info  'resque scheduler ended'
          self.scheduler.on 'working_timestamp',    (timestamp) -> api.log.debug 'resque scheduler working timestamp', timestamp
          self.scheduler.on 'transferred_job', (timestamp, job) -> api.log.debug 'resque scheduler enqueuing job', timestamp, job
          # self.scheduler.on 'poll',                            -> api.log.debug 'resque scheduler polling'
          self.scheduler.start()
          process.nextTick ->
            next cb
      else
        next cb

    stopScheduler: (cb) ->
      self = api.resque
      if not self.scheduler?
        next cb
      else
        self.scheduler.end () ->
          delete self.scheduler
          next cb

    startWorkers: (cb) ->
      self = api.resque
      i = 0
      started = 0
      if not api.config.tasks.queues? or api.config.tasks.queues.length is 0
        next cb
      else
        while i < api.config.tasks.queues.length
          do (i=i) ->
            timeout = api.config.tasks.timeout
            name = os.hostname() + ':' + process.pid + '+' + (i+1)
            worker = new NR.worker {
              connection: self.connectionDetails
              name: name
              queues: api.config.tasks.queues[i]
              timeout: timeout
            }, api.tasks.jobs, ->
              worker.on 'start',           ->                      api.log.info  'resque worker #' + (i+1) + ' started (queues: ' + worker.options.queues + ')'
              worker.on 'end',             ->                      api.log.info  'resque worker #' + (i+1) + ' ended'
              worker.on 'cleaning_worker', (worker, pid) ->        api.log.info  'resque cleaning old worker ', worker
              # worker.on('poll',            function(queue){              api.log('resque worker #'+(i+1)+' polling ' + queue, 'debug'); })
              worker.on 'job',             (queue, job) ->         api.log.debug 'resque worker #' + (i+1) + ' working job', queue, job
              worker.on 'success',         (queue, job, result) ->
                api.log.info  'resque worker #' + (i+1) + ' job success', queue, [job?.class, result]
              worker.on 'error',           (queue, job, error) ->
                api.log.error 'resque worker #' + (i+1) + ' job failed', queue, [job?.class, error]
              # worker.on('pause',           function(){                   api.log('resque worker #'+(i+1)+'  paused', 'debug'); })

              worker.workerCleanup()
              worker.start()
              self.workers[i] = worker

              started++
              if started is api.config.tasks.queues.length
                next cb
          i++

    stopWorkers: (cb) ->
      self = api.resque
      if self.workers.length is 0
        next cb
      else
        ended = 0
        self.workers.forEach (worker) ->
          api.log.debug 'stopping worker:', worker.name
          worker.end ->
            ended++
            if ended is self.workers.length
              self.workers = []
              next cb
  next cb

exports.resque = resque