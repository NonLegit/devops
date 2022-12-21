FROM jenkins/jenkins

ARG DOCKER_GROUP_ID

USER root

RUN curl -fsSL https://deb.nodesource.com/setup_19.x | bash

RUN apt-get update && apt-get install ca-certificates curl gnupg lsb-release nodejs -y

RUN mkdir -p /etc/apt/keyrings && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  bionic stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

RUN apt-get update && apt-get install docker-ce-cli docker-compose-plugin -y

RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && unzip awscliv2.zip && ./aws/install && rm -rf ./aws*

RUN groupadd -g $DOCKER_GROUP_ID docker && gpasswd -a jenkins docker

USER jenkins

ENV JENKINS_OPTS --prefix=/jenkins
