#!/bin/bash

#######
#  This file contains instructions to build the demo environment
#  from source
#
#  - as root,
#  - within a bare Ubuntu 14.04 docker image
#
#  1. To launch into the bare image, use
#    sudo docker run -p 3000:3000 -p 3350:3350 -p 3111:3111 -p 8080:8080 -it ubuntu:14.04 /bin/bash
#
#  2. Copy and paste this entire file into the prompt
#
#  3. Run one by one all the update functions except update_all
#     (or run only update_all)
#     This step requires downloading around 500M, and
#     some pretty heavy compilation.
#
#  4. Optional. Save your work so steps 1-3 need not be repeated:
#     - exit the image: execute 'exit'
#     - save the image: execute 'sudo docker clone <id> <name>'
#       (use 'sudo docker ps -a' to find its <id>)
#     - re-start the image: 
#       sudo docker run -p 3000:3000 -p 3350:3350 -p 3111:3111 -p 8080:8080 -it <name> /bin/bash
#
#  5. Launch supporting servers
#     - launch_redis && launch_mongo && launch_el
#     - launch_zookeeper
#     - launch_kafka
#     - launch_storm
#     - launch_openlrs
#
#  6. Launch WP2 servers, one by one
#     - launch_openlrs
#     - launch_test_users
#     - launch_lrs
#     - launch_gf
#     - launch_emo
#

export MAVEN_VERSION="3.3.3"
export NODE_NUM_VERSION="v0.12.7"
export NODE_VERSION="node-v0.12.7-linux-x64"
export REDIS_VERSION="redis-3.0.4"
export EL_VERSION="elasticsearch-1.7.1"
export STORM_VERSION="apache-storm-0.9.5"
export ZOOKEEPER_VERSION="zookeeper-3.4.6"
export KAFKA_NUM_VERSION="0.8.2.1"
export KAFKA_VERSION="kafka_2.10-0.8.2.1"

export PATH_TO_GLEANER_REALTIME_JAR="/opt/gleaner-realtime/target/realtime-jar-with-dependencies.jar"
export PATH_TO_L_I_SPACE_WEBAPP="/opt/lostinspace/html/target/webapp"

# used to download sources, executables
function update_tools {
    apt-get update && apt-get install -y nano git wget gcc g++ make openjdk-7-jdk
    cd /opt
    wget http://apache.rediris.es/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz
    tar -xvzf apache-maven-${MAVEN_VERSION}-bin.tar.gz
    cd /
    ln -sf /opt/apache-maven-${MAVEN_VERSION}/bin/mvn /usr/local/bin
}

function update_with_git {
    cd /opt
    git clone https://github.com/$1/$2
    sleep 1s
    cd $2
    git fetch origin $3
    git pull origin $3
    sleep 1s
}

function update_node {    
    cd /tmp
    wget https://nodejs.org/dist/${NODE_NUM_VERSION}/${NODE_VERSION}.tar.gz
    cd /opt
    tar -xvzf /tmp/${NODE_VERSION}.tar.gz
    cd /
    ln -sf /opt/${NODE_VERSION}/bin/* /usr/local/bin
    npm install -g bower
}

function scriptify { # name dir commands...
    TARGET=/opt/${1}.sh
    shift
    cd /opt
    echo "#! /bin/bash" > $TARGET
    echo cd $1 >> $TARGET
    shift 
    echo "$@" >> $TARGET
    cd /opt
    chmod 0755 $TARGET
}

function update_mongo {
    # mongo via apt; see http://docs.mongodb.org/master/tutorial/install-mongodb-on-ubuntu/
    apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 7F0CEB10
    echo "deb http://repo.mongodb.org/apt/ubuntu trusty/mongodb-org/3.0 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-3.0.list
    apt-get update
    apt-get install -y mongodb-org
}

function update_redis {
    cd /opt
    wget http://download.redis.io/releases/${REDIS_VERSION}.tar.gz
    tar xvzf ${REDIS_VERSION}.tar.gz
    cd ${REDIS_VERSION}
    make
    ln -sf /opt/${REDIS_VERSION}/src/redis-server /usr/local/bin
}

function update_el { 
    cd /opt
    wget https://download.elastic.co/elasticsearch/elasticsearch/${EL_VERSION}.deb
    dpkg -i ${EL_VERSION}.deb
}

function update_storm {   
    cd /opt
    wget http://apache.rediris.es/storm/${STORM_VERSION}/${STORM_VERSION}.tar.gz
    tar -xvzf ${STORM_VERSION}.tar.gz
    cd ${STORM_VERSION}/conf
    echo "ui.port: 8081" >> storm.yaml
    cd /
    ln -sf /opt/${STORM_VERSION}/bin/storm /usr/local/bin
}

function update_zookeeper {  
    cd /opt
    wget http://apache.rediris.es/zookeeper/${ZOOKEEPER_VERSION}/${ZOOKEEPER_VERSION}.tar.gz
    tar -xvzf ${ZOOKEEPER_VERSION}.tar.gz
    cd /
    ln -sf /opt/${ZOOKEEPER_VERSION}/bin/zk*.sh /usr/local/bin
    cd /opt/${ZOOKEEPER_VERSION}/conf/
    cp zoo_sample.cfg zoo.cfg
}

function update_kafka {
    cd /opt
    wget http://apache.rediris.es/kafka/${KAFKA_NUM_VERSION}/${KAFKA_VERSION}.tgz
    tar -xvzf ${KAFKA_VERSION}.tgz
    cd /
    ln -sf /opt/${KAFKA_VERSION}/bin/*.sh /usr/local/bin       
}

function update_gleaner_realtime { # updates .m2 cache
    update_with_git RotaruDan gleaner-realtime toledo-09-15
    cd /opt/gleaner-realtime
    mvn clean install
}

function update_openlrs {
    update_with_git RotaruDan OpenLRS toledo-09-15
}

# updates .m2 cache; SLOW
function update_lostinspace {
    update_with_git RotaruDan lostinspace toledo-09-15
    update_with_git e-ucm xmltools master
    cd /opt/xmltools
    mvn clean install
    cd /opt/lostinspace
    mvn clean install -Phtml
}

function update_test_users {
    update_with_git RotaruDan test-users toledo-09-15
    npm install
    npm run fast-setup
    npm run gen-apidoc
   # npm test # requires redis, mongo running
    scriptify test-users test-users npm start
}

# depends: gleaner-realtime
function update_lrs { 
    update_with_git RotaruDan lrs toledo-09-15
    cd /opt/lrs
    echo "exports.defaultValues.realtimeJar='${PATH_TO_GLEANER_REALTIME_JAR}';" >> config-values.js 
    echo "exports.defaultValues.stormPath='/opt/${STORM_VERSION}/bin';" >> config-values.js 
    npm install
    npm run fast-setup
    npm run gen-apidoc
   # npm test # requires redis, mongo running
    scriptify lrs lrs npm start
}

# depends: lost-in-space
function update_gf {
    update_with_git gorco gf toledo-09-15
    cd /opt/gf
    npm install
    bower --allow-root install
    npm run fast-setup

    mkdir app
    mkdir app/public
    rm -rf app/public/lostinspace 
    cp -r ${PATH_TO_L_I_SPACE_WEBAPP} app/public/lostinspace  
    cd app/public/
    wget https://dl.dropboxusercontent.com/u/3300634/inboxed.tar.gz
    tar -xvzf inboxed.tar.gz
    mv webapp inboxed
    scriptify gf gf npm start
}

# front and back-ends for emotions
function update_emo {
    update_with_git gorco emoB master
    cd /opt/emoB
    npm install
    scriptify emoB emoB npm start

    update_with_git gorco emoF master
    cd /opt/emoF
    npm install
    scriptify emoF emoF npm start
}

function update_all {
    update_tools
    update_node
    
    update_mongo
    update_redis
    update_el
    update_storm
    update_zookeeper
    update_kafka
    
    update_gleaner_realtime
    update_openlrs 
    update_lostinspace
    update_test_users
    update_lrs
    update_gf
    update_emo
}

function get_pids { # $! is broken in docker
    ps -Af | grep $1 \
    | tr -s " " "|" | cut -d "|" -f 2 | head -n -1 \
    | xargs
}

function launch_redis {
    PIDFILE="/opt/redis.pid"
    LOGFILE="/opt/redis.log"
    kill $(cat ${PIDFILE})

    # in warning shown when launched otherwise
    echo never > /sys/kernel/mm/transparent_hugepage/enabled    

    (redis-server > ${LOGFILE} 2>&1 & )
    sleep 4s
    PIDS=$(get_pids redis)
    echo -n $PIDS > $PIDFILE
    
    echo "Launched redis: $PIDS"
    cd /opt
}

function launch_mongo {
    PIDFILE="/opt/mongo.pid"
    LOGFILE="/opt/mongo.log"
    kill $(cat ${PIDFILE})

    mkdir /opt/mongoDB
    (mongod --dbpath /opt/mongoDB > ${LOGFILE} 2>&1 & )
    sleep 4s
    PIDS=$(get_pids mongod)
    echo -n $PIDS > $PIDFILE
    
    echo "Launched mongo: $PIDS"
    cd /opt    
}

function launch_el {
    /etc/init.d/elasticsearch restart
    echo "Launched ElasticSearch (via init.d)"
}

function launch_kafka {
    PIDFILE="/opt/kafka.pid"
    LOGFILE="/opt/kafka.log"
    kill $(cat ${PIDFILE})
    
    cd /opt/${KAFKA_VERSION}
    (bin/kafka-server-start.sh config/server.properties > ${LOGFILE} 2>&1 & )
    sleep 4s
    PIDS=$(get_pids kafka_2)
    echo -n $PIDS > $PIDFILE
    
    echo "Launched kafka: $PIDS"
    cd /opt
}

function launch_zookeeper {
    PIDFILE="/opt/zookeeper.pid"
    LOGFILE="/opt/zookeeper.log"
    kill $(cat ${PIDFILE})

    cd /opt/${ZOOKEEPER_VERSION}/bin
    (./zkServer.sh start > ${LOGFILE} 2>&1 & )
    sleep 4s
    PIDS=$(get_pids zookeeper)
    echo -n $PIDS > $PIDFILE

    echo "Launched zookeeper: $PIDS"
    cd /opt
}

function launch_storm {
    PIDFILE="/opt/storm.pid"
    kill $(cat ${PIDFILE})
    
    LOGFILE="/opt/storm_nimbus.log"
    (storm nimbus > ${LOGFILE} 2>&1 & )
    PIDS=$(get_pids nimbus)
    echo -n "$PIDS " > $PIDFILE
    sleep 2s
    
    LOGFILE="/opt/storm_supervisor.log"
    (storm supervisor > ${LOGFILE} 2>&1 & )
    PIDS=$(get_pids supervisor)
    echo -n "$PIDS " >> $PIDFILE
    sleep 2s
    
    LOGFILE="/opt/storm_ui.log"
    (storm ui > ${LOGFILE} 2>&1 & )
    PIDS=$(get_pids .ui)
    echo -n "$PIDS " >> $PIDFILE
    sleep 2s
    
    echo "Launched storm: $PIDS"
    cd /opt
}

function launch_openlrs {
    PIDFILE="/opt/openlrs.pid"
    LOGFILE="/opt/openlrs.log"
    kill $(cat ${PIDFILE})

    cd /opt/OpenLRS
    chmod 0755 run.sh
    echo "Warning - this takes a long time to start (~1m)"
    (./run.sh > ${LOGFILE} 2>&1 & )
    sleep 4s
    PIDS=$(get_pids openlrs)
    echo -n $PIDS > $PIDFILE
    echo "Launched OpenLRS: $PIDS"
    cd /opt
}

function launch_node {
    PIDFILE="/opt/$1.pid"
    LOGFILE="/opt/$1.log"
    kill $(cat ${PIDFILE})
    
    (./$1.sh > ${LOGFILE} 2>&1 & )
    sleep 4s
    PIDS=$(get_pids $1.sh)

    echo -n $PIDS > $PIDFILE
    echo "Launched $1 via Node: $PIDS"
    cd /opt
}

function launch_test_users {
    launch_node test-users
}

function launch_lrs {
    launch_node lrs    
}

function launch_gf {
    launch_node gf
}

function launch_emo {
    launch_node emoB 
    launch_node emoF
}

# WARNING - this is for reference; do not execute directly
# as services take a while to start, and some require others
# to be running to start properly
function launch_all {
    launch_zookeeper # 
    launch_redis
    launch_mongo     # 27017
    launch_el
    launch_storm     # 8081 + internal
    launch_kafka

    launch_openlrs     # 8080
    launch_test_users  # 3000 ; also :3000/api
    launch_lrs         # 3300 ;
    launch_gf          # 3350
    
    launch_emo         # 3111 (frontend); 3232 (be)
}

function log {
    tail -n 100 -f $1
}
