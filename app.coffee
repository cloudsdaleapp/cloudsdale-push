# Read the environment variable
global.redisExpire = 86400

# Load all dependent libraries
global.http = require("http")
global.amqp = require("amqp")
global.mongo = require("mongodb")
global.redis = require("faye-redis")
global.faye = require("faye")
global.fs = require("fs")

global.Url = require("url")
global.QueryString = require("querystring")

connectMongoDB = (url) ->

  url = Url.parse(url)

  host = url.hostname
  port = url.port

  opts = if url.query then QueryString.parse(url.query) else {}
  opts.poolSize ||= 10
  opts.auto_reconnect ||= true
  opts.socketOptions ||= {}
  opts.socketOptions.timeout || = 60 * 1000

  database = url.pathname.slice(1) if url.pathname

  server = new mongo.Server(host, port, opts)

  db = new mongo.Db(database, server, safe: true)

  db.open (err, client) ->
    throw err if err
    if url.auth
      auth = url.auth.split(":")
      mongodb.authenticate auth[0], auth[1], {}, ->
        console.log "MongoDB connection on #{host}:#{port}"

  return db

connectRabbit = (url) ->
  rabbit = amqp.createConnection(url: url, vhost: "/")
  rabbit.on "ready", -> console.log "RabbitMQ connection on #{ url }"
  rabbit.on "close", -> console.log "RabbitMQ connection could not be established"
  return rabbit

redisEngineConfig = (url) ->
  url = Url.parse(url)

  opts = {}
  opts.type = redis
  opts.host = url.hostname if url.hostname
  opts.port = url.port  if url.port
  opts.database = url.pathname.slice(1)
  opts.namespace = "cloudsdale:faye"

  return opts

startFaye = (url, engine) ->
  url = Url.parse(url)
  opts = if url.query then QueryString.parse(url.query) else { timeout: 45 }

  server = new faye.NodeAdapter
    mount: url.pathname
    timeout: opts.timeout
    engine: redisEngineConfig(process.env.REDIS_URL || "redis://127.0.0.1:6379/0")

  userAuthExt   = require("./ext/user_auth")
  serverAuthExt = require("./ext/server_auth")
  userHeartbeat = require("./ext/user_heartbeat")

  server.addExtension(userAuthExt)
  server.addExtension(serverAuthExt)
  server.addExtension(userHeartbeat)

  console.log "Node.js cloudsdale-faye started on #{ url.href }"
  server.listen(url.port)

  return server

connectFaye = (bayeux) ->
  client = bayeux.getClient()
  client.addExtension require("./ext/client_auth")
  client.connect()
  return client

exports.run = ->
  console.log "Booting node.js faye [#{ (process.env.FAYE_ENV || "development") }]"

  global.mongodb = connectMongoDB(process.env.MONGO_URL || "mongo://127.0.0.1:27017/cloudsdale")
  global.fayeServer = startFaye(process.env.FAYE_URL || "ws://0.0.0.0:8282/push")
  global.fayeClient = connectFaye(fayeServer)

  global.fayeEngine = fayeServer._server._engine._engine
  global.redisClient = fayeServer._server._engine._engine._redis

  rabbit = connectRabbit(process.env.AMQP_URL || "amqp://guest:guest@localhost")
  rabbit.on "ready", ->
    rabbit.exchange "cloudsdale.push", { type: "direct", autoDelete: false }, (exchange) ->
      rabbit.queue "cloudsdale.push", { passive: false, durable: true, noDeclare: false, autoDelete: false }, (queue) ->
        queue.bind(exchange, "#")
        queue.subscribe { ack: false }, (message, headers, deliveryInfo) ->
          fayeClient.publish(message.channel, message.data)

    rabbit.queue "faye", { passive: false, durable: true, noDeclare: false, autoDelete: false }, (queue) ->
      queue.bind("#")
      queue.subscribe { ack: false }, (message, headers, deliveryInfo) ->
        fayeClient.publish(message.channel, message.data)

