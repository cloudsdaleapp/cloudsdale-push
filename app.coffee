# Read the environment variable
global.app_env = process.env.NODE_ENV || "development"

# Setup the environment configuration
global.config = require("./config/config.json")[app_env]

# Load all dependent libraries
http = require("http")
faye = require("faye")
amqp = require("amqp")

# Initialize the faye server
faye = new faye.NodeAdapter
  mount: config.faye.path
  timeout: config.faye.timeout

# Require all extentions
serverAuthExt = require("./ext/server_auth")
clientAuthExt = require("./ext/client_auth")

# Add all extentions
faye.addExtension(serverAuthExt)

# Start listening to the faye server port.
faye.listen config.faye.port

console.log "Started Node.js faye server on port #{config.faye.port}"

# Get the faye client
client = faye.getClient()
client.addExtension(clientAuthExt)

client.connect()

# Initialize the amqp consumer
connection = amqp.createConnection
  host: config.rabbit.host
  user: config.rabbit.user
  pass: config.rabbit.pass

# When AMQP connection is ready, start subscribing to the faye queue.
connection.on "ready", ->
  connection.queue "faye", { passive: true }, (queue) ->
    queue.bind "#"
    queue.subscribe { ack: false }, (message, headers, deliveryInfo) ->
            
      client.publish message.channel, message.data
