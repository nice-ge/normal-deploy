#!/bin/bash
# 正常机器专用一键部署 Shadowsocks + Shadow-TLS v3（2025 通用版）
# 适用于：甲骨文普通 ARM/x86、Vultr、搬瓦工、腾讯、阿里、所有主流 VPS
# 用法：curl -fsSL https://raw.githubusercontent.com/你的用户名/normal-deploy/main/deploy-normal.sh | bash

set -e

echo "开始一键部署 Shadowsocks + Shadow-TLS v3（正常机器通用版）..."

# 1. 一键安装最新官方 Docker + Compose（自动识别架构、自动换最快源）
curl -fsSL https://get.docker.com | sh

# 2. 开机自启 + 立即启动
sudo systemctl start docker
sudo systemctl enable docker >/dev/null 2>&1

# 3. 创建 docker-compose.yml（密码支持环境变量）
cat > docker-compose.yml << 'EOF'
services:
  ss:
    image: shadowsocks/shadowsocks-libev:latest
    restart: always
    network_mode: host
    environment:
      - PASSWORD=${PASSWORD:-PleaseChangeMe2025}
      - METHOD=aes-256-gcm

  shadowtls:
    image: ghcr.io/ihciah/shadow-tls:latest
    restart: always
    network_mode: host
    environment:
      - MODE=server
      - LISTEN=0.0.0.0:443
      - SERVER=127.0.0.1:24000
      - TLS=www.microsoft.com:443
      - PASSWORD=${PASSWORD:-PleaseChangeMe2025}
EOF

# 4. 创建 .env（方便你改密码）
echo "PASSWORD=PleaseChangeMe2025" > .env
echo "默认密码已设为：PleaseChangeMe2025（建议立即改掉）"

# 5. 启动
docker compose up -d || docker-compose up -d

# 6. 完工提示
sleep 3
echo ""
echo "全部完成！你的节点信息："
echo "   IP     : $(curl -s https://ifconfig.me || curl -s https://api.ipify.org)"
echo "   端口   : 443"
echo "   密码   : $(grep PASSWORD .env | cut -d= -f2)"
echo "   加密   : aes-256-gcm"
echo "   TLS伪装: www.microsoft.com:443"
echo ""
echo "客户端配置好 Shadow-TLS 插件就能连了，爽玩！"
docker compose ps
