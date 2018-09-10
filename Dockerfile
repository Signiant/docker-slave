# The MIT License
#
#  Copyright (c) 2015-2017, CloudBees, Inc. and other Jenkins contributors
#
#  Permission is hereby granted, free of charge, to any person obtaining a copy
#  of this software and associated documentation files (the "Software"), to deal
#  in the Software without restriction, including without limitation the rights
#  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#  copies of the Software, and to permit persons to whom the Software is
#  furnished to do so, subject to the following conditions:
#
#  The above copyright notice and this permission notice shall be included in
#  all copies or substantial portions of the Software.
#
#  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
#  THE SOFTWARE.

FROM openjdk:8-jdk
MAINTAINER Signiant DevOps <devops@signiant.com>

ARG user=bldmgr
ARG group=users
ARG uid=10012
ARG gid=100

ENV BUILD_DOCKER_GROUP docker
ENV BUILD_DOCKER_GROUP_ID 1001

USER root
# Install a base set of packages from the default repo
# && Install pip
COPY apt-get-packages.list /tmp/apt-get-packages.list
RUN apt-get update \
    && chmod +r /tmp/apt-get-packages.list \
    && apt-get install -y `cat /tmp/apt-get-packages.list` \
    && easy_install pip==7.1.2

#Setup Docker CE
RUN curl -fsSL https://download.docker.com/linux/$(. /etc/os-release; echo "$ID")/gpg | sudo apt-key add -
RUN add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/$(. /etc/os-release; echo "$ID") \
   $(lsb_release -cs) \
   stable"
RUN apt-get update && apt-get install docker-ce

# Setup build environment / tools
ENV NPM_VERSION latest-2
ENV FINDBUGS_VERSION 2.0.3
ENV ANT_VERSION 1.9.6
ENV ANT_HOME /usr/local/apache-ant-${ANT_VERSION}

RUN curl -sL https://deb.nodesource.com/setup_8.x | sudo bash - \
    && apt-get install -y npm

# Update npm
# && Install npm packages needed by builds
#  -- We have to use the fixed version of grunt-connect-proxy otherwise we get fatal socket hang up errors
# && Install findbugs
# && Install ant
# && Install link to ant
RUN npm version && npm install -g npm@${NPM_VERSION} && npm version \
  && npm install -g bower grunt@0.4 grunt-cli grunt-connect-proxy@0.1.10 n \
  && curl -fSLO http://downloads.sourceforge.net/project/findbugs/findbugs/$FINDBUGS_VERSION/findbugs-$FINDBUGS_VERSION.tar.gz && \
    tar xzf findbugs-$FINDBUGS_VERSION.tar.gz -C /home/$BUILD_USER  && \
    rm findbugs-$FINDBUGS_VERSION.tar.gz \
  && wget --no-verbose http://archive.apache.org/dist/ant/binaries/apache-ant-${ANT_VERSION}-bin.tar.gz && \
    tar -xzf apache-ant-${ANT_VERSION}-bin.tar.gz && \
    mv apache-ant-${ANT_VERSION} /usr/local/apache-ant-${ANT_VERSION} && \
    rm apache-ant-${ANT_VERSION}-bin.tar.gz \
  && update-alternatives --install /usr/bin/ant ant ${ANT_HOME}/bin/ant 20000

# Install our required ant libs
COPY ant-libs/*.jar ${ANT_HOME}/lib/
RUN chmod 644 ${ANT_HOME}/lib/*.jar \
  && sh -c 'echo ANT_HOME=/usr/local/apache-ant-${ANT_VERSION} >> /etc/environment'

# Install the Whitesource scanner
RUN wget --no-verbose https://s3.amazonaws.com/file-system-agent/whitesource-fs-agent-18.1.1.jar -O /whitesource-fs-agent.jar

# Add in our common jenkins node tools for bldmgr
COPY jenkins_nodes /home/${user}/jenkins_nodes

ENV HOME /home/${user}
RUN useradd -c "Jenkins user" -d $HOME -u ${uid} -g ${gid} -m ${user}
RUN usermod -a -G ${BUILD_DOCKER_GROUP} ${user}
LABEL Description="This is a base image, which provides the Jenkins agent executable (slave.jar)" Vendor="Jenkins project" Version="3.20"
ARG VERSION=3.20

RUN curl --create-dirs -sSLo /usr/share/jenkins/slave.jar https://repo.jenkins-ci.org/public/org/jenkins-ci/main/remoting/${VERSION}/remoting-${VERSION}.jar \
  && chmod 755 /usr/share/jenkins \
  && chmod 644 /usr/share/jenkins/slave.jar

# Create the folder we use for Jenkins workspaces across all nodes
RUN mkdir -p /var/lib/jenkins \
  && chown -R ${user}:${group} /var/lib/jenkins

COPY jenkins-slave /usr/local/bin/jenkins-slave
RUN chmod +x /usr/local/bin/jenkins-slave
RUN mkdir /home/${user}/.jenkins && chown -R ${user}:${group} /home/${user}/.jenkins \
  && mkdir /home/${user}/workspace && chown -R ${user}:${group} /home/${user}/workspace

#USER ${user}
#VOLUME /home/${user}/.jenkins
WORKDIR /home/${user}

ENTRYPOINT ["/usr/local/bin/jenkins-slave"]
