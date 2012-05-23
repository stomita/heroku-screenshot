Heroku Screenshot Server: Node.js
=======================

Deploying to Heroku
-----

    $ heroku create --stack cedar
    $ heroku config:add AWS_ACCESS_KEY_ID=<your aws access key id>
    $ heroku config:add AWS_SECRET_ACCESS_KEY=<your aws secret access key>
    $ heroku config:add UPLOAD_BUCKET_NAME=<aws s3 bucket name to store screenshots>
    $ git push heroku master


