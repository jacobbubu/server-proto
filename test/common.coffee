assert  = require('referee').assert
refute  = require('referee').refute

module.exports.ServerProto    = require '../index'
module.exports.commonSetUp    = (done) ->
  @timeout = 1000
  done()
module.exports.commonTearDown = (done) -> done()
