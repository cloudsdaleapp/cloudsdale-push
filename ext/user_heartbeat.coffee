exports.incoming = (message, callback) ->

  message.ext ||= {}

  if message.channel.match(/meta\/subscribe/ig)
    token = message.ext.auth_token
    client_id = message.clientId

    if message.subscription.match(/users\/(.*)\/private/ig)
      refreshPresence(token,client_id) if token

  callback(message)

exports.outgoing = (message, callback) ->
  callback(message)

refreshPresence = (token,client_id) ->
  mongodb.collection 'users', (err, collection) ->
    if err
      console.log err
    collection.findOne { auth_token: token }, (err,user) ->
      if err
        console.log err
      if user != null
        setPresenceKeys(user,client_id,Date.now())

        fayengine.clientExists client_id, (connected,score) ->
          if connected
            setTimeout ->
              status = user.preferred_status
              msg = { status: status }
              broadcastOnClouds(user,msg,user.cloud_ids)
              setTimeout ->
                refreshPresence(token,client_id)
              , 24000
            , 6000
          else
            last_seen = rediscli.get "cloudsdale/users/#{user._id}"
            last_seen = 0 unless last_seen
            if Date.now() > last_seen
              deletePresenceKeys(user,client_id)
              msg = { status: "offline" }
              broadcastOnClouds(user,msg,user.cloud_ids)

setPresenceKeys = (user,client_id,time) ->
  user_id   = user._id
  cloud_ids = user.cloud_ids

  rediscli.set "cloudsdale/users/#{user_id}", time

  if cloud_ids
    for cloud_id in cloud_ids
      do (cloud_id) ->
        rediscli.hset "cloudsdale/clouds/#{cloud_id}/users", user_id, time

deletePresenceKeys = (user,client_id) ->
  user_id   = user._id
  cloud_ids = user.cloud_ids

  rediscli.del "cloudsdale/users/#{user_id}"

  if cloud_ids
    for cloud_id in cloud_ids
      do (cloud_id) ->
        rediscli.hdel "cloudsdale/clouds/#{cloud_id}/users", user_id

broadcastOnClouds = (user,msg,cloud_ids) ->
  if cloud_ids
    for cloud_id in cloud_ids
      do (cloud_id) ->
        fayeCli.publish "/clouds/#{cloud_id}/users/#{user._id}", msg

