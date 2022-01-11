FROM golang:1.16-alpine AS backend
WORKDIR /go/src/cloudshell
COPY ./cmd ./cmd
COPY ./internal ./internal
COPY ./pkg ./pkg
COPY ./go.mod .
COPY ./go.sum .
ENV CGO_ENABLED=0
RUN go mod vendor
ARG VERSION_INFO=dev-build
RUN go build -a -v \
  -ldflags " \
  -s -w \
  -extldflags 'static' \
  -X main.VersionInfo='${VERSION_INFO}' \
  " \
  -o ./bin/cloudshell \
  ./cmd/cloudshell

FROM node:16.0.0-alpine AS frontend
WORKDIR /app
COPY ./package.json .
COPY ./package-lock.json .
RUN npm install

FROM centos:7

RUN rpm -Uvh https://github.com/griddb/griddb/releases/download/v4.6.1/griddb-4.6.1-linux.x86_64.rpm
RUN rpm -Uvh https://github.com/griddb/cli/releases/download/v4.6.0/griddb-ce-cli-4.6.0-linux.x86_64.rpm
RUN yum -y install iproute
RUN yum install -y \
       java-1.8.0-openjdk \
       java-1.8.0-openjdk-devel
ADD https://repo1.maven.org/maven2/com/github/griddb/gridstore-jdbc/4.5.0/gridstore-jdbc-4.5.0.jar /usr/share/java

ENV GS_HOME /var/lib/gridstore
ENV GS_LOG $GS_HOME/log
ENV HOME $GS_HOME
WORKDIR $HOME
ADD start_griddb.sh /

WORKDIR /app
COPY --from=backend /go/src/cloudshell/bin/cloudshell /app/cloudshell
COPY --from=frontend /app/node_modules /app/node_modules
COPY ./public /app/public
RUN ln -s /app/cloudshell /usr/bin/cloudshell
RUN useradd -ms /bin/bash user
RUN mkdir -p /home/user
RUN chown user:user /app -R
WORKDIR /
ENV WORKDIR=/app

USER gsadm
WORKDIR $HOME

CMD /start_griddb.sh
EXPOSE 10001 10010 10020 10030 10040 10050 10080 20001 2375 80 443 8376

USER user
WORKDIR /app
ENTRYPOINT ["/app/cloudshell"]
CMD ["--allowed-hostnames", "52.250.124.168", "--command", "/usr/bin/gs_sh"]
