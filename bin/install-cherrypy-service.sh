#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. $SCRIPT_DIR/hadoop-install.conf

if [ -z $1 ]; then
  echo "This script requires a parameter: cherrypy script"
  exit 1
fi

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root."
   exit 1
fi

if [ -z "`dpkg-query -l python-cherrypy3 2> /dev/null | grep '^ii '`" ]; then
    apt-get install -y python-cherrypy3
fi

if [ -z "`dpkg-query -l gawk 2> /dev/null`" ]; then
    apt-get install gawk
fi

CHERRYPY_SCRIPT=`readlink -f $1`
PORT=`$CHERRYPY_SCRIPT port` # extract it to give it to nginx installer
SERVICE_NAME=`$CHERRYPY_SCRIPT service_name`
PIDFILE=`$CHERRYPY_SCRIPT pidfile_path`

#  651  cd hadoop-install/dist/
#  652  tar -xzf CherryPy-*.tar.gz 
#  654  cd CherryPy-*
#  655  python3 setup.py install

cat > /etc/init.d/$SERVICE_NAME << "EOF"
#!/bin/sh
### BEGIN INIT INFO
# Provides:          ${SERVICE_NAME}
# Required-Start:    $local_fs $remote_fs $network $syslog
# Required-Stop:     $local_fs $remote_fs $network $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start/Stop ${SERVICE_NAME} CherryPy script
### END INIT INFO

PIDFILE=${PIDFILE}

case "$1" in
start)
echo "Starting ${SERVICE_NAME}..."
start-stop-daemon --start --background --pidfile $PIDFILE --exec ${CHERRYPY_SCRIPT}
exit $?
;;
stop)
echo "Stopping ${SERVICE_NAME}..."

start-stop-daemon --stop --quiet --pidfile $PIDFILE --exec `which python`
exit $?
;;
*)
echo "Usage: /etc/init.d/${SERVICE_NAME} {start|stop}"
exit 1
;;
esac
exit 0
EOF
sed -i -e 's,${SERVICE_NAME},'$SERVICE_NAME',g' /etc/init.d/$SERVICE_NAME
sed -i -e 's,${CHERRYPY_SCRIPT},'$CHERRYPY_SCRIPT',g' /etc/init.d/$SERVICE_NAME
sed -i -e 's,${PIDFILE},'$PIDFILE',g' /etc/init.d/$SERVICE_NAME
chmod 755 /etc/init.d/$SERVICE_NAME
update-rc.d $SERVICE_NAME defaults
service $SERVICE_NAME start
