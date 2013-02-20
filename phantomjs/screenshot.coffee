fs      = require('fs')
sys     = require('system')
webpage = require('webpage')

if sys.args.length < 2
  console.log "Usage: phantomjs screenshot.coffee <push-server-url> [screen-width] [screen-height] [image-width] [image-height] [wait]"
  return

pushServerUrl = sys.args[1]
screenSize =
  width : sys.args[2] || 1024
  height : sys.args[3] || 768
imageSize =
  width : sys.args[4] || 400
  height : sys.args[5] || 300

renderingWait = Number(sys.args[6] || 1000)

###
 Loading page
###
loadPage = (url, callback) ->
  page = webpage.create()
  page.viewportSize = screenSize
  page.clipRect = { top: 0, left: 0, width: screenSize.width, height: screenSize.height }
  page.onAlert = (msg) ->
    console.log msg
  page.onError = (msg, trace) ->
    console.log msg
    trace.forEach (item) -> console.log "  ", item.file, ":", item.line
  page.open url, (status) ->
    callback (if status is "success" then page else null)
  page


###
 Render and upload page image
###
renderPage = (url, filename, callback) ->
  console.log "rendering #{url} to #{filename} ..."
  loadPage url, (page) ->
    return callback(null) unless page
    setTimeout ->
      page.evaluate -> document.documentElement.style.backgroundColor = '#fff'
      page.render(filename)
      callback(filename)
    , 1000

###
 Resize image size
###
resizeImageFile = (srcFile, dstFile, imageSize, callback) ->
  console.log "resizing #{srcFile} to #{dstFile}..."
  page = webpage.create()
  page.viewportSize = imageSize
  page.clipRect = { left: 0, right: 0, width: imageSize.width, height: imageSize.height }
  html = "<html><body style=\"margin:0;padding:0\">"
  html += "<img src=\"file://#{srcFile}\" width=\"#{imageSize.width}\" height=\"#{imageSize.height}\">"
  html += "</body></html>"
  page.content = html
  page.onLoadFinished = ->
    page.render(dstFile)
    callback(dstFile)

###
 Upload file using form
###
uploadFile = (file, form, callback) ->
  console.log "uploading file #{file}..."
  page = webpage.create()
  html = "<html><body>"
  html += "<form action=\"#{form.action}\" method=\"post\" enctype=\"multipart/form-data\">"
  for n, v of form.fields
    html += "<input type=\"hidden\" name=\"#{n}\" value=\"#{v}\" >"
  html += "<input type=\"file\" name=\"file\" >"
  html += "</form></body></html>"
  page.content = html
  page.uploadFile("input[name=file]", file)
  page.evaluate -> document.forms[0].submit()
  page.onLoadFinished = (status) ->
    url = page.evaluate( -> location.href )
    if url is form.action
      page.onLoadFinished = null
      console.log "uploading done."
      loc = page.content.match(/<Location>(http[^<]+)<\/Location>/)
      if loc
        console.log "image location: #{loc[1]}"
        callback loc[1]
      else
        callback null
      page.release()

###
 Connecting to socket.IO push server
###
connect = (callback) ->
  loadPage pushServerUrl, (page) ->
    return conn(null) unless page
    console.log "connected to #{pushServerUrl}"
    conn = new Connection(page)
    callback(conn)

###
 SocketIO server connection
###
class Connection
  constructor: (@page) ->
    page.onConsoleMessage = (msg) =>
      console.log msg
      return unless msg.indexOf "render:" is 0
      try
        request = JSON.parse(msg.substring(7))
        @onRenderRequest?(request)
      catch e

  onRenderRequest: null

  notify: (message) ->
    args = Array.prototype.slice.call(arguments, 1)
    if message is "complete"
      @page.evaluate("function(){ notifyComplete('#{args.join("','")}'); }")
    else
      @page.evaluate("function(){ notifyFailure('#{args.join("','")}'); }")


###
 init
###
connect (conn) ->
  return console.log("connection failure.") unless conn
  conn.onRenderRequest = (request) ->
    filename = Math.random().toString(36).substring(2)
    captureFile = "/tmp/#{filename}.jpg"
    imageFile = "/tmp/#{filename}_#{imageSize.width}x#{imageSize.height}.jpg"
    renderPage request.url, captureFile, (captureFile) ->
      console.log "captureFile #{captureFile}"
      resizeImageFile captureFile, imageFile, imageSize, (imageFile) ->
        uploadFile imageFile, request.form, (imageUrl) ->
          if imageUrl
            conn.notify("complete", request.url, imageUrl)
          else
            conn.notify("failure",  request.url)
          fs.remove(captureFile)
          fs.remove(imageFile)


