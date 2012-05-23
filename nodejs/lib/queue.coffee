events = require "events"
###
 Worker Queue
###
class WorkerQueue extends events.EventEmitter
  maxWorkers: 100
  maxRequests: 50

  constructor: ->
    @_requests = []
    @_workers = []

  wait: (worker) ->
    request = @_requests.shift()
    if request
      worker.emit "dispatch", request
    else if @maxWorkers > @_workers.length
      @_workers.push(worker)
    else
      @emit "error", message: "Workers Limit Exceeded"
  
  remove: (worker) ->
    @_workers = (w for w in @_workers when w isnt worker)

  enqueue: (request) ->
    worker = @_workers.shift()
    if worker
      worker.emit "dispatch", request
    else if @maxRequests > @_requests.length
      @_requests.push(request)
    else
      @emit "error", message: "Request Limit Exceeded"


module.exports = WorkerQueue
