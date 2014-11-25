exports.incoming = (message, callback) ->

  message.ext ||= {}

  if !message.channel.match(/meta/ig)
    if !message.channel.match(/clouds\/(.*)\/users/ig)
      message.error = 'Invalid authentication token' if message.ext.server_token != process.env.FAYE_TOKEN

  callback(message)

exports.outgoing = (message, callback) ->
  callback(message)
