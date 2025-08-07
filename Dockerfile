# build
FROM openjdk:17-jdk-slim AS builder            
ARG NIFI_VERSION=1.26.0
RUN apt-get update && apt-get install -y --no-install-recommends curl unzip 
RUN curl -L -o /tmp/nifi.zip \
      https://archive.apache.org/dist/nifi/${NIFI_VERSION}/nifi-${NIFI_VERSION}-bin.zip && \
    unzip -q /tmp/nifi.zip -d /opt && mv /opt/nifi-${NIFI_VERSION} /opt/nifi-build
COPY conf /opt/nifi-build/conf 

# run
FROM openjdk:17-slim                    
ENV NIFI_HOME=/opt/nifi \
    PATH=/opt/nifi/bin:${PATH}
COPY --from=builder /opt/nifi-build ${NIFI_HOME}
RUN adduser --system --group nifi && \
    chown -R nifi:nifi ${NIFI_HOME}
USER nifi
WORKDIR ${NIFI_HOME}
EXPOSE 8080
ENTRYPOINT ["bin/nifi.sh","run"]
