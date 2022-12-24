# to be built as cynic0/reddit-flutter:latest
FROM cynic0/flutter-image:latest

WORKDIR /usr/src/app

COPY . .

RUN /flutter/bin/flutter create .

EXPOSE 443

CMD ["/flutter/bin/flutter", "run", "-d", "web-server", "--web-hostname", "0.0.0.0", "--web-port", "443"]
