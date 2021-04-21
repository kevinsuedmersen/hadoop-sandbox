#!/bin/bash

# Set some sensible defaults
export CORE_CONF_fs_defaultFS=${CORE_CONF_fs_defaultFS:-hdfs://`hostname -f`:8020}

function addProperty() {
  local path=$1
  local name=$2
  local value=$3

  local entry="<property><name>$name</name><value>${value}</value></property>"
  local escapedEntry=$(echo $entry | sed 's/\//\\\//g')
  sed -i "/<\/configuration>/ s/.*/${escapedEntry}\n&/" $path
}

function configure() {
    local path=$1
    local module=$2
    local envPrefix=$3

    local var
    local value
    
    echo "Configuring $module"
    for c in `printenv | perl -sne 'print "$1 " if m/^${envPrefix}_(.+?)=.*/' -- -envPrefix=$envPrefix`; do 
        name=`echo ${c} | perl -pe 's/___/-/g; s/__/@/g; s/_/./g; s/@/_/g;'`
        var="${envPrefix}_${c}"
        value=${!var}
        echo " - Setting $name=$value"
        addProperty /etc/hadoop/$module-site.xml $name "$value"
    done
}

configure /etc/hadoop/core-site.xml core CORE_CONF
configure /etc/hadoop/hdfs-site.xml hdfs HDFS_CONF
configure /etc/hadoop/yarn-site.xml yarn YARN_CONF
configure /etc/hadoop/httpfs-site.xml httpfs HTTPFS_CONF
configure /etc/hadoop/kms-site.xml kms KMS_CONF
configure /etc/hadoop/mapred-site.xml mapred MAPRED_CONF

if [ "$MULTIHOMED_NETWORK" = "1" ]; then
    echo "Configuring for multihomed network"

    # HDFS
    addProperty /etc/hadoop/hdfs-site.xml dfs.namenode.rpc-bind-host 0.0.0.0
    addProperty /etc/hadoop/hdfs-site.xml dfs.namenode.servicerpc-bind-host 0.0.0.0
    addProperty /etc/hadoop/hdfs-site.xml dfs.namenode.http-bind-host 0.0.0.0
    addProperty /etc/hadoop/hdfs-site.xml dfs.namenode.https-bind-host 0.0.0.0
    addProperty /etc/hadoop/hdfs-site.xml dfs.client.use.datanode.hostname true
    addProperty /etc/hadoop/hdfs-site.xml dfs.datanode.use.datanode.hostname true

    # YARN
    addProperty /etc/hadoop/yarn-site.xml yarn.resourcemanager.bind-host 0.0.0.0
    addProperty /etc/hadoop/yarn-site.xml yarn.nodemanager.bind-host 0.0.0.0
    addProperty /etc/hadoop/yarn-site.xml yarn.nodemanager.bind-host 0.0.0.0
    addProperty /etc/hadoop/yarn-site.xml yarn.timeline-service.bind-host 0.0.0.0

    # MAPRED
    addProperty /etc/hadoop/mapred-site.xml yarn.nodemanager.bind-host 0.0.0.0
fi

if [ -n "$GANGLIA_HOST" ]; then
    mv /etc/hadoop/hadoop-metrics.properties /etc/hadoop/hadoop-metrics.properties.orig
    mv /etc/hadoop/hadoop-metrics2.properties /etc/hadoop/hadoop-metrics2.properties.orig

    for module in mapred jvm rpc ugi; do
        echo "$module.class=org.apache.hadoop.metrics.ganglia.GangliaContext31"
        echo "$module.period=10"
        echo "$module.servers=$GANGLIA_HOST:8649"
    done > /etc/hadoop/hadoop-metrics.properties
    
    for module in namenode datanode resourcemanager nodemanager mrappmaster jobhistoryserver; do
        echo "$module.sink.ganglia.class=org.apache.hadoop.metrics2.sink.ganglia.GangliaSink31"
        echo "$module.sink.ganglia.period=10"
        echo "$module.sink.ganglia.supportsparse=true"
        echo "$module.sink.ganglia.slope=jvm.metrics.gcCount=zero,jvm.metrics.memHeapUsedM=both"
        echo "$module.sink.ganglia.dmax=jvm.metrics.threadsBlocked=70,jvm.metrics.memHeapUsedM=40"
        echo "$module.sink.ganglia.servers=$GANGLIA_HOST:8649"
    done > /etc/hadoop/hadoop-metrics2.properties
fi

function wait_for_it()
{
    local serviceport=$1
    local service=${serviceport%%:*}
    local port=${serviceport#*:}
    local retry_seconds=5
    local max_try=100
    let i=1

    nc -z $service $port
    result=$?

    until [ $result -eq 0 ]; do
      echo "[$i/$max_try] check for ${service}:${port}..."
      echo "[$i/$max_try] ${service}:${port} is not available yet"
      if (( $i == $max_try )); then
        echo "[$i/$max_try] ${service}:${port} is still not available; giving up after ${max_try} tries. :/"
        exit 1
      fi
      
      echo "[$i/$max_try] try in ${retry_seconds}s once again ..."
      let "i++"
      sleep $retry_seconds

      nc -z $service $port
      result=$?
    done
    echo "[$i/$max_try] $service:${port} is available."
}

for i in ${SERVICE_PRECONDITION[@]}
do
    wait_for_it ${i}
done

# remove problematic package source
sed -i '$ d' /etc/apt/sources.list

# create user from env 
useradd -s /bin/bash -p $(openssl passwd $ADMIN_PASSWORD) $ADMIN_NAME
chown -R $ADMIN_NAME /home/$ADMIN_NAME/

# install python
if [[ $INSTALL_PYTHON == "true" ]]; then
  apt-get update
  echo Y | apt-get install nano python
fi

# install sqoop
if [[ $INSTALL_SQOOP == "true" ]]; then
     
  echo "export HADOOP_MAPRED_HOME=/opt/hadoop-3.2.1" >> /root/.bashrc
  echo "export HADOOP_COMMON_HOME=/opt/hadoop-3.2.1" >> /root/.bashrc
  echo "export HADOOP_HDFS_HOME=/opt/hadoop-3.2.1" >> /root/.bashrc
  echo "export YARN_HOME=/opt/hadoop-3.2.1" >> /root/.bashrc
  echo "export HADOOP_COMMON_LIB_NATIVE_DIR=/opt/hadoop-3.2.1/lib/native" >> /root/.bashrc
  echo "export SQOOP_HOME=/usr/lib/sqoop" >> /root/.bashrc

  echo "export HADOOP_MAPRED_HOME=/opt/hadoop-3.2.1" >> /home/$ADMIN_NAME/.bashrc
  echo "export HADOOP_COMMON_HOME=/opt/hadoop-3.2.1" >> /home/$ADMIN_NAME/.bashrc
  echo "export HADOOP_HDFS_HOME=/opt/hadoop-3.2.1" >> /home/$ADMIN_NAME/.bashrc
  echo "export YARN_HOME=/opt/hadoop-3.2.1" >> /home/$ADMIN_NAME/.bashrc
  echo "export HADOOP_COMMON_LIB_NATIVE_DIR=/opt/hadoop-3.2.1/lib/native" >> /home/$ADMIN_NAME/.bashrc
  echo "export SQOOP_HOME=/usr/lib/sqoop" >> /home/$ADMIN_NAME/.bashrc

  cd /tmp

  curl http://us.mirrors.quenda.co/apache/sqoop/1.4.7/sqoop-1.4.7.bin__hadoop-2.6.0.tar.gz --output sqoop-1.4.7.bin__hadoop-2.6.0.tar.gz
  tar -xvf sqoop-1.4.7.bin__hadoop-2.6.0.tar.gz
  mv sqoop-1.4.7.bin__hadoop-2.6.0/ /usr/lib/sqoop
  echo "export PATH=$PATH:/usr/lib/sqoop/bin" >> /root/.bashrc
  echo "export PATH=$PATH:/usr/lib/sqoop/bin" >> /home/$ADMIN_NAME/.bashrc

  curl https://downloads.mysql.com/archives/get/file/mysql-connector-java-8.0.16.tar.gz --output mysql-connector-java-8.0.16.tar.gz
  tar -xvf mysql-connector-java-8.0.16.tar.gz
  mv mysql-connector-java-8.0.16/mysql-connector-java-8.0.16.jar /usr/lib/sqoop/lib

  curl https://jdbc.postgresql.org/download/postgresql-42.2.6.jar --output postgresql-42.2.6.jar
  mv postgresql-42.2.6.jar /usr/lib/sqoop/lib

  mv /usr/lib/sqoop/conf/sqoop-env-template.sh /usr/lib/sqoop/conf/sqoop-env.sh
  echo "export HADOOP_COMMON_HOME=/opt/hadoop-3.2.1" >> /usr/lib/sqoop/conf/sqoop-env.sh
  echo "export HADOOP_MAPRED_HOME=/opt/hadoop-3.2.1" >> /usr/lib/sqoop/conf/sqoop-env.sh

  rm sqoop-1.4.7.bin__hadoop-2.6.0.tar.gz
  rm mysql-connector-java-8.0.16.tar.gz

fi

exec $@
