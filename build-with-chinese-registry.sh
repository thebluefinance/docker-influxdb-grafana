#!/bin/bash

# 使用国内Docker镜像仓库构建
# 使用方法: ./build-with-chinese-registry.sh

set -e

# 镜像名称
IMAGE_NAME="influxdb-grafana-upgraded"

echo "🔧 使用国内Docker镜像仓库构建..."

# 配置Docker镜像加速器
echo "🔧 配置Docker镜像加速器..."

# 检查并创建daemon.json
DOCKER_CONFIG_DIR="$HOME/.docker"
DAEMON_JSON="$DOCKER_CONFIG_DIR/daemon.json"

if [ ! -d "$DOCKER_CONFIG_DIR" ]; then
    mkdir -p "$DOCKER_CONFIG_DIR"
fi

# 创建或更新daemon.json
cat > "$DAEMON_JSON" << 'EOF'
{
  "registry-mirrors": [
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com",
    "https://registry.docker-cn.com",
    "https://mirror.baidubce.com"
  ],
  "insecure-registries": [],
  "debug": false,
  "experimental": false
}
EOF

echo "✅ 已配置Docker镜像加速器"
echo "📍 配置文件位置: $DAEMON_JSON"
echo ""
echo "⚠️  请按以下步骤操作："
echo "1. 打开 Docker Desktop"
echo "2. 点击设置图标 (齿轮) > Docker Engine"
echo "3. 将以下内容复制到配置中："
echo ""
cat "$DAEMON_JSON"
echo ""
echo "4. 点击 'Apply & Restart' 重启Docker"
echo "5. 重启完成后，再次运行此脚本"
echo ""

# 检查Docker是否重启
echo "🔍 检查Docker镜像加速器是否生效..."
if docker info 2>/dev/null | grep -q "Registry Mirrors" > /dev/null 2>&1; then
    echo "✅ Docker镜像加速器已生效"
    
    # 尝试拉取基础镜像
    echo "🔄 拉取基础镜像..."
    if docker pull debian:bullseye-slim; then
        echo "✅ 基础镜像拉取成功"
        
        # 创建使用国内镜像源的Dockerfile
        cat > Dockerfile.china << 'EOF'
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

# Clear previous sources and install packages
RUN ARCH= && dpkgArch="$(dpkg --print-architecture)" && \
    case "${dpkgArch##*-}" in \
      amd64) ARCH='amd64';; \
      arm64) ARCH='arm64';; \
      armhf) ARCH='armhf';; \
      armel) ARCH='armel';; \
      *)     echo "Unsupported architecture: ${dpkgArch}"; exit 1;; \
    esac && \
    rm /var/lib/apt/lists/* -vf && \
    apt-get -y update && \
    apt-get -y dist-upgrade && \
    apt-get -y --allow-downgrades --allow-remove-essential --allow-change-held-packages install \
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
        musl && \
    mkdir -p /var/log/supervisor && \
    rm -rf .profile && \
    wget --no-verbose https://dl.influxdata.com/influxdb/releases/influxdb_${INFLUXDB_VERSION}_${ARCH}.deb && \
    dpkg -i influxdb_${INFLUXDB_VERSION}_${ARCH}.deb && \
    rm influxdb_${INFLUXDB_VERSION}_${ARCH}.deb && \
    wget --no-verbose https://dl.influxdata.com/chronograf/releases/chronograf_${CHRONOGRAF_VERSION}_${ARCH}.deb && \
    dpkg -i chronograf_${CHRONOGRAF_VERSION}_${ARCH}.deb && rm chronograf_${CHRONOGRAF_VERSION}_${ARCH}.deb && \
    wget --no-verbose https://dl.grafana.com/oss/release/grafana_${GRAFANA_VERSION}_${ARCH}.deb && \
    dpkg -i grafana_${GRAFANA_VERSION}_${ARCH}.deb && \
    rm grafana_${GRAFANA_VERSION}_${ARCH}.deb && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

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
        echo "🔨 开始构建镜像..."
        docker build -f Dockerfile.china -t "$IMAGE_NAME" .
        
        echo "✅ 构建完成！"
        echo "📦 镜像名称: $IMAGE_NAME"
        
        # 清理临时文件
        rm Dockerfile.china
        
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
        
    else
        echo "❌ 基础镜像拉取失败"
        echo "请检查网络连接或Docker配置"
    fi
else
    echo "❌ Docker镜像加速器未生效"
    echo "请按上述步骤配置Docker Desktop并重启"
fi