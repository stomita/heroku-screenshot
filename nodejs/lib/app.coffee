###
app.coffee
###

events   = require "events"
express  = require "express"
crypto   = require "crypto"
socketio = require "socket.io"
s3upload   = require "./s3upload"
WorkerQueue = require "./queue"

app = module.exports = express.createServer()

###
Express server configure
###
app.configure ->
  app.set "views", __dirname + "/../views"
  app.set "view engine", "ejs"
  app.use express.bodyParser()
  app.use express.methodOverride()
  app.use app.router
  app.use express.static(__dirname + "/../public")

app.configure "development", ->
  app.use express.errorHandler(
    dumpExceptions: true
    showStack: true
  )

app.configure "production", ->
  app.use express.errorHandler()


###
SHA1 Hash Utility Function
###
sha1 = (str) ->
  crypto.createHash('sha1').update(str).digest('hex')


###
Worker Queue
###
queue = new WorkerQueue()


###
Socket IO Channels
###
io = socketio.listen(app)

channels =
  request:
    io.of("/request")
      .on "connection", (socket) ->
        console.log "<requester> connect"
        socket.on "render", (url) ->
          console.log "<requester> render #{url}"
          hash = sha1(url)
          queue.enqueue
            url: url
            hash: hash
            form : s3upload.createForm(hash)
        socket.on "disconnect", ->
          console.log "<requester> disconnect"

  render:
    io.of("/render")
      .on "connection", (socket) ->
        console.log "<renderer> connect"
        renderer = new events.EventEmitter()
        renderer.on "dispatch", (req) -> socket.emit "render", req
        queue.wait(renderer)
        socket.on "complete", (response) ->
          console.log "<renderer> notify #{response.imageUrl}"
          channels.request.emit "image", response.imageUrl
          queue.wait(renderer)
        socket.on "fail", ->
          queue.wait(renderer)
        socket.on "disconnect", ->
          console.log "<renderer> disconnect"
          queue.remove(renderer)


###
Start server
###
app.listen process.env.PORT ? 3000
console.log "Express server listening on port %d in %s mode", app.address().port, app.settings.env
