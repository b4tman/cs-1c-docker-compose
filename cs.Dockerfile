FROM bellsoft/liberica-openjdk-debian:11 as installer

ARG COMPONENTS=1c-enterprise-ring,1c-cs-server-small

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

WORKDIR /tmp

COPY --from=installer /opt/1C/ /opt/1C/ 
COPY --from=installer /etc/1C/ /etc/1C/

RUN set -x && \
    RING_PATH=$(find /opt/1C/1CE/components -name "1c-enterprise-ring-*" -type d) && \
    CS_PATH=$(find /opt/1C/1CE/components -name "1c-cs-server-small-*" -type d) && \
    JAVA_HOME=$(find /usr/lib/jvm -name "jdk-*-bellsoft-*" -type d) && \
    chmod +x $RING_PATH/ring && \
    \
    echo "#!/bin/bash\n" > /usr/local/bin/ring && \
    echo $RING_PATH/ring \"\$@\" >> /usr/local/bin/ring && \
    \
    echo "#!/bin/bash\n" > /usr/local/bin/cs_launcher && \
    echo $CS_PATH/bin/launcher \"\$@\" >> /usr/local/bin/cs_launcher && \
    \
    chmod +x /usr/local/bin/ring && \
    chmod +x /usr/local/bin/cs_launcher && \
    \
    ln -s $JAVA_HOME /usr/lib/jvm/current
    

WORKDIR /app

RUN set -x &&\
    useradd -m cs_user &&\
    mkdir -p /var/cs/cs_instance &&\
    ring cs instance create --dir /var/cs/cs_instance --owner cs_user &&\
    ring cs --instance cs_instance hazelcast set-params --group-name 1ce-cs --group-password cs-pass --addresses hazelcast &&\
    ring cs --instance cs_instance elasticsearch set-params --addresses elasticsearch:9300 &&\
    ring cs --instance cs_instance jdbc pools --name common set-params --url jdbc:postgresql://db:5432/cs_db?currentSchema=public &&\
    ring cs --instance cs_instance jdbc pools --name common set-params --username postgres &&\
    ring cs --instance cs_instance jdbc pools --name common set-params --password postgres &&\
    ring cs --instance cs_instance jdbc pools --name privileged set-params --url jdbc:postgresql://db:5432/cs_db?currentSchema=public &&\
    ring cs --instance cs_instance jdbc pools --name privileged set-params --username postgres &&\
    ring cs --instance cs_instance jdbc pools --name privileged set-params --password postgres &&\
    ring cs --instance cs_instance websocket set-params --hostname cs &&\
    ring cs --instance cs_instance websocket set-params --port 8087 &&\
    chown -R cs_user:cs_user /var/cs/cs_instance
    
VOLUME /var/cs/cs_instance
USER cs_user

EXPOSE 8087
EXPOSE 8086

CMD ["/usr/local/bin/cs_launcher", "start", "--instance", "/var/cs/cs_instance", "--javahome", "/usr/lib/jvm/current"]