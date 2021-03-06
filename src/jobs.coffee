mongo = (require 'tingodb')();
path = require 'path'
dbName = path.basename(process.cwd()).replace(/\./, "-")

db = new mongo.Db process.env.HOME + "/.concrete/db_#{ dbName }", { name : dbName }
db.open (err) ->
    if err
      console.log 'There was an error creating a connection with the Mongo database. Please check that MongoDB is properly installed and running.'.red
      console.log err
      process.exit 1

jobs = module.exports =
    current: null
    addJob: (next)->
        db.collection 'jobs', (error, collection) ->
            job =
                addedTime: new Date().getTime()
                log: ''
                running: no
                finished: no
            collection.insert job
            next(job) if next?

    getQueued: (next)->
        getJobs {running: no}, next

    getRunning: (next)->
        getJobs {running: yes}, next

    getAll: (next)->
        getJobs null, next

    getLast: (next)->
        db.collection 'jobs', (error, collection) ->
            collection.find().sort({$natural:-1}).limit(1).toArray (error, jobs) ->
                if jobs.length > 0
                    next jobs[0]
                else
                    next()
            

    get: (id, next) ->
        db.collection 'jobs', (error, collection) ->
            collection.findOne {_id: id}, (error, job) ->
                if job?
                    next job
                else
                    next "No job found with the id '#{id}'"

    clear: (next)->
        db.dropCollection 'jobs', (error) ->
            next() if next?

    getLog: (id, next)->
        db.collection 'jobs', (error, collection) ->
            collection.findOne {_id: id}, (error, job) ->
                if job?
                    next job.log
                else
                    next "No job found with the id '#{id}'"

    updateLog: (id, string, next)->
        db.collection 'jobs', (error, collection) ->
            collection.findOne {_id: id}, (error, job) ->
                console.log "update log for job #{job}, #{string}"
                return no if not job?
                job.log += "#{string} <br />"
                collection.save(job)
                next() if next?

    currentComplete: (success, next)->
        db.collection 'jobs', (error, collection) ->
            collection.findOne {_id: jobs.current}, (error, job) ->
                return no if not job?
                job.running = no
                job.finished = yes
                job.failed = not success
                job.finishedTime = new Date().getTime()
                jobs.current = null
                collection.save(job)
                next()

    next: (next)->
        db.collection 'jobs', (error, collection) ->
            collection.findOne {running: no, finished: no}, (error, job) ->
                return no if not job?
                job.running = yes
                job.startedTime = new Date().getTime()
                jobs.current = job._id.toString()
                collection.save(job)
                next()

getJobs = (filter, next)->
    db.collection 'jobs', (error, collection) ->
        if filter?
            collection.find(filter).sort({addedTime: 1}).toArray (error, results) ->
                console.log(error, results)
                next results
        else
            collection.find().sort({addedTime: 1}).toArray (error, results) ->
                console.log(error, results)
                next results
