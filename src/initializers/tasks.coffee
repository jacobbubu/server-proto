fs   = require 'fs'
path = require 'path'
next = require('../utils').next

getParams = (taskName, params, queue, cb) ->
  if typeof queue is 'function'
    cb = queue
    queue = @tasks[taskName].queue
  else if typeof params is 'function'
    cb = params
    queue = @tasks[taskName].queue
    params = {}
  { params, queue, cb }

tasks = (api, cb) ->

  api.tasks =
    tasks: {}
    jobs: {}

    _start: (api, cb) ->
      if api.config.tasks.scheduler
        api.tasks.enqueueAllRecurrentJobs ->
          next cb
      else
        next cb

    load: (fullFilePath) ->
      self = @

      loadMessage = (loadedTaskName) ->
        api.log.debug 'task loaded:', loadedTaskName + ',', fullFilePath

      collection = require fullFilePath
      for i of collection
        task = collection[i]
        if self.validateTask task
          api.tasks.tasks[task.name] = task
          api.tasks.jobs[task.name] = self.jobWrapper task.name
          loadMessage task.name

    jobWrapper: (taskName) ->
      self = @
      task = api.tasks.tasks[taskName]
      plugins = task.plugins ? []
      pluginOptions = task.pluginOptions ? []
      if task.frequency > 0
        plugins.push 'jobLock'        if plugins.indexOf('jobLock') < 0
        plugins.push 'queueLock'      if plugins.indexOf('queueLock') < 0
        plugins.push 'delayQueueLock' if plugins.indexOf('delayQueueLock') < 0

      return {
        'plugins': plugins
        'pluginOptions': pluginOptions
        'perform': ->
          args = Array.prototype.slice.call arguments
          cb = args.pop()
          error = null
          # empty params array
          args.push {} if args.length is 0
          args.push (res) ->
            self.enqueueRecurrentJob taskName, ->
              cb error, res
          args.splice 0, 0, api
          api.tasks.tasks[taskName].run.apply null, args
      }

    validateTask: (task) ->
      fail = (msg) ->
        api.log.error msg + '; exiting.'

      if typeof task.name isnt 'string' or task.name.length < 1
        fail "a task is missing 'task.name'"
        return false
      else if typeof task.description isnt 'string' or task.description.length < 1
        fail "Task #{task.name} is missing 'task.description'"
        return false
      else if typeof task.frequency isnt 'number'
        fail "Task #{task.name} has no frequency"
        return false
      else if typeof task.queue isnt 'string'
        fail "Task #{task.name} has no queue"
        return false
      else if typeof task.run != 'function'
        fail "Task #{task.name} has no run method"
        return false
      else
        return true

    loadFolder: (taskPath) ->
      self = @
      taskPath ?= path.resolve api.project_root, 'tasks'
      if fs.existsSync taskPath
        fs.readdirSync(taskPath).forEach (file) ->
          fullFilePath = path.join taskPath, file
          if file[0] isnt '.'
            stats = fs.statSync fullFilePath
            if stats.isDirectory()
              self.loadFolder fullFilePath
            else if stats.isSymbolicLink()
              realPath = fs.readlinkSync fullFilePath
              self.loadFolder realPath
            else if stats.isFile()
              ext = path.extname file
              if ext in ['.js', '.coffee', '.litcoffee']
                api.tasks.load fullFilePath
            else
              api.log.warn file + ' is a type of file I cannot read'
      else
        api.log.debug 'no tasks folder found, skipping'

    enqueue: (taskName, params, queue, cb) ->
      res = getParams.call @, taskName, params, queue, cb
      api.resque.queue.enqueue res.queue, taskName, res.params, res.cb

    enqueueAt: (timestamp, taskName, params, queue, cb) ->
      res = getParams.call @, taskName, params, queue, cb
      api.resque.queue.enqueueAt timestamp, res.queue, taskName, res.params, res.cb

    enqueueIn: (time, taskName, params, queue, cb) ->
      res = getParams.call @, taskName, params, queue, cb
      api.resque.queue.enqueueIn time, res.queue, taskName, res.params, res.cb

    del: (q, taskName, args, count, cb) ->
      api.resque.queue.del q, taskName, args, count, cb

    delDelayed: (q, taskName, args, cb) ->
      api.resque.queue.delDelayed q, taskName, args, cb

    enqueueRecurrentJob: (taskName, cb) ->
      self = @
      task = self.tasks[taskName]
      if task.frequency <= 0
        next cb
      else
        self.del task.queue, taskName, {}, ->
          self.delDelayed task.queue, taskName, {}, ->
            self.enqueueIn task.frequency, taskName, ->
              api.log.debug 're-enqueued recurrent job', taskName
              next cb

    enqueueAllRecurrentJobs: (cb) ->
      self = @
      started = 0
      loadedTasks = []
      for taskName of self.tasks
        task = self.tasks[taskName]
        if task.frequency > 0
          started++
          do (taskName = taskName) ->
            self.enqueue taskName, (err, toRun) ->
              if toRun
                api.log.info 'enqueuing periodic task:', taskName
                loadedTasks.push taskName
              started--
              next cb loadedTasks if started is 0
      next cb loadedTasks if started is 0

    stopRecurrentJob: (taskName, cb) ->
      # find the jobs in either the normal queue or delayed queues
      self = @
      task = self.tasks[taskName]
      if task.frequency <= 0
        next cb
      else
        removedCount = 0
        self.del task.queue, task.name, {}, 1, (err, count) ->
          removedCount = removedCount + count
          self.delDelayed task.queue, task.name, {}, (err, timestamps) ->
            removedCount = removedCount + timestamps.length
            next cb, err, removedCount

    details: (cb) ->
      self = @
      details = queues: {}
      api.resque.queue.queues (err, queues) ->
        if queues.length is 0
          next cb, null, details
        else
          started = 0
          queues.forEach (queue) ->
            started++
            api.resque.queue.length queue, (err, length) ->
              details['queues'][queue] = length: length
              started--
              next cb, null, details if started is 0

  api.tasks.loadFolder()
  next cb

exports.tasks = tasks