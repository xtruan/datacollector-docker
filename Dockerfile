#
# Copyright 2017 StreamSets Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# https://hub.docker.com/_/eclipse-temurin?tab=tags
# The two valid values for the BASE_IMAGE_TAG argument are 17.x.x_x-jdk-focal if you want to run
# datacollector on Java17 or 8uxxx-bxx-jdk-focal if you want to do so in Java8.
ARG BASE_IMAGE_TAG=8u382-b05-jre-focal
# Begin Data Collector image
FROM eclipse-temurin:$BASE_IMAGE_TAG

ARG SDC_VERSION=3.17.1-0030

RUN apt-get update && \
    apt-get -y install \
    sudo \
    apache2-utils \
    curl \
    krb5-user \
    protobuf-compiler \
    psmisc \
    lsb-release

# Used for configuring DNS resolution priority
RUN echo 'hosts: files mdns4_minimal [NOTFOUND=return] dns mdns4' >> /etc/nsswitch.conf

# We need to set up GMT as the default timezone to maintain compatibility
RUN ln -fs /usr/share/zoneinfo/GMT /etc/localtime && \
    dpkg-reconfigure -f noninteractive tzdata

# We set a UID/GID for the SDC user because certain test environments require these to be consistent throughout
# the cluster. We use 20159 because it's above the default value of YARN's min.user.id property.
ARG SDC_UID=20159
ARG SDC_GID=20159

# Begin Data Collector installation
ARG SDC_URL=https://archives.streamsets.com/datacollector/${SDC_VERSION}/tarball/streamsets-datacollector-all-${SDC_VERSION}.tgz
ARG SDC_USER=sdc
# SDC_HOME is where executables and related files are installed. Used in setup_mapr script.
ARG SDC_HOME="/opt/streamsets-datacollector-${SDC_VERSION}"

# The paths below should generally be attached to a VOLUME for persistence.
# SDC_CONF is where configuration files are stored. This can be shared.
# SDC_DATA is a volume for storing collector state. Do not share this between containers.
# SDC_LOG is an optional volume for file based logs.
# SDC_RESOURCES is where resource files such as runtime:conf resources and Hadoop configuration can be placed.
# STREAMSETS_LIBRARIES_EXTRA_DIR is where extra libraries such as JDBC drivers should go.
# USER_LIBRARIES_DIR is where custom stage libraries are installed.
ENV SDC_CONF=/etc/sdc \
    SDC_DATA=/data \
    SDC_DIST=${SDC_HOME} \
    SDC_HOME=${SDC_HOME} \
    SDC_LOG=/logs \
    SDC_RESOURCES=/resources \
    USER_LIBRARIES_DIR=/opt/streamsets-datacollector-user-libs
ENV STREAMSETS_LIBRARIES_EXTRA_DIR="${SDC_DIST}/streamsets-libs-extras"

# Copy local sdc-dist directory to SDC_DIST directory.
# COPY sdc-dist ${SDC_DIST}
# RUN mv ${SDC_DIST}/etc ${SDC_CONF}

ENV SDC_JAVA_OPTS="-Dfile.encoding=UTF-8 -Dsun.jnu.encoding=UTF-8"

# Run the SDC configuration script.
COPY sdc-configure.sh *.tgz /tmp/
RUN /tmp/sdc-configure.sh

# Set any additional stage libraries if requested
#ARG SDC_LIBS="streamsets-datacollector-aerospike-lib,streamsets-datacollector-apache-kafka_1_0-lib,streamsets-datacollector-apache-kafka_2_0-lib,streamsets-datacollector-apache-kudu_1_7-lib,streamsets-datacollector-apache-solr_6_1_0-lib,streamsets-datacollector-aws-lib,streamsets-datacollector-aws-secrets-manager-credentialstore-lib,streamsets-datacollector-azure-keyvault-credentialstore-lib,streamsets-datacollector-azure-lib,streamsets-datacollector-basic-lib,streamsets-datacollector-bigtable-lib,streamsets-datacollector-cassandra_3-lib,streamsets-datacollector-cdh-spark_2_3_r4-lib,streamsets-datacollector-cdh_5_16-lib,streamsets-datacollector-cdh_6_3-lib,streamsets-datacollector-cdh_kafka_3_1-lib,streamsets-datacollector-cdh_kafka_4_1-lib,streamsets-datacollector-cdh_spark_2_1_r1-lib,streamsets-datacollector-couchbase_5-lib,streamsets-datacollector-crypto-lib,streamsets-datacollector-cyberark-credentialstore-lib,streamsets-datacollector-databricks-ml_2-lib,streamsets-datacollector-dataformats-lib,streamsets-datacollector-dev-lib,streamsets-datacollector-elasticsearch_5-lib,streamsets-datacollector-emr_hadoop_2_8_3-lib,streamsets-datacollector-google-cloud-lib,streamsets-datacollector-groovy_2_4-lib,streamsets-datacollector-hdp_3_1-lib,streamsets-datacollector-influxdb_0_9-lib,streamsets-datacollector-jdbc-lib,streamsets-datacollector-jdbc-sap-hana-lib,streamsets-datacollector-jks-credentialstore-lib,streamsets-datacollector-jms-lib,streamsets-datacollector-jython_2_7-lib,streamsets-datacollector-kinesis-lib,streamsets-datacollector-kinetica_6_0-lib,streamsets-datacollector-kinetica_6_1-lib,streamsets-datacollector-kinetica_6_2-lib,streamsets-datacollector-kinetica_7_0-lib,streamsets-datacollector-mapr_6_0-lib,streamsets-datacollector-mapr_6_0-mep4-lib,streamsets-datacollector-mapr_6_0-mep5-lib,streamsets-datacollector-mapr_6_1-lib,streamsets-datacollector-mapr_6_1-mep6-lib,streamsets-datacollector-mleap-lib,streamsets-datacollector-mongodb_3-lib,streamsets-datacollector-mongodb_4-lib,streamsets-datacollector-mysql-binlog-lib,streamsets-datacollector-omniture-lib,streamsets-datacollector-orchestrator-lib,streamsets-datacollector-rabbitmq-lib,streamsets-datacollector-redis-lib,streamsets-datacollector-salesforce-lib,streamsets-datacollector-stats-lib,streamsets-datacollector-tensorflow-lib,streamsets-datacollector-thycotic-credentialstore-lib,streamsets-datacollector-vault-credentialstore-lib,streamsets-datacollector-wholefile-transformer-lib,streamsets-datacollector-windows-lib"
ARG SDC_LIBS=""
# Fix sha1sum error
RUN sed -i "s/run sha1sum -s -c/run sha1sum -c/" ${SDC_DIST}/libexec/_stagelibs
# Install any additional stage libraries if requested
RUN if [ -n "${SDC_LIBS}" ]; then "${SDC_DIST}/bin/streamsets" stagelibs -install="${SDC_LIBS}"; fi

# Copy files in $PROJECT_ROOT/resources dir to the SDC_RESOURCES dir.
COPY resources/ ${SDC_RESOURCES}/
RUN sudo chown -R sdc:sdc ${SDC_RESOURCES}/

# Copy local "sdc-extras" libs to STREAMSETS_LIBRARIES_EXTRA_DIR.
# Local files should be placed in appropriate stage lib subdirectories.  For example
# to add a JDBC driver like my-jdbc.jar to the JDBC stage lib, the local file my-jdbc.jar
# should be at the location $PROJECT_ROOT/sdc-extras/streamsets-datacollector-jdbc-lib/lib/my-jdbc.jar
COPY sdc-extras/ ${STREAMSETS_LIBRARIES_EXTRA_DIR}/

# Get JDBC drivers if they were not already provided in sdc-extras
ARG PG_JDBC_DRIVER=postgresql-42.6.0
ARG MYSQL_JDBC_DRIVER=mysql-connector-j-8.0.33

COPY sdc-get-jdbc-libs.sh /tmp/
RUN /tmp/sdc-get-jdbc-libs.sh

RUN sudo chown -R sdc:sdc ${STREAMSETS_LIBRARIES_EXTRA_DIR}/

USER ${SDC_USER}
EXPOSE 18630
COPY docker-entrypoint.sh /
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["dc"]
