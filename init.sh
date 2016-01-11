#!/bin/bash

trap graceful_stop SIGHUP SIGINT SIGTERM

set_java_home () {
  arch=`dpkg --print-architecture 2>/dev/null`
  support_java_ver='6 7'
  java_list=''
  for v in ${support_java_ver}; do
    java_list=`echo ${java_list} java-$v-openjdk-${arch}`
    java_list=`echo ${java_list} java-$v-openjdk`
  done

  cur_java=`update-alternatives --query java | awk '/^Value: /{print $2}'`
  cur_real_java=`readlink -f ${cur_java} 2>/dev/null`
  for jvm in ${java_list}; do
    jvm_real_java=`readlink -f /usr/lib/jvm/${jvm}/bin/java 2>/dev/null`
    [ "${jvm_real_java}" != "" ] || continue
    if [ "${jvm_real_java}" == "${cur_real_java}" ]; then
      JAVA_HOME="/usr/lib/jvm/${jvm}"
      return
    fi
  done

  alts_java=`update-alternatives --query java | awk '/^Alternative: /{print $2}'`
  for cur_java in ${alts_java}; do
    cur_real_java=`readlink -f ${cur_java} 2>/dev/null`
    for jvm in ${java_list}; do
      jvm_real_java=`readlink -f /usr/lib/jvm/${jvm}/bin/java 2>/dev/null`
      [ "${jvm_real_java}" != "" ] || continue
      if [ "${jvm_real_java}" == "${cur_real_java}" ]; then
        JAVA_HOME="/usr/lib/jvm/${jvm}"
        return
      fi
    done
  done

  JAVA_HOME=/usr/lib/jvm/java-6-openjdk
}

NAME="unifi"
DESC="Ubiquiti UniFi Controller"

BASEDIR="/usr/lib/unifi"
MAINCLASS="com.ubnt.ace.Launcher"

PIDFILE="/var/run/${NAME}/${NAME}.pid"
PATH=/bin:/usr/bin:/sbin:/usr/sbin

MONGOPORT=27117
MONGOLOCK="${BASEDIR}/data/db/mongod.lock"

ENABLE_UNIFI=yes
JVM_EXTRA_OPTS=
JSVC_EXTRA_OPTS=
[ -f /etc/default/${NAME} ] && . /etc/default/${NAME}

[ "x${ENABLE_UNIFI}" != "xyes" ] && exit 0

JVM_OPTS="${JVM_EXTRA_OPTS} -Djava.awt.headless=true -Dfile.encoding=UTF-8 -Xmx1024M"

set_java_home

# JSVC - for running java apps as services
JSVC=`which jsvc`

#JSVC_OPTS="-debug"
JSVC_OPTS="${JSVC_OPTS}\
  -home ${JAVA_HOME} \
  -cp /usr/share/java/commons-daemon.jar:${BASEDIR}/lib/ace.jar \
  -pidfile ${PIDFILE} \
  -procname ${NAME} \
  -outfile SYSLOG \
  -errfile SYSLOG \
  ${JSVC_EXTRA_OPTS} \
  ${JVM_OPTS}"

[ -d /var/run/${NAME} ] || mkdir -p /var/run/${NAME}
cd ${BASEDIR}

function graceful_stop {
  echo "Stopping unifi service..."
  ${JSVC} ${JSVC_OPTS} -stop ${MAINCLASS} stop
  for i in `seq 1 10` ; do
    [ -z "$(pgrep -f ${BASEDIR}/lib/ace.jar)" ] && break
    # graceful shutdown
    [ $i -gt 1 ] && [ -d ${BASEDIR}/run ] && touch ${BASEDIR}/run/server.stop || true
    # savage shutdown
    [ $i -gt 7 ] && pkill -f ${BASEDIR}/lib/ace.jar || true
    sleep 1
  done
  # shutdown mongod
  if [ -f ${MONGOLOCK} ]; then
    echo "Stopping mongo service..."
    mongo localhost:${MONGOPORT} --eval "db.getSiblingDB('admin').shutdownServer()" >/dev/null 2>&1
  fi
}

echo "Starting unifi service..."
${JSVC} ${JSVC_OPTS} ${MAINCLASS} start
sleep 5

while true; do sleep 0.1; done
