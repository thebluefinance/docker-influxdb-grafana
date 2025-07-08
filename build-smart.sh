#!/bin/bash

# 智能构建脚本 - 自动检测网络状况并选择最佳构建方式
# 使用方法: ./build-smart.sh

set -e

# 镜像名称
IMAGE_NAME="influxdb-grafana-upgraded"

echo "🔧 智能构建Docker镜像..."

# 检查网络连接
echo "🔍 检查网络连接..."

# 检查Docker Hub连接
if curl -s --connect-timeout 5 https://registry-1.docker.io/ > /dev/null 2>&1; then
    echo "✅ Docker Hub 连接正常"
    NETWORK_OK=true
else
    echo "❌ Docker Hub 连接失败"
    NETWORK_OK=false
fi

# 检查代理可用性
PROXY_OK=false
if [[ "$OSTYPE" == "darwin"* ]] || [[ "$OSTYPE" == "msys" ]]; then
    PROXY_URL="http://host.docker.internal:4780"
else
    PROXY_URL="http://127.0.0.1:4780"
fi

if curl -s --proxy "$PROXY_URL" --connect-timeout 5 http://httpbin.org/ip > /dev/null 2>&1; then
    echo "✅ 代理服务器 $PROXY_URL 可用"
    PROXY_OK=true
else
    echo "❌ 代理服务器 $PROXY_URL 不可用"
fi

# 决定构建策略
if [ "$NETWORK_OK" = true ]; then
    echo "🚀 使用直连方式构建..."
    docker build -t "$IMAGE_NAME" .
elif [ "$PROXY_OK" = true ]; then
    echo "🚀 使用代理方式构建..."
    export HTTP_PROXY="$PROXY_URL"
    export HTTPS_PROXY="$PROXY_URL"
    export NO_PROXY="localhost,127.0.0.1"
    
    docker build \
      --build-arg HTTP_PROXY="$PROXY_URL" \
      --build-arg HTTPS_PROXY="$PROXY_URL" \
      --build-arg NO_PROXY="localhost,127.0.0.1" \
      -t "$IMAGE_NAME" \
      .
else
    echo "❌ 无法连接到Docker Hub，且代理也不可用"
    echo ""
    echo "可能的解决方案："
    echo "1. 检查网络连接"
    echo "2. 启动代理服务器在端口 4780"
    echo "3. 配置Docker Desktop的代理设置"
    echo "4. 使用国内镜像源"
    echo ""
    echo "如需配置国内镜像源，请运行: ./build-with-mirrors.sh"
    exit 1
fi

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