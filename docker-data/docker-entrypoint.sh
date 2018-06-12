#!/bin/sh

ports="6379 30001 30002 30003 30004 30005 30006"
if [ "$1" = 'redis-cluster' ]; then
    # Allow passing in cluster IP by argument or environmental variable
    IP="${2:-$IP}"

    for port in $ports; do
      mkdir -p /redis-conf/${port}
      mkdir -p /redis-data/${port}

      if [ -e /redis-data/${port}/nodes.conf ]; then
        rm /redis-data/${port}/nodes.conf
      fi

      if [ "${port}" != "6379" ]; then
        PORT=${port} envsubst < /redis-conf/redis-cluster.tmpl > /redis-conf/${port}/redis.conf
      else
        PORT=${port} envsubst < /redis-conf/redis.tmpl > /redis-conf/${port}/redis.conf
      fi
    done

    bash /generate-supervisor-conf.sh "$ports" > /etc/supervisor/supervisord.conf

    supervisord -c /etc/supervisor/supervisord.conf
    sleep 3

    # If IP is unset then discover it
    if [ -z "$IP" ]; then
        IP=`ifconfig | grep "inet addr:17" | cut -f2 -d ":" | cut -f1 -d " "`
    fi
    echo "yes" | ruby /redis/src/redis-trib.rb create --replicas 1 ${IP}:30001 ${IP}:30002 ${IP}:30003 ${IP}:30004 ${IP}:30005 ${IP}:30006
    tail -F /var/log/supervisor/redis*.log
else
  exec "$@"
fi
