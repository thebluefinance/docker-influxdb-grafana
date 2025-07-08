#!/bin/bash

# 无代理构建脚本（网络正常时使用）
# 使用方法: ./build-without-proxy.sh

set -e

# 镜像名称
IMAGE_NAME="influxdb-grafana-upgraded"

echo "🔧 构建Docker镜像（无代理）..."

# 构建镜像
docker build -t "$IMAGE_NAME" .

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