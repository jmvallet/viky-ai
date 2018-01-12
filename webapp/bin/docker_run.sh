#!/bin/bash
set -x -e

# remove previously started server pid
rm -f ./tmp/pids/server.pid
rm -f ./tmp/pids/sidekiq.pid


if [[ "$1" == "master" ]] ; then

  # wait for services
  /usr/local/bin/dockerize -wait tcp://db-postgresql:5432 -wait tcp://db-redis:6379 -timeout 60s


  # Setup DB
  ./bin/rails db:create db:migrate

  # Push all Package
  ./bin/rails packages:push_all && echo "All packages have been pushed" &

else

  # wait for services
  # migration can be long
  /usr/local/bin/dockerize -wait http://app-master:3000 -wait tcp://db-postgresql:5432 -wait tcp://db-redis:6379 -timeout 600s

fi

if [[ "$1" == "worker" ]] ; then

  # Start one worker
  bundle exec sidekiq -C config/sidekiq.yml


else

  echo "viky will be available on ${VIKYAPP_BASEURL}"

  # Start web server
  ./bin/rails server -b 0.0.0.0 -p 3000

fi
