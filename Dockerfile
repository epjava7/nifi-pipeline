# build
FROM openjdk:17-jdk-slim AS builder
RUN apt-get update && apt-get install -y curl unzip 
RUN curl -L -o /tmp/nifi.zip https://archive.apache.org/dist/nifi/1.26.0/nifi-1.26.0-bin.zip && \
    unzip -q /tmp/nifi.zip -d /opt && mv /opt/nifi-1.26.0 /opt/nifi-build
# COPY conf /opt/nifi-build/conf

# run
FROM openjdk:17-slim                    
COPY --from=builder /opt/nifi-build /opt/nifi
RUN adduser --system --group nifi && chown -R nifi:nifi /opt/nifi
USER nifi
WORKDIR /opt/nifi
ENTRYPOINT ["bin/nifi.sh","run"]
