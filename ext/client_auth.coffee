exports.incoming = (message, callback) ->
  callback(message)

exports.outgoing = (message, callback) ->
  
  message.ext ||= {}
  message.ext.auth_token = config.faye.token
    
  callback(message)
