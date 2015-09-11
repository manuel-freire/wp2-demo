#!/bin/bash

#######
# 
#  This file is intended to be used within a bare Ubuntu 14.04 docker image
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
   
# used to download sources, executables
function update_tools {
    apt-get update && apt-get install -y git wget gcc make openjdk-7-jdk
    
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
    git pull origin master
    sleep 1s
}

function update_sources {
    update_with_git RotaruDan OpenLRS
    update_with_git RotaruDan test-users
    update_with_git RotaruDan lrs # broken: pangyp!
    update_with_git gorco gf
    update_with_git RotaruDan gleaner-realtime
    update_with_git RotaruDan gleaner-tracker
    update_with_git RotaruDan lostinspace
    update_with_git e-ucm xmltools
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

function update_gleaner_realtime {
    cd /opt/gleaner-realtime
    mvn clean install
}

function update_lostinspace {
    cd /opt/xmltools
    mvn clean install
    cd /opt/lostinspace
    mvn clean install -Phtml
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
    update_sources
    update_gleaner_realtime 
}

function launch_redis {
    # in warning shown when launched otherwise
    echo never > /sys/kernel/mm/transparent_hugepage/enabled    
    redis-server &
    sleep 2s
}

function launch_mongo {
    mkdir /opt/mongoDB
    mongod --dbpath /opt/mongoDB &
    sleep 2s    
}

function launch_el {
    /etc/init.d/elasticsearch start
    sleep 2s    
}

function launch_kafka {
    cd /opt/${KAFKA_VERSION}
    bin/kafka-server-start.sh config/server.properties &
    sleep 2s
}

function launch_zookeeper {
    zkServer.sh start &
    sleep 2s
}

function launch_storm {
    storm nimbus &
    sleep 2s
    storm supervisor &
    sleep 2s
    storm ui &
    sleep 2s
}

function launch_openlrs {
    cd /opt/OpenLRS/src/main/resources
    echo "spring.profiles.include: redis,elasticsearch" > application-dev.properties
    echo "openlrs.tierOneStorage=RedisPubSubTierOneStorage" >> application-dev.properties
    echo "openlrs.tierTwoStorage=XApiOnlyElasticsearchTierTwoStorage" >> application-dev.properties
    cd /opt/OpenLRS
    mvn clean package spring-boot:run  -Drun.jvmArguments="-Dspring.config.location=./application-dev.properties" &
    sleep 2s
}

function launch_node {
    cd /opt/$1
    npm install
    npm run fast-setup
    npm run gen-apidoc
    npm start &
    sleep 2s
}

function launch_test_users {
    launch_node test-users
}

function launch_lrs {
    cd /opt/lrs
    echo "exports.defaultValues.realtimeJar='${PATH_TO_GLEANER_REALTIME_JAR}';" >> config-values.js 
    echo "exports.defaultValues.stormPath='/opt/${STORM_VERSION}';" >> config-values.js 

    # y ahora falta copiar aqui el LostInSpace

    launch_node lrs    
}

function launch_gf {
    launch_node gf
}

function launch_gf {
    cd /opt/gf
    npm install
    bower install
    npm run fast-setup
    npm start &
    sleep 2s
}

function launch_all {
    launch_zookeeper # 
    launch_redis
    launch_mongo     # 27017
    launch_el
    launch_storm     # 8081 + internal
    launch_kafka
    launch_openlrs   # 3000 ; also :3000/api
    launch_lrs       # 3300 ; errores
    launch_gf        # 3350
}
