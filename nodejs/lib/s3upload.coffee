crypto = require "crypto"

config =
  aws:
    accessKeyId: process.env.AWS_ACCESS_KEY_ID
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY
  upload:
    bucketName: process.env.UPLOAD_BUCKET_NAME
    path: 'files/'
    expiration: 5

toISO8601 = (d) ->
  pad2 = (n) -> (if n < 10 then '0' else '') + n
  pad3 = (n) -> (if n < 10 then '00' else if n < 100 then '0' else '') + n
  [
    d.getUTCFullYear()
    '-'
    pad2(d.getUTCMonth() + 1)
    '-'
    pad2(d.getUTCDate())
    'T'
    pad2(d.getUTCHours())
    ':'
    pad2(d.getUTCMinutes())
    ':'
    pad2(d.getUTCSeconds())
    '.'
    pad3(d.getUTCMilliseconds())
    'Z'
  ].join('')


module.exports =
  createForm: (filename) ->
    filePath = config.upload.path + filename + '.jpg'
    policy =
      expiration : toISO8601(new Date(Date.now() + 60000 * config.upload.expiration))
      conditions : [
        { bucket: config.upload.bucketName }
        [ "starts-with", "$key", config.upload.path ]
        { acl: "public-read" }
        { success_action_status : "201" }
        [ "starts-with", "$Content-Type", "image/" ]
        [ "content-length-range", 0, 524288 ]
      ]
    policyB64 = new Buffer(JSON.stringify(policy)).toString('base64')
    signature = crypto.createHmac('sha1', config.aws.secretAccessKey)
                      .update(policyB64)
                      .digest('base64')
    {
      action : "http://#{config.upload.bucketName}.s3.amazonaws.com/"
      fields :
        AWSAccessKeyId: config.aws.accessKeyId
        key: filePath
        acl: "public-read"
        success_action_status: "201"
        "Content-Type": "image/jpeg"
        policy: policyB64
        signature: signature
    }


