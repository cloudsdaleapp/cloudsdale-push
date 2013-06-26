
# Read the environment variable
global.app_env = process.env.NODE_ENV || "development"

# Setup the environment configuration
global.config = require("./config/config.json")[app_env]

global.redisExpire = 86400

# Load all dependent libraries
http = require("http")
_faye = require("./node_modules/faye/build")
fayeRedis = require('faye-redis')
amqp = require("amqp")
global.mongo = require('mongodb')
redis = require('redis')
fs = require('fs')

startServer = ->
  console.log "=> Booting Node.js faye [#{global.app_env}]"

  global.mongosrv = new mongo.Server config.mongo.host, config.mongo.port,
    poolSize: 10
    auto_reconnect: true
    socketOptions:
      timeout: 60 * 1000

  global.mongodb = new mongo.Db config.mongo.database, mongosrv,
    safe: true

  mongodb.open (err, p_client) ->
    if err
      console.log err
    else
      mongodb.authenticate config.mongo.database, config.mongo.password, {}, ->
        console.log "=> Connected to MongoDB on #{config.mongo.host}:#{config.mongo.port}"

  # Initialize the faye server
  faye = new _faye.NodeAdapter
    mount: config.faye.path
    timeout: config.faye.timeout
    engine:
      type: fayeRedis
      host: config.redis.host
      port: config.redis.port
      namespace: "cloudsdale:faye"

  global.fayengine = faye._server._engine._engine
  global.rediscli = faye._server._engine._engine._redis

  # Require all extentions
  userAuthExt   = require("./ext/user_auth")
  serverAuthExt = require("./ext/server_auth")
  clientAuthExt = require("./ext/client_auth")
  userHeartbeat = require("./ext/user_heartbeat")

  # Add all extentions
  faye.addExtension(userAuthExt)
  faye.addExtension(serverAuthExt)
  faye.addExtension(userHeartbeat)

  if app_env == "production"
    # Start listening to a unix socket.

    oldmask = process.umask(0o0000)

    if fs.existsSync config.faye.socket
      fs.utimesSync config.faye.socket, new Date(), new Date()
      fs.unlinkSync config.faye.socket

    faye.listen config.faye.socket,
      key: config.sslKey
      cert: config.sslCert
    console.log "=> Node.js cloudsdale-faye-ssl started on wss://#{config.faye.host}:#{config.faye.secure_port}#{config.faye.path} (socket)"

    fs.unlinkSync config.faye.socket

    faye.listen config.faye.socket
    console.log "=> Node.js cloudsdale-faye started on ws://#{config.faye.host}:#{config.faye.port}#{config.faye.path} (socket)"

    process.umask(oldmask)

  else
    # Start listening to the faye server port.
    faye.listen config.faye.port
    console.log "=> Node.js cloudsdale-faye started on ws://#{config.faye.host}:#{config.faye.port}#{config.faye.path} (port)"

  # Get the faye client
  global.fayeCli = faye.getClient()
  fayeCli.addExtension(clientAuthExt)

  fayeCli.connect()

  # Initialize the amqp consumer
  connection = amqp.createConnection { host: config.rabbit.host, user: config.rabbit.user, pass: config.rabbit.pass },
    reconnect: true

  # When AMQP connection is ready, start subscribing to the faye queue.
  connection.on "ready", ->
    connection.queue "faye", { passive: true, durable: true }, (queue) ->
      queue.bind "#"
      queue.subscribe { ack: false }, (message, headers, deliveryInfo) ->
        fayeCli.publish message.channel, message.data

startServer()

# if app_env == "production"

#   daemon.daemonize
#     stdout: config.logFile,
#     config.pidFile, (err, pid) ->

#       return console.log("Master: error starting daemon: " + err) if err
#       console.log "Daemon started successfully with pid: " + pid

#       daemon.closeStdin()
#       startServer()

# else
#   startServer()

# try
#   init_queue()
# catch err
#   console.log "Error: #{err}"
#   console.log "cloud not connect to [faye] queue... retrying in 10 seconds..."
#   console.log "reload your web page to get the rails server to create the queue."
#   init_queue()

# init_queue = ->
#   connection.queue "faye", { passive: true, durable: true }, (queue) ->
#     queue.bind "#"
#     queue.subscribe { ack: false }, (message, headers, deliveryInfo) ->
#       client.publish message.channel, message.data
