#!/bin/bash
# 正常机器终极一键部署脚本（2025 版）
# 包含：Docker + SS + Shadow-TLS v3 + BBR + 自动生成带正确IP的分享链接 + 改密码教程

set -e

echo "开始部署 Shadowsocks + Shadow-TLS v3 + BBR..."

# 1. 安装最新 Docker
curl -fsSL https://get.docker.com | sh
sudo systemctl start docker
sudo systemctl enable docker >/dev/null 2>&1

# 2. 获取公网 IP（优先 ipv4，兼容性最好）
IP=$(curl -s https://ifconfig.me || curl -s https://api.ipify.org || echo "127.0.0.1")
PASSWORD="lY1yVTiespe43EVb"   # 你原来的密码，建议后面自己改

# 3. 写入 docker-compose.yml（密码走环境变量）
cat > docker-compose.yml << EOF
services:
  ss:
    image: shadowsocks/shadowsocks-libev:latest
    restart: always
    network_mode: host
    environment:
      - PASSWORD=\${PASSWORD:-$PASSWORD}
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
      - PASSWORD=\${PASSWORD:-$PASSWORD}
EOF

# 4. 写入 .env（方便后面改密码）
echo "PASSWORD=$PASSWORD" > .env

# 5. 开启 BBR + 常用优化（一次性 + 开机自启）
sudo bash -c 'cat > /etc/sysctl.d/99-bbr.conf << "EOF"
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.ipv4.tcp_slow_start_after_idle=0
net.ipv4.tcp_notsent_lowat=16384
vm.swappiness=10
EOF'
sudo sysctl -p /etc/sysctl.d/99-bbr.conf >/dev/null

# 6. 启动服务
docker compose up -d || docker-compose up -d

# 7. 生成两个带正确 IP 的分享链接
SS_BASE64=$(echo -n "aes-256-gcm:$PASSWORD@$IP:24000" | base64 -w0)
SHADOWTLS_JSON=$(echo -n "{\"version\":2,\"host\":\"www.microsoft.com\",\"port\":\"443\",\"password\":\"$PASSWORD\",\"address\":\"$IP\"}" | base64 -w0)

SS_LINK="ss://$SS_BASE64#SS-Plain"
SHADOWTLS_LINK="ss://$SS_BASE64?shadow-tls=$SHADOWTLS_JSON#Shadow-TLS-v3"

# 8. 完工输出
sleep 5
clear
echo "部署完成！BBR 已开启！"
echo "============================================"
echo "服务器 IP   : $IP"
echo "端口        : 443"
echo "密码        : $PASSWORD"
echo "加密        : aes-256-gcm"
echo "TLS 伪装    : www.microsoft.com"
echo "============================================"
echo "普通 SS 链接（备用）："
echo "$SS_LINK"
echo ""
echo "Shadow-TLS v3 完整链接（推荐）："
echo "$SHADOWTLS_LINK"
echo ""
echo "客户端推荐："
echo "   Windows → Nekoray / HiddifyNext"
echo "   macOS   → Shadowrocket / Stash"
echo "   Android → Surfboard / Matsuri"
echo "   iOS     → Shadowrocket / Stash"
echo ""
echo "改密码方法（随时改随时生效）："
echo "   vim .env"
echo "   修改 PASSWORD= 新密码"
echo "   然后执行：docker compose up -d   （或 docker-compose up -d）"
echo ""
docker compose ps
