FROM bellsoft/liberica-openjdk-debian:11 as installer

ARG COMPONENTS=1c-enterprise-ring,1c-cs-hazelcast

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

COPY --from=installer /opt/1C/ /opt/1C/ 
COPY --from=installer /etc/1C/ /etc/1C/

RUN set -x && \
    RING_PATH=$(find /opt/1C/1CE/components -name "1c-enterprise-ring-*" -type d) && \
    HC_PATH=$(find /opt/1C/1CE/components -name "1c-cs-hazelcast-*" -type d) && \
    JAVA_HOME=$(find /usr/lib/jvm -name "jdk-*-bellsoft-*" -type d) && \
    chmod +x $RING_PATH/ring && \
    \
    echo "#!/bin/bash\n" > /usr/local/bin/ring && \
    echo $RING_PATH/ring \"\$@\" >> /usr/local/bin/ring && \
    \
    echo "#!/bin/bash\n" > /usr/local/bin/hc_launcher && \
    echo $HC_PATH/bin/launcher \"\$@\" >> /usr/local/bin/hc_launcher && \
    \
    chmod +x /usr/local/bin/ring && \
    chmod +x /usr/local/bin/hc_launcher && \
    \
    ln -s $JAVA_HOME /usr/lib/jvm/current &&\
    \
    useradd -m cs_user &&\
    mkdir -p /var/cs/hc_instance &&\
    ring hazelcast instance create --dir /var/cs/hc_instance --owner cs_user &&\
    \
    mkdir -p /var/cs/hc_instance/data &&\
    mkdir -p /var/cs/hc_instance/logs &&\
    chown -R cs_user:cs_user /var/cs/hc_instance
    
WORKDIR /var/cs/hc_instance

VOLUME /var/cs/hc_instance/logs
VOLUME /var/cs/hc_instance/data

USER cs_user

# <management-center enabled="true">http://localhost:8080/mancenter</management-center>
EXPOSE 8080
EXPOSE 5701

CMD sh -exc "rm -vf daemon.pid && exec /usr/local/bin/hc_launcher start --instance /var/cs/hc_instance --javahome /usr/lib/jvm/current"