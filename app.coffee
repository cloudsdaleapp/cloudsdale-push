console.log "=> Booting Node.js faye..."

# Read the environment variable
global.app_env = process.env.NODE_ENV || "development"

# Setup the environment configuration
global.config = require("./config/config.json")[app_env]

# Load all dependent libraries
http = require("http")
faye = require("./node_modules/faye/build")
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

console.log "=> Node.js cloudsdale-faye started on  ws://#{config.faye.host}:#{config.faye.port}#{config.faye.path}"

# Get the faye client
client = faye.getClient()
client.addExtension(clientAuthExt)

client.connect()

# Initialize the amqp consumer
connection = amqp.createConnection { host: config.rabbit.host, user: config.rabbit.user, pass: config.rabbit.pass },
  reconnect: true

# When AMQP connection is ready, start subscribing to the faye queue.
connection.on "ready", ->
  connection.queue "faye", { passive: true, durable: true }, (queue) ->
    queue.bind "#"
    queue.subscribe { ack: false }, (message, headers, deliveryInfo) ->
      client.publish message.channel, message.data

    
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