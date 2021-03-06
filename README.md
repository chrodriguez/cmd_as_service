# Command as service

This application is intended to be an easy way to automate running commands as
an HTTP service.

## Installation

* Install ruby 2.x and install bundler gem
* Clone this repo: `git clone https://github.com/chrodriguez/cmd_as_service.git`
* Run: `bundle install`


## Configuration

This service is entirely configured based on environment variables. The complete
list of variables is:

* **CMD_AS:** command to execute. Argument to this command can be set as POST
  argument
* **CACHE_TIMEOUT:** time a generated token will be valid. Default: 300
  seconds.
* **MAIL_TO:** recipient mail address to send validation and notification
  emails.
* **MAIL_FROM:** sender mail address to send mails from.
* **MAIL_SUBJECT:** mail subject text to send for initial validation emails.
  Defualt: Command as a service
* **MAIL_HOST:** mail server to use as SMTP server
* **MAIL_PORT:** mail server port. Default: 25
* **MAIL_USER:** mail server authentication user if needed
* **MAIL_PASS:** mail server authentication password
* **MAIL_AUTH:** mail server authentication method. Valid values are: plain, login,
  cram_md5. If empty means no authentication.
* **MAIL_STARTTLS:** mail server uses starttls?

## HTTP Services

The application exposes only two entry points that must be used as a state
machine:

### POST /

This command is the main entry point. It will accept the following arguments:

* **args**: string with arguments to send as parameters to configured $CMD
* **force:**: force token regeneration. Valid values are true and 1. Other
  values will be considered as false

When a requirement arrives, the application will send a confirmation email to
configured recipients. This email will give recipients the confirmation URL to
be accessed for accepting command execution.

### GET /:token

This entry point is a validation URI. Token must be a valid token previously
generated with a POST method. If token is valid (valid hash and is still within
configured timeout threshold), command is executed using a thread.
When command finishes, a resulting email will be send to configured recipients
with command status and output

## Sample usage

### Start server

```
MAIL_HOST=smtp.example.net MAIL_TO=user@example.net RACK_ENV=production ruby serve.rb
```

### Start server specifying other port

```
RACK_ENV=production puma -w 1 -t 2:4 -p 4567
```

## Sample client usage

Ask to run command as a service

```
curl -d 'force=1&args=Hello world' http://localhost:4567
```


# Docker

You can play with this application using a provided image that can be used as
template o used as base image for your own docker images. Dockerfile is provided
in `docker/` directory.

## Run a sample echo container

The following example uses gmail as server

```
docker run --rm -it \
  -e CMD_AS=/bin/echo \
  -e MAIL_TO=user@gmail.com \
  -e MAIL_FROM=user@gmail.com \
  -e MAIL_HOST=smtp.gmail.com \
  -e MAIL_PORT=587 \
  -e MAIL_USER=user@gmail.com \
  -e MAIL_PASS=**** \
  -e MAIL_AUTH=plain \
  -e MAIL_STARTTLS=true \
  -p 9292:9292 chrodriguez/cmd_as_service
```

Then use curl to play with this demo:

```
curl -d 'args=Hello world' localhost:9292
```

An email will be sent with instructions to follow. Finally, after command
execution an email with subject **SUCCESS...** will be sent with a body similar
to the following example. Any output produced by the command (via `stderr`
and/or `stdout`) will be attached to the email.

```
Command finished in 0.06 seconds
-------------------------------------------------------------------------------

Please refer to the attached file(s) for the standard and error output produced
by the command, if any.

[attachment stdout.txt contains "Hello world"]
```
