task =
  name:         'echo'
  description:  'echo task for test'
  queue:        'default'
  plugins:       []
  pluginOptions: []
  frequency:     0

  run: (api, input, cb) ->
    api.trash = input
    cb null, input

exports.task = task