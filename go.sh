#!/bin/bash

#######
#
#  This file is intended to be run 
#  - as root,
#  - within a bare Ubuntu 14.04 docker image
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
    apt-get update && apt-get install -y git wget gcc g++ make openjdk-7-jdk
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
    npm test
}

# depends: gleaner-realtime
function update_lrs { 
    update_with_git RotaruDan lrs toledo-09-15
    cd /opt/lrs
    echo "exports.defaultValues.realtimeJar='${PATH_TO_GLEANER_REALTIME_JAR}';" >> config-values.js 
    echo "exports.defaultValues.stormPath='/opt/${STORM_VERSION}';" >> config-values.js 
    npm install
    npm run fast-setup
    npm run gen-apidoc
    npm test
}

# depends: lost-in-space
function update_gf {
    update_with_git gorco gf toledo-09-15
    cd /opt/gf
    npm install
    bower install
    npm run fast-setup

    mkdir app
    mkdir app/public
    rm -rf app/public/lostinspace 
    cp -r ${PATH_TO_L_I_SPACE_WEBAPP} app/public/lostinspace  
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
}

function launch_redis {
    PIDFILE="/opt/redis.pid"
    LOGFILE="/opt/redis.log"
    kill $(cat ${PIDFILE})

    # in warning shown when launched otherwise
    echo never > /sys/kernel/mm/transparent_hugepage/enabled    

    (redis-server > ${LOGFILE} 2>&1 & )
    PIDS=$!
    echo -n $PIDS > $PIDFILE
    sleep 2s
    
    echo "Launched redis: $PIDS"
}

function launch_mongo {
    PIDFILE="/opt/mongo.pid"
    LOGFILE="/opt/mongo.log"
    kill $(cat ${PIDFILE})

    mkdir /opt/mongoDB
    (mongod --dbpath /opt/mongoDB > ${LOGFILE} 2>&1 & )
    PIDS=$!
    echo -n $PIDS > $PIDFILE
    sleep 2s
    
    echo "Launched mongo: $PIDS"
}

function launch_el {
    /etc/init.d/elasticsearch restart
    sleep 2s    
    
    echo "Launched ElasticSearch (via init.d)"
}

function launch_kafka {
    PIDFILE="/opt/kafka.pid"
    LOGFILE="/opt/kafka.log"
    kill $(cat ${PIDFILE})
    
    cd /opt/${KAFKA_VERSION}
    (bin/kafka-server-start.sh config/server.properties > ${LOGFILE} 2>&1 & )
    PIDS=$!
    echo -n $PIDS > $PIDFILE
    sleep 2s
    
    echo "Launched kafka: $PIDS"
}

function launch_zookeeper {
    PIDFILE="/opt/zookeeper.pid"
    LOGFILE="/opt/zookeeper.log"
    kill $(cat ${PIDFILE})

    (zkServer.sh start > ${LOGFILE} 2>&1 & )
    PIDS=$!
    echo -n $PIDS > $PIDFILE
    sleep 2s

    echo "Launched zookeeper: $PIDS"
}

function launch_storm {
    PIDFILE="/opt/storm.pid"
    kill $(cat ${PIDFILE})
    
    LOGFILE="/opt/storm_nimbus.log"
    (storm nimbus > ${LOGFILE} 2>&1 & )
    PIDS=$!
    echo -n "$PIDS " > $PIDFILE
    sleep 2s
    
    LOGFILE="/opt/storm_supervisor.log"
    (storm supervisor > ${LOGFILE} 2>&1 & )
    PIDS=$!
    echo -n "$PIDS " > $PIDFILE
    sleep 2s
    
    LOGFILE="/opt/storm_ui.log"
    (storm ui > ${LOGFILE} 2>&1 & )
    PIDS=$!
    echo -n "$PIDS " > $PIDFILE
    sleep 2s
    
    echo "Launched storm: $PIDS"
}

function launch_openlrs {
    PIDFILE="/opt/openlrs.pid"
    LOGFILE="/opt/openlrs.log"
    kill $(cat ${PIDFILE})

    cd /opt/OpenLRS
    chmod 0755 run.sh
    (./run.sh > ${LOGFILE} 2>&1 & )
    echo "Waiting for OpenLRS..."
    sleep 20s

    PIDS="$(ps -Af | grep OpenLRS | tr -s " " "|" | cut -d "|" -f 2 | head -n 2 | xargs)"
    echo -n $PIDS > $PIDFILE
    echo "Launched OpenLRS: $PIDS"
}

function launch_node {
    PIDFILE="/opt/$1.pid"
    LOGFILE="/opt/$1.log"
    kill $(cat ${PIDFILE})
    
    cd /opt/$1
    (npm start > ${LOGFILE} 2>&1 & )
    PIDS=$!
    sleep 2s

    echo -n $PIDS > $PIDFILE
    echo "Launched $1 via Node: $PIDS"
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

function launch_all {
    launch_zookeeper # 
    launch_redis
    launch_mongo     # 27017
    launch_el
    launch_storm     # 8081 + internal
    launch_kafka

    launch_openlrs   # 3000 ; also :3000/api
    launch_lrs       # 3300 ;
    launch_gf        # 3350
}
