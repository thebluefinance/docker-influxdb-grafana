# Docker InfluxDB Grafana 升级指南

## 版本升级

本次升级将以下组件更新到最新版本：

| 组件 | 原版本 | 新版本 |
|------|--------|--------|
| InfluxDB | 1.8.2 | 1.8.10 |
| Grafana | 7.2.0 | 12.0.2 |
| Chronograf | 1.8.6 | 1.8.10 |

## 构建说明

### 重要提醒
构建过程中需要下载软件包，请确保代理服务正常运行。

### 启动代理服务

在构建前，请先启动代理服务：

```bash
# 启动代理服务
proxy
```

或者确保代理服务在 `127.0.0.1:4780` 端口运行。

### 构建选项

#### 选项1：使用代理构建（推荐）

```bash
# 方式1：使用构建脚本
./build-with-proxy.sh

# 方式2：手动构建
docker build \
  --build-arg HTTP_PROXY=http://127.0.0.1:4780 \
  --build-arg HTTPS_PROXY=http://127.0.0.1:4780 \
  --build-arg NO_PROXY=localhost,127.0.0.1 \
  -t influxdb-grafana-upgraded .
```

#### 选项2：使用SOCKS5代理

```bash
docker build \
  --build-arg HTTP_PROXY=socks5://127.0.0.1:4780 \
  --build-arg HTTPS_PROXY=socks5://127.0.0.1:4780 \
  -t influxdb-grafana-upgraded .
```

#### 选项3：无代理构建

```bash
# 网络正常时使用
./build-without-proxy.sh
```

### 构建故障排除

如果构建失败，请检查：

1. **代理服务状态**
   ```bash
   # 检查代理端口是否开启
   netstat -an | grep 4780
   ```

2. **网络连接**
   ```bash
   # 测试网络连接
   curl -I http://www.google.com
   ```

3. **Docker代理设置**
   ```bash
   # 检查Docker代理设置
   docker system info | grep -i proxy
   ```

## 运行升级后的容器

构建成功后，使用以下命令运行容器：

```bash
# 基本运行
docker run -d \
  --name docker-influxdb-grafana-upgraded \
  -p 3003:3003 \
  -p 3004:8083 \
  -p 8086:8086 \
  influxdb-grafana-upgraded

# 带数据持久化
docker run -d \
  --name docker-influxdb-grafana-upgraded \
  -p 3003:3003 \
  -p 3004:8083 \
  -p 8086:8086 \
  -v /path/for/influxdb:/var/lib/influxdb \
  -v /path/for/grafana:/var/lib/grafana \
  influxdb-grafana-upgraded
```

## 访问服务

- **Grafana**: http://localhost:3003 (root/root)
- **Chronograf**: http://localhost:3004 (root/root)
- **InfluxDB**: localhost:8086

## 重要注意事项

1. **代理依赖**: 构建过程必须使用代理才能成功下载软件包
2. **数据迁移**: 升级前请备份现有数据
3. **配置兼容性**: Grafana 12.0.2 相对于 7.2.0 有重大更新，建议重新配置
4. **性能考虑**: 新版本可能需要更多资源，请适当调整容器配置

## 升级验证

构建完成后，请验证以下功能：

1. **容器启动**
   ```bash
   docker logs docker-influxdb-grafana-upgraded
   ```

2. **服务可用性**
   ```bash
   # 检查Grafana
   curl http://localhost:3003
   
   # 检查InfluxDB
   curl http://localhost:8086/ping
   ```

3. **数据连通性**
   - 在Grafana中添加InfluxDB数据源
   - 创建测试仪表板
   - 验证数据查询功能

## 如果遇到问题

1. 确保代理服务正在运行
2. 检查端口占用情况
3. 查看Docker构建日志
4. 如有需要，可恢复到原版本配置