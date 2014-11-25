exports.incoming = (message, callback) ->

  message.ext ||= {}

  clientId = message.clientId

  if clientId && message.channel.match(/meta\/subscribe/ig)
    privateChannelMatch = /^\/users\/(.{24})\/private$/ig.exec(message.subscription)
    if privateChannelMatch
      userId = message.ext.user_id || privateChannelMatch[1]
      if userId
        startHeartbeat(userId,clientId) if userId.match(/^.{24}$/)

  callback(message)

exports.outgoing = (message, callback) ->
  callback(message)

startHeartbeat = (userId,clientId) ->
  setTimeout ->
    refreshPresence(userId,clientId,undefined,true)
  , 2000
  setInterval ->
    refreshPresence(userId,clientId,this,false)
  , 30000

refreshPresence = (userId,clientId,hearbeatInterval,firstPass) ->
  mongodb.collection 'users', (err, collection) ->
    console.log err if err
    collection.findOne { _id: new mongo.ObjectID(userId) }, (err,user) ->
      console.log err if err
      checkStatusAndBroadcast(user,clientId,hearbeatInterval,firstPass) if user != null

checkStatusAndBroadcast = (user,clientId,hearbeatInterval,firstPass) ->
  setUserHeartbeat(user,Date.now())

  fayeEngine.clientExists clientId, (connected,score) ->
    if connected
      status = user.preferred_status
      broadcastStatus(user,status) if (status != "offline") and (firstPass == true)
    else
      redisClient.get "cloudsdale/users/#{user._id.toString()}", (err, lastSeen) ->
        lastSeen ||= 0

        if Date.now() > lastSeen
          clearUserHeartbeat(user,clientId)
          broadcastStatus(user,"offline")

      clearInterval(hearbeatInterval) if hearbeatInterval

setUserHeartbeat = (user,time) ->
  userId   = user._id.toString()
  cloudIds = user.cloud_ids

  redisClient.set "cloudsdale/users/#{userId}", time
  redisClient.expire "cloudsdale/users/#{userId}", redisExpire

  if cloudIds
    for cloudId in cloudIds
      do (cloudId) -> redisClient.hset "cloudsdale/clouds/#{cloudId}/users", userId, time

clearUserHeartbeat = (user) ->
  userId   = user._id.toString()
  cloudIds = user.cloud_ids

  redisClient.del "cloudsdale/users/#{userId}"

  if cloudIds
    for cloudId in cloudIds
      do (cloudId) -> redisClient.hdel "cloudsdale/clouds/#{cloudId}/users", userId

broadcastStatus = (user,status) ->

  userId   = user._id.toString()
  cloudIds = user.cloud_ids
  status   = status || "offline"

  if cloudIds
    for cloudId in cloudIds
      do (cloudId) -> fayeClient.publish "/clouds/#{cloudId}/users/#{userId}", { id: userId, status: status }

