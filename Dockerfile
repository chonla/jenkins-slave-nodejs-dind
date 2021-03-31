FROM openjdk:11-jdk

ADD ./data /opt
WORKDIR /opt

ENV GOSU_VERSION=1.12 \
    SWARM_VERSION=3.19 \
    MD5=96c259096839cf95acd3db2f48d556df \
    FINGER_PRINT=0EBFCD88

# grab gosu for easy step-down from root
RUN apt-get -y update \
    && apt-get install -y --no-install-recommends ca-certificates wget bzip2 python \
    && rm -rf /var/lib/apt/lists/* \
    && wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture)" \
    && wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture).asc" \
    && export GNUPGHOME="$(mktemp -d)" \
    && GPG_KEYS=B42F6819007F00F88E364FD4036A9C25BF357DD4 \
    && gpg --keyserver hkp://:p80.pool.sks-keyservers.net:80 --recv-keys "$GPG_KEYS" \
    || gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$GPG_KEYS" \
    || gpg --keyserver pgp.mit.edu --recv-keys "$GPG_KEYS" \
    || gpg --keyserver keyserver.pgp.com --recv-keys "$GPG_KEYS" \
    && gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu \
    && rm -rf "$GNUPGHOME" /usr/local/bin/gosu.asc \
    && chmod +x /usr/local/bin/gosu \
    && gosu nobody true

# grab swarm-client.jar
RUN mkdir -p /var/jenkins_home \
    && useradd -d /var/jenkins_home/slave -u 1000 -m -s /bin/bash jenkins \
    && curl -o /bin/swarm-client.jar -SL https://repo.jenkins-ci.org/releases/org/jenkins-ci/plugins/swarm-client/$SWARM_VERSION/swarm-client-$SWARM_VERSION.jar \
    && echo "$MD5  /bin/swarm-client.jar" | md5sum -c -

# get node
RUN curl -sL https://deb.nodesource.com/setup_14.x | bash - \
    && apt-get install -y nodejs

# get yarn
RUN cd /opt \
    && wget https://yarnpkg.com/latest.tar.gz \
    && tar zvxf latest.tar.gz \
    && export PATH="$PATH:/opt/yarn-v1.22.4/bin"

# get docker ce
RUN apt-get -y update \
    && apt-get -y install apt-transport-https ca-certificates curl gnupg-agent software-properties-common acl \
    && curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add - \
    && apt-key fingerprint $FINGER_PRINT \
    && add-apt-repository \
    "deb [arch=amd64] https://download.docker.com/linux/debian \
    $(lsb_release -cs) \
    stable" \
    && apt-get -y update \
    && apt-get -y install docker-ce docker-ce-cli containerd.io

# get jq
RUN apt-get -y install jq

# post install to docker on linux
RUN usermod -aG docker jenkins

# start on boot
RUN systemctl enable docker

VOLUME /var/jenkins_home/slave
WORKDIR /var/jenkins_home/slave

ENTRYPOINT ["/opt/docker-entrypoint.sh"]
# CMD ["java", "-jar", "/bin/swarm-client.jar"]