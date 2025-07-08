#!/bin/bash

# 构建带代理的Docker镜像脚本
# 使用方法: ./build-with-proxy.sh

set -e

# 代理配置
HTTP_PROXY="http://127.0.0.1:4780"
HTTPS_PROXY="http://127.0.0.1:4780"
NO_PROXY="localhost,127.0.0.1"

# 镜像名称
IMAGE_NAME="influxdb-grafana-upgraded"

echo "🔧 构建带代理的Docker镜像..."
echo "HTTP_PROXY: $HTTP_PROXY"
echo "HTTPS_PROXY: $HTTPS_PROXY"

# 构建镜像
docker build \
  --build-arg HTTP_PROXY="$HTTP_PROXY" \
  --build-arg HTTPS_PROXY="$HTTPS_PROXY" \
  --build-arg NO_PROXY="$NO_PROXY" \
  -t "$IMAGE_NAME" \
  .

echo "✅ 构建完成！"
echo "📦 镜像名称: $IMAGE_NAME"

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