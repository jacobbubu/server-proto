module.exports =
  next: (cb, err, res) ->
    cb err, res if typeof cb is 'function'

  hasFunc: (obj, func) ->
    if obj?
      typeof obj[func] is 'function' or typeof obj.__proto__[func] is 'function'
    else
      false

  extend: require 'xtend'
  eql:  require 'deep-equal'