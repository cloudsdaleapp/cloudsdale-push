exports.incoming = (message, callback) ->

  message.ext ||= {}

  userId = message.ext.user_id
  clientId = message.clientId

  if clientId && userId && message.channel.match(/meta\/connect/ig)
    console.log "User ID: #{userId}"
    startHeartbeat(userId,clientId)

  callback(message)

exports.outgoing = (message, callback) ->
  callback(message)

startHeartbeat = (userId,clientId) ->
  setInterval ->
    refreshPresence(userId,clientId,this)
  , 30000

refreshPresence = (userId,clientId,hearbeatInterval) ->
  mongodb.collection 'users', (err, collection) ->
    console.log err if err
    collection.findOne { _id: userId }, (err,user) ->
      console.log err if err
      checkStatusAndBroadcast(user,clientId,hearbeatInterval) if user != null

checkStatusAndBroadcast = (user,clientId,hearbeatInterval) ->
  setUserHeartbeat(user,Date.now())

  fayengine.clientExists clientId, (connected,score) ->
    if connected
      status = user.preferred_status
      broadcastStatus(user,status) unless status == "offline"
    else
      rediscli.get "cloudsdale/users/#{user._id}", (err, lastSeen) ->
        lastSeen ||= 0

        if Date.now() > lastSeen
          clearUserHeartbeat(user,clientId)
          broadcastStatus(user,"offline")

      clearInterval(hearbeatInterval)

setUserHeartbeat = (user,time) ->
  userId   = user._id
  cloudIds = user.cloud_ids

  rediscli.set "cloudsdale/users/#{userId}", time
  rediscli.expire "cloudsdale/users/#{userId}", redisExpire

  if cloudIds
    for cloudId in cloudIds
      do (cloudId) -> rediscli.hset "cloudsdale/clouds/#{cloudId}/users", userId, time

clearUserHeartbeat = (user) ->
  userId   = user._id
  cloudIds = user.cloud_ids

  rediscli.del "cloudsdale/users/#{userId}"

  if cloudIds
    for cloudId in cloudIds
      do (cloudId) -> rediscli.hdel "cloudsdale/clouds/#{cloudId}/users", userId

broadcastStatus = (user,status) ->

  userId   = user._id
  cloudIds = user.cloud_ids
  status   = status || "offline"

  if cloudIds
    for cloudId in cloudIds
      do (cloudId) -> fayeCli.publish "/clouds/#{cloudId}/users/#{userId}", { status: status }

