
FROM ubuntu as archive

ARG HADOOP_VERSION
ARG HIVE_VERSION
ARG TEZ_VERSION
RUN apt-get update && apt-get -y install wget
RUN wget https://archive.apache.org/dist/tez/$TEZ_VERSION/apache-tez-$TEZ_VERSION-bin.tar.gz && \
    wget https://archive.apache.org/dist/hadoop/core/hadoop-$HADOOP_VERSION/hadoop-$HADOOP_VERSION.tar.gz && \
    wget https://archive.apache.org/dist/hive/hive-$HIVE_VERSION/apache-hive-$HIVE_VERSION-bin.tar.gz

RUN mv /apache-tez-$TEZ_VERSION-bin.tar.gz /opt && \
    mv hadoop-$HADOOP_VERSION.tar.gz /opt && \
    mv apache-hive-$HIVE_VERSION-bin.tar.gz /opt

RUN tar -xzvf /opt/hadoop-$HADOOP_VERSION.tar.gz -C /opt/ && \
    rm -rf /opt/hadoop-$HADOOP_VERSION/share/doc/* && \
    tar -xzvf /opt/apache-hive-$HIVE_VERSION-bin.tar.gz -C /opt/ && \
    rm -rf /opt/apache-hive-$HIVE_VERSION-bin/jdbc/* && \
    tar -xzvf /opt/apache-tez-$TEZ_VERSION-bin.tar.gz -C /opt && \
    rm -rf /opt/apache-tez-$TEZ_VERSION-bin/share/*

FROM openjdk:8-jre-slim AS run

ENV HADOOP_VERSION=3.3.1
ENV HIVE_VERSION=4.0.0-beta-1
ENV TEZ_VERSION=0.10.2
ARG HADOOP_VERSION
ARG HIVE_VERSION
ARG TEZ_VERSION
COPY --from=archive /opt/hadoop-$HADOOP_VERSION /opt/hadoop
COPY --from=archive /opt/apache-hive-$HIVE_VERSION-bin /opt/hive
COPY --from=archive /opt/apache-tez-$TEZ_VERSION-bin /opt/tez

# Install dependencies
RUN set -ex; \
    apt-get update; \
    apt-get -y install procps curl netcat telnet iputils-ping wget --no-install-recommends; \
    rm -rf /var/lib/apt/lists/*


# Set necessary environment variables.
ENV HADOOP_HOME=/opt/hadoop \
    HIVE_HOME=/opt/hive \
    TEZ_HOME=/opt/tez \
    HIVE_VER=$HIVE_VERSION

ENV PATH=$HIVE_HOME/bin:$HADOOP_HOME/bin:$PATH
ENV AWS_SDK_VERSION=1.11.1026
ENV HADOOP_LIB_PATH=${HADOOP_HOME}/share/hadoop/common/lib

COPY ./jars/postgresql-42.2.16.jar ${HADOOP_LIB_PATH}/postgresql-42.2.16.jar 
COPY ./jars/aws-java-sdk-$AWS_SDK_VERSION.jar ${HADOOP_LIB_PATH}/aws-java-sdk-$AWS_SDK_VERSION.jar
COPY ./jars/aws-java-sdk-bundle-$AWS_SDK_VERSION.jar ${HADOOP_LIB_PATH}/aws-java-sdk-bundle-$AWS_SDK_VERSION.jar
COPY ./jars/hadoop-aws-$HADOOP_VERSION.jar ${HADOOP_LIB_PATH}/hadoop-aws-$HADOOP_VERSION.jar
COPY ./jars/hadoop-common-$HADOOP_VERSION.jar ${HADOOP_LIB_PATH}/hadoop-common-$HADOOP_VERSION.jar

RUN cp ${HADOOP_HOME}/share/hadoop/common/lib/* ${HIVE_HOME}/lib/ 
RUN cp ${HADOOP_HOME}/share/hadoop/common/lib/* ${TEZ_HOME}/lib/ 

RUN rm -f ${HADOOP_LIB_PATH}/slf4j-log4j12-*.jar 
RUN rm -f ${HIVE_HOME}/lib/slf4j-log4j12-*.jar 
RUN rm -f ${TEZ_HOME}/lib/slf4j-log4j12-*.jar ${TEZ_HOME}/lib/slf4j-reload4j-1.7.36.jar


COPY entrypoint.sh /
COPY configurations/hive/hive-site.xml $HIVE_HOME/conf/hive-site.xml
COPY configurations/hive/hive-log4j2.properties $HIVE_HOME/conf/hive-log4j2.properties
COPY configurations/hive/web-hcat-default.xml ${HIVE_HOME}/hcatalog/etc/webhcat/webhcat-default.xml
COPY configurations/hadoop/core-site.xml $HADOOP_HOME/etc/hadoop/core-site.xml
COPY configurations/tez/tez-site.xml $TEZ_HOME/conf/hive-site.xml
RUN chmod +x /entrypoint.sh

ARG UID=1000
RUN adduser --no-create-home --disabled-login --gecos "" --uid $UID hive && \
    chown hive /opt/tez && \
    chown hive /opt/hive && \
    chown hive /opt/hadoop && \
    chown hive /opt/hive/conf 

USER hive
WORKDIR /opt/hive
EXPOSE 10000 10002 9083
ENTRYPOINT ["sh", "-c", "/entrypoint.sh"]
