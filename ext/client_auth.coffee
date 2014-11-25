exports.incoming = (message, callback) ->
  callback(message)

exports.outgoing = (message, callback) ->

  message.ext ||= {}
  message.ext.server_token = process.env.FAYE_TOKEN

  callback(message)
