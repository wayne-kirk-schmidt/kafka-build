#!/usr/bin/env bash

### Set up basic path and permissions to assist the script
umask 022
export PATH="/usr/bin:/usr/local/bin:/sbin:/usr/sbin:$PATH"

### Define the bin and the etc directory as related to the running script
BINDIR=$(dirname "$(realpath "$0")")
ETCDIR=$( realpath "$BINDIR"/../etc )

### Define the download directory
export DOWNLOAD_DIR="/var/tmp/downloads"

### Setup apt-get and following scripts to be non-interactive
export DEBIAN_FRONTEND=noninteractive

### Prepare the machine for installation
apt-get update -y && apt-get upgrade -y

### Disable snapd. We will be treating this as a static appliance.
systemctl stop snapd
systemctl disable snapd
systemctl mask snapd
apt-get remove -y snapd
apt-get purge -y snapd

### Now install basic packages that can be easily installed by apt-get
apt-get install -y vim openjdk-11-jre-headless openjdk-11-jdk \
zookeeper wget apt-transport-https ca-certificates \
curl gnupg-agent gnupg software-properties-common

### Now Prepare to install logstash
ELASTICKEY="/usr/share/keyrings/elastic-keyring.gpg"
ELASTICSRC="https://artifacts.elastic.co/packages/8.x/apt"

wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | \
        gpg --dearmor -o "$ELASTICKEY"

echo "deb [signed-by=$ELASTICKEY] $ELASTICSRC stable main" | \
        sudo tee -a /etc/apt/sources.list.d/elastic-8.x.list

### Now install logstash
apt-get update -y
apt-get install -y logstash

### Prepare download directory for non debian package installations
mkdir -p ${DOWNLOAD_DIR}
cd ${DOWNLOAD_DIR} || exit

### Retrieve the Kafka installation image
### wget https://downloads.apache.org/kafka/3.6.0/kafka_2.13-3.6.0.tgz

BASEURL="https://downloads.apache.org/kafka/"

KAFKA_BASE=$( curl -s "${BASEURL}" | \
        grep -E -i "\[DIR\]" | grep -o -E 'href="[^"]+"' | \
        cut -d'"' -f2 | sed 's/\///' | sort -rbn | head -1 )

KAFKA_FILE=$( curl -s "${BASEURL}/${KAFKA_BASE}/" | \
        grep -E -i '\[\s+\]' | grep -E -iv '(src|docs).tgz' | \
        grep -o -E 'href="[^"]+"' | cut -d'"' -f2 | sort -rbn | head -1 )

rm -f "${DOWNLOAD_DIR}/${KAFKA_FILE}"

wget "${BASEURL}${KAFKA_BASE}/${KAFKA_FILE}"

### Unpack and install the installation image
KAFKAFILE=$( ls -1d kafka*.tgz)

tar -xf "$KAFKAFILE"

KAFKADIR=$( basename "$KAFKAFILE" .tgz )
KAFKA_BASE_DIR="/usr/local/kafka"
mkdir -p "${KAFKA_BASE_DIR}"

KAFKA_ETC_DIR="/etc/kafka"
mkdir -p "${KAFKA_ETC_DIR}"

KAFKA_SVC_DIR="/etc/systemd/system"
mkdir -p "${KAFKA_SVC_DIR}"

KAFKA_DATA_DIR="/var/local/data/kafka"
ZOOKEEPER_DATA_DIR="/var/local/data/zookeeper"
mkdir -p "${KAFKA_DATA_DIR}" "${ZOOKEEPER_DATA_DIR}"

KAFKA_LOGS_DIR="/var/log/kafka"
ZOOKEEPER_LOGS_DIR="/var/log/zookeeper"
mkdir -p "${KAFKA_LOGS_DIR}" "${ZOOKEEPER_LOGS_DIR}"

mv "$KAFKADIR"/* "${KAFKA_BASE_DIR}"

touch "${KAFKA_BASE_DIR}/$KAFKADIR"

rm -f "${DOWNLOAD_DIR}/${KAFKA_FILE}"

### Setup the appropriate variables for the properties files
SRC_KAFKA_CFG="$ETCDIR/server.properties"
SRC_ZOOKEEPER_CFG="$ETCDIR/zookeeper.properties"

DST_KAFKA_CFG="$KAFKA_ETC_DIR/server.properties"
DST_ZOOKEEPER_CFG="$KAFKA_ETC_DIR/zookeeper.properties"

### Install the appropriate configuration files
cp "${SRC_KAFKA_CFG}" "${DST_KAFKA_CFG}"
cp "${SRC_ZOOKEEPER_CFG}" "${DST_ZOOKEEPER_CFG}"

### Setup the appropriate variables for the Service definition files
SRC_KAFKA_SVC="$ETCDIR/kafka.service"
SRC_ZOOKEEPER_SVC="$ETCDIR/zookeeper.service"

DST_KAFKA_SVC="$KAFKA_SVC_DIR/kafka.service"
DST_ZOOKEEPER_SVC="$KAFKA_SVC_DIR/zookeeper.service"

### Install the appropriate service definition files
cp "${SRC_KAFKA_SVC}" "${DST_KAFKA_SVC}"
cp "${SRC_ZOOKEEPER_SVC}" "${DST_ZOOKEEPER_SVC}"

### Now start the kafka service
systemctl start kafka
systemctl enable kafka
systemctl status kafka | grep -E -i 'Active|PID'

### Now start the zookeeper service
systemctl start zookeeper
systemctl enable zookeeper
systemctl status zookeeper | grep -E -i 'Active|PID'

### Now start the logstash service
systemctl start logstash
systemctl enable logstash
systemctl status logstash | grep -E -i 'Active|PID'
