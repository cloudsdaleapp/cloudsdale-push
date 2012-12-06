exports.incoming = (message, callback) ->

  message.ext ||= {}
  token = message.ext.auth_token

  # Clear user id so that users cannot set it themselves
  delete message.ext["user_id"]

  console.log "----------------------------------"
  console.log "Client ID: #{message.clientId}"
  console.log "Message on '#{message.channel}'"
  console.log "Auth Token: #{token}"

  if token
    rediscli.get "cloudsdale/users/#{token}/id", (err,userId) ->
      callback(message) if err
      if userId
        message.ext.user_id = userId
        callback(message)
      else
        mongodb.collection 'users', (err, collection) ->
          callback(message) if err
          collection.findOne { auth_token: token }, (err,user) ->
            callback(message) if err
            if user != null
              rediscli.set "cloudsdale/users/#{token}/id", user._id
              rediscli.expire "cloudsdale/users/#{token}/id", redisExpire
              message.ext.user_id = user._id
              callback(message)
            else
              callback(message)
  else
    callback(message)

exports.outgoing = (message, callback) ->
  callback(message)
