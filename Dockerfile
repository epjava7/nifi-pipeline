# build
FROM eclipse-temurin:17-jdk-jammy AS builder
RUN apt-get update && apt-get install -y curl unzip 
RUN curl -L -o /tmp/nifi.zip https://archive.apache.org/dist/nifi/1.26.0/nifi-1.26.0-bin.zip && \
    unzip -q /tmp/nifi.zip -d /opt && mv /opt/nifi-1.26.0 /opt/nifi-build

# run
FROM eclipse-temurin:17-jdk-jammy
COPY --from=builder /opt/nifi-build /opt/nifi
COPY conf/nifi.properties /opt/nifi/conf/nifi.properties
WORKDIR /opt/nifi
ENTRYPOINT ["bin/nifi.sh"]
CMD ["run"]
