#!/bin/bash

# Installing apache and cerbot..
yum update -y
yum install yum-utils httpd -y

rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-9
yum install https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm -y
yum install certbot python3-certbot-apache -y

# Installing docker..
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
rpm --import https://download.docker.com/linux/centos/gpg
yum install docker-ce docker-ce-cli containerd.io docker-compose-plugin -y

systemctl enable --now docker.service
docker pull cynic0/reddit-backend:latest 
docker pull cynic0/reddit-frontend:latest 
cynic0/reddit-flutter:latest

# Configuring apache


# Requesting certificates

# Modifying /etc/hosts

# Starting services

# 

# Pull docker images

# Pull dockerfiles
