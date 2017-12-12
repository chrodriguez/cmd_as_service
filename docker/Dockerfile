FROM alpine:3.7

ADD . /app

RUN apk add -U --no-cache ruby ruby-dev build-base libressl libressl-dev && \
    cd /app && \
    gem install bundler --no-rdoc --no-ri && \
    bundle --frozen

ENV RACK_ENV=production \
    CMD_AS=/bin/echo

WORKDIR "/app"

CMD [ "puma", "-w", "1", "-t", "2:4" ]
