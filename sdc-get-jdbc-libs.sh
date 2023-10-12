#!/usr/bin/env bash
set -e
set -x

# Check if streamsets-datacollector-jdbc-lib already exists, if not create its artifact of things.
if [ ! -d "${STREAMSETS_LIBRARIES_EXTRA_DIR}/streamsets-datacollector-jdbc-lib/lib" ]; then
    mkdir -p ${STREAMSETS_LIBRARIES_EXTRA_DIR}/streamsets-datacollector-jdbc-lib/lib
    curl -k -f "https://jdbc.postgresql.org/download/${PG_JDBC_DRIVER}.jar" -L -o ${STREAMSETS_LIBRARIES_EXTRA_DIR}/streamsets-datacollector-jdbc-lib/lib/${PG_JDBC_DRIVER}.jar
    curl -k -f "https://downloads.mysql.com/archives/get/p/3/file/${MYSQL_JDBC_DRIVER}.tar.gz" -L -o /tmp/${MYSQL_JDBC_DRIVER}.tar.gz && \
        tar -xzf /tmp/${MYSQL_JDBC_DRIVER}.tar.gz -C /tmp/ && \
        mv /tmp/${MYSQL_JDBC_DRIVER}/${MYSQL_JDBC_DRIVER}.jar ${STREAMSETS_LIBRARIES_EXTRA_DIR}/streamsets-datacollector-jdbc-lib/lib/${MYSQL_JDBC_DRIVER}.jar
fi;