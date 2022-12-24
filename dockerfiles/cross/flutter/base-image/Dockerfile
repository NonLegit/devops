# to be built as cynic0/flutter-image
FROM ubuntu:latest

RUN apt update -y && apt install wget unzip git xz-utils -y

RUN wget https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.3.10-stable.tar.xz && tar xvf flutter_linux_3.3.10-stable.tar.xz && rm -f *xz && export PATH=$PATH:$PWD/flutter/bin

RUN git config --global --add safe.directory /flutter && /flutter/bin/flutter channel stable && /flutter/bin/flutter upgrade
