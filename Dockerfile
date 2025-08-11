# build
FROM eclipse-temurin:17-jdk-jammy AS builder
RUN apt-get update && apt-get install -y curl unzip 
RUN curl -L -o /tmp/nifi.zip https://archive.apache.org/dist/nifi/1.26.0/nifi-1.26.0-bin.zip && \
    unzip -q /tmp/nifi.zip -d /opt && mv /opt/nifi-1.26.0 /opt/nifi-build

# run
FROM eclipse-temurin:17-jdk-jammy
ENV NIFI_HOME=/opt/nifi
COPY --from=builder /opt/nifi-build ${NIFI_HOME}
WORKDIR ${NIFI_HOME}
RUN set -eux; \
  printf '#!/usr/bin/env bash\nset -euo pipefail\n' \
         'mkdir -p "$NIFI_HOME/logs"\n' \
         ': > "$NIFI_HOME/logs/nifi-app.log"\n' \
         ': > "$NIFI_HOME/logs/nifi-bootstrap.log"\n' \
         '"$NIFI_HOME/bin/nifi.sh" run &\n' \
         'sleep 2\n' \
         'exec tail -F "$NIFI_HOME/logs/nifi-app.log" "$NIFI_HOME/logs/nifi-bootstrap.log"\n' \
         > /usr/local/bin/start-nifi && chmod +x /usr/local/bin/start-nifi

EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/start-nifi"]

# FROM apache/nifi:1.26.0  
# COPY conf/nifi.properties /opt/nifi/nifi-current/conf/nifi.properties