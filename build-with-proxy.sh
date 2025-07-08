#!/bin/bash

# 构建带代理的Docker镜像脚本
# 使用方法: ./build-with-proxy.sh

set -e

# 代理配置 - 容器内需要使用host.docker.internal访问宿主机代理
if [[ "$OSTYPE" == "darwin"* ]] || [[ "$OSTYPE" == "msys" ]]; then
    # macOS/Windows: Docker容器内访问宿主机代理
    HTTP_PROXY="http://host.docker.internal:4780"
    HTTPS_PROXY="http://host.docker.internal:4780"
    NO_PROXY="localhost,127.0.0.1,host.docker.internal"
    
else
    # Linux: 使用宿主机网络
    HTTP_PROXY="http://host.docker.internal:4780"
    HTTPS_PROXY="http://host.docker.internal:4780"
    NO_PROXY="localhost,127.0.0.1"
fi


# 镜像名称
IMAGE_NAME="influxdb-grafana-upgraded"

echo "🔧 构建带代理的Docker镜像..."
echo "HTTP_PROXY: $HTTP_PROXY"
echo "HTTPS_PROXY: $HTTPS_PROXY"

# 检查代理是否可用
echo "🔍 检查代理连接..."
if ! curl -s --proxy "http://127.0.0.1:4780" --connect-timeout 5 http://httpbin.org/ip > /dev/null 2>&1; then
    echo "❌ 警告: 代理服务器 http://127.0.0.1:4780 不可用"
    echo "请确保代理服务器正在运行，或使用 build-without-proxy.sh 脚本"
    exit 1
fi
echo "✅ 代理连接正常"

# 设置Docker客户端代理环境变量
# export HTTP_PROXY="http://127.0.0.1:4780"
# export HTTPS_PROXY="http://127.0.0.1:4780"
# export NO_PROXY="localhost,127.0.0.1"

# 构建镜像 - 传递容器内部使用的代理地址
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