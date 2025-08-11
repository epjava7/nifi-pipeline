# build
FROM eclipse-temurin:17-jdk-jammy AS builder
RUN apt-get update && apt-get install -y curl unzip 
RUN curl -L -o /tmp/nifi.zip https://archive.apache.org/dist/nifi/1.26.0/nifi-1.26.0-bin.zip && \
    unzip -q /tmp/nifi.zip -d /opt && mv /opt/nifi-1.26.0 /opt/nifi-build

# run
FROM eclipse-temurin:17-jdk-jammy
RUN apt-get update && apt-get install -y tini && rm -rf /var/lib/apt/lists/*
ENV NIFI_HOME=/opt/nifi JAVA_HOME=/opt/java/openjdk
COPY --from=builder /opt/nifi-build ${NIFI_HOME}
COPY conf/nifi.properties ${NIFI_HOME}/conf/nifi.properties
WORKDIR ${NIFI_HOME}

# Run NiFi in the foreground; tini is PID 1
ENTRYPOINT ["/usr/bin/tini","-g","--"]
CMD ["bash","-lc","bin/nifi.sh run"]

# FROM apache/nifi:1.26.0  
# COPY conf/nifi.properties /opt/nifi/nifi-current/conf/nifi.properties