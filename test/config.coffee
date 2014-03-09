config = {}

config.appName = 'server-proto-test'
config.pid = '/tmp'

config.logger =
  console:
    theme: 'formatMinilog' # 'formatClean', 'formatColor', 'formatNpm', 'formatLearnboost', 'formatWithStack'
    'filter-name': '.*'
    'filter-level': 'error'

config.redis =
  host: '127.0.0.1'
  port: 6379
  password: null
  options: null
  database: 14

config.tasks =
  # Should this node run a scheduler to promote delayed tasks?
  scheduler: true
  # what queues should the workers work and how many to spawn?
  #  ['*'] is one worker working the * queue
  #  ['high,low'] is one worker working 2 queues
  queues: ['*']
  # how long to sleep between jobs / scheduler checks
  timeout: 1000
  # What redis server should we connect to for tasks / delayed jobs?
  redis: config.redis

config.stats =
  # how often should the server write its stats to redis?
  writeFrequency: 1000
  # what redis key(s) [hash] should be used to store stats?
  # provide no key if you do not want to store stats
  keys: [ config.appName + ':stats' ]

exports.config = config