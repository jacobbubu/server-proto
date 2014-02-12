var task;

task = {
  name: 'tick',
  description: 'I will run an action and return the connection object',
  queue: 'default',
  plugins: [],
  pluginOptions: [],
  frequency: 1000,
  run: function(api, params, cb) {
    return cb('Hello, World', 'Second');
  }
};

exports.task = task;
