# # build
# FROM eclipse-temurin:17-jdk-jammy AS builder
# RUN apt-get update && apt-get install -y curl unzip 
# RUN curl -L -o /tmp/nifi.zip https://archive.apache.org/dist/nifi/1.26.0/nifi-1.26.0-bin.zip && \
#     unzip -q /tmp/nifi.zip -d /opt && mv /opt/nifi-1.26.0 /opt/nifi-build

# # run
# FROM eclipse-temurin:17-jdk-jammy
# COPY --from=builder /opt/nifi-build /opt/nifi
# COPY conf/nifi.properties /opt/nifi/conf/nifi.properties
# WORKDIR /opt/nifi
# ENTRYPOINT ["bin/nifi.sh"]
# CMD ["run"]


FROM apache/nifi:1.26.0 AS base

FROM eclipse-temurin:17-jdk-jammy
RUN groupadd -g 1000 nifi \
 && useradd -u 1000 -g 1000 -m -s /bin/bash nifi
ENV NIFI_BASE_DIR=/opt/nifi \
    NIFI_HOME=/opt/nifi/nifi-current \
    NIFI_TOOLKIT_HOME=/opt/nifi/nifi-toolkit-current \
    NIFI_PID_DIR=/opt/nifi/nifi-current/run \
    NIFI_LOG_DIR=/opt/nifi/nifi-current/logs \
    JAVA_HOME=/opt/java/openjdk \
    PATH=/opt/java/openjdk/bin:$PATH
COPY --from=base /opt/nifi /opt/nifi
RUN chown -R nifi:nifi /opt/nifi
COPY --chown=nifi:nifi conf/nifi.properties ${NIFI_HOME}/conf/nifi.properties
WORKDIR ${NIFI_HOME}
USER nifi
ENTRYPOINT ["../scripts/start.sh"]