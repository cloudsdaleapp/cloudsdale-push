exports.incoming = (message, callback) ->
  callback(message)

exports.outgoing = (message, callback) ->

  message.ext ||= {}
  message.ext.server_token = config.faye.token

  callback(message)
