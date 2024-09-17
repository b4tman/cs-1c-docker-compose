FROM bellsoft/liberica-openjdk-debian:11 as installer

ARG COMPONENTS=1c-enterprise-ring,1c-cs-elasticsearch

RUN mkdir /tmp/install
WORKDIR /tmp

COPY 1c_cs_*_linux_*.tar.gz /tmp/install/installer.tar.gz
RUN set -x && \
    cd install && \
    tar xf installer.tar.gz && \
    ./1ce-installer-cli install 1c-cs --components $COMPONENTS --ignore-signature-warnings && \
    rm -rf /tmp/install

FROM bellsoft/liberica-openjdk-debian:11

RUN apt-get update && apt-get -y install sudo curl gawk && rm -rf /var/lib/apt/lists/*

RUN mkdir /tmp/install
WORKDIR /tmp

COPY --from=installer /opt/1C/ /opt/1C/ 
COPY --from=installer /etc/1C/ /etc/1C/

RUN set -x && \
    RING_PATH=$(find /opt/1C/1CE/components -name "1c-enterprise-ring-*" -type d) && \
    ELASTIC_PATH=$(find /opt/1C/1CE/components -name "1c-cs-elasticsearch-*" -type d) && \
    JAVA_HOME=$(find /usr/lib/jvm -name "jdk-*-bellsoft-*" -type d) && \
    chmod +x $RING_PATH/ring && \
    \
    echo "#!/bin/bash\n" > /usr/local/bin/ring && \
    echo $RING_PATH/ring \"\$@\" >> /usr/local/bin/ring && \
    \
    echo "#!/bin/bash\n" > /usr/local/bin/elasticsearch_launcher && \
    echo $ELASTIC_PATH/bin/launcher \"\$@\" >> /usr/local/bin/elasticsearch_launcher && \
    \
    chmod +x /usr/local/bin/ring && \
    chmod +x /usr/local/bin/elasticsearch_launcher && \
    \
    ln -s $JAVA_HOME /usr/lib/jvm/current
    

WORKDIR /app

RUN set -x &&\
    useradd -m cs_user &&\
    mkdir -p /var/cs/elastic_instance &&\
    ring elasticsearch instance create --dir /var/cs/elastic_instance --owner cs_user &&\
    chown -R cs_user:cs_user /var/cs/elastic_instance

VOLUME /var/cs/elastic_instance
USER cs_user

EXPOSE 9300

ENTRYPOINT ["/usr/local/bin/elasticsearch_launcher", "start", "--instance", "/var/cs/elastic_instance", "--javahome", "/usr/lib/jvm/current"]
