#!/bin/bash

# 使用国内镜像源构建Docker镜像
# 使用方法: ./build-with-mirrors.sh

set -e

# 镜像名称
IMAGE_NAME="influxdb-grafana-upgraded"

echo "🔧 使用国内镜像源构建Docker镜像..."

# 临时创建使用国内镜像源的Dockerfile
cat > Dockerfile.mirrors << 'EOF'
FROM debian:bullseye-slim
LABEL maintainer="The Blue Finance <thebluefinance@gmail.com>"

# Proxy configuration
ARG HTTP_PROXY
ARG HTTPS_PROXY
ARG NO_PROXY
ENV HTTP_PROXY=$HTTP_PROXY
ENV HTTPS_PROXY=$HTTPS_PROXY
ENV NO_PROXY=$NO_PROXY

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8

# Default versions
ENV INFLUXDB_VERSION=1.8.10
ENV CHRONOGRAF_VERSION=1.8.10
ENV GRAFANA_VERSION=12.0.2

# Grafana database type
ENV GF_DATABASE_TYPE=sqlite3

# Fix bad proxy issue
COPY system/99fixbadproxy /etc/apt/apt.conf.d/99fixbadproxy

WORKDIR /root

# 使用国内镜像源
RUN echo "deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bullseye main" > /etc/apt/sources.list && \
    echo "deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bullseye-updates main" >> /etc/apt/sources.list && \
    echo "deb https://mirrors.tuna.tsinghua.edu.cn/debian-security bullseye-security main" >> /etc/apt/sources.list

# Clear previous sources
RUN ARCH= && dpkgArch="$(dpkg --print-architecture)" && \
    case "${dpkgArch##*-}" in \
      amd64) ARCH='amd64';; \
      arm64) ARCH='arm64';; \
      armhf) ARCH='armhf';; \
      armel) ARCH='armel';; \
      *)     echo "Unsupported architecture: ${dpkgArch}"; exit 1;; \
    esac && \
    rm /var/lib/apt/lists/* -vf \
    # Configure proxy for apt if needed
    && if [ ! -z "$HTTP_PROXY" ]; then \
        echo "Acquire::http::Proxy \"$HTTP_PROXY\";" >> /etc/apt/apt.conf.d/01proxy; \
        echo "Acquire::https::Proxy \"$HTTPS_PROXY\";" >> /etc/apt/apt.conf.d/01proxy; \
        echo "Acquire::Retries 3;" >> /etc/apt/apt.conf.d/01proxy; \
        echo "Acquire::http::Timeout 30;" >> /etc/apt/apt.conf.d/01proxy; \
        echo "Acquire::https::Timeout 30;" >> /etc/apt/apt.conf.d/01proxy; \
    fi \
    # Base dependencies
    && apt-get -y update \
    && apt-get -y dist-upgrade \
    && apt-get -y --allow-downgrades --allow-remove-essential --allow-change-held-packages install \
        apt-utils \
        ca-certificates \
        curl \
        git \
        htop \
        libfontconfig1 \
        nano \
        net-tools \
        supervisor \
        wget \
        gnupg \
        musl \
    && mkdir -p /var/log/supervisor \
    && rm -rf .profile \
    # Install InfluxDB from 清华源
    && wget --no-verbose https://mirrors.tuna.tsinghua.edu.cn/influxdata/influxdb/releases/influxdb_${INFLUXDB_VERSION}_${ARCH}.deb || \
       wget --no-verbose https://dl.influxdata.com/influxdb/releases/influxdb_${INFLUXDB_VERSION}_${ARCH}.deb \
    && dpkg -i influxdb_${INFLUXDB_VERSION}_${ARCH}.deb \
    && rm influxdb_${INFLUXDB_VERSION}_${ARCH}.deb \
    # Install Chronograf
    && wget --no-verbose https://mirrors.tuna.tsinghua.edu.cn/influxdata/chronograf/releases/chronograf_${CHRONOGRAF_VERSION}_${ARCH}.deb || \
       wget --no-verbose https://dl.influxdata.com/chronograf/releases/chronograf_${CHRONOGRAF_VERSION}_${ARCH}.deb \
    && dpkg -i chronograf_${CHRONOGRAF_VERSION}_${ARCH}.deb && rm chronograf_${CHRONOGRAF_VERSION}_${ARCH}.deb \
    # Install Grafana
    && wget --no-verbose https://mirrors.tuna.tsinghua.edu.cn/grafana/apt/pool/main/g/grafana/grafana_${GRAFANA_VERSION}_${ARCH}.deb || \
       wget --no-verbose https://dl.grafana.com/oss/release/grafana_${GRAFANA_VERSION}_${ARCH}.deb \
    && dpkg -i grafana_${GRAFANA_VERSION}_${ARCH}.deb \
    && rm grafana_${GRAFANA_VERSION}_${ARCH}.deb \
    # Cleanup
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Configure Supervisord and base env
COPY supervisord/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY bash/profile .profile

# Configure InfluxDB
COPY influxdb/influxdb.conf /etc/influxdb/influxdb.conf

# Configure Grafana
COPY grafana/grafana.ini /etc/grafana/grafana.ini

COPY run.sh /run.sh
RUN ["chmod", "+x", "/run.sh"]
CMD ["/run.sh"]
EOF

# 构建镜像
docker build -f Dockerfile.mirrors -t "$IMAGE_NAME" .

echo "✅ 构建完成！"
echo "📦 镜像名称: $IMAGE_NAME"

# 清理临时文件
rm Dockerfile.mirrors

# 显示镜像信息
echo "📋 镜像信息:"
docker images | grep "$IMAGE_NAME"

echo ""
echo "🚀 运行容器:"
echo "docker run -d \\"
echo "  --name docker-influxdb-grafana-upgraded \\"
echo "  -p 3003:3003 \\"
echo "  -p 3004:8083 \\"
echo "  -p 8086:8086 \\"
echo "  -v /path/for/influxdb:/var/lib/influxdb \\"
echo "  -v /path/for/grafana:/var/lib/grafana \\"
echo "  $IMAGE_NAME"