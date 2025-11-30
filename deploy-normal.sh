#!/bin/bash
# 正常机器终极一键部署脚本（2025 最终版）
# 功能：Docker + SS + Shadow-TLS v3 + BBR + 自动获取IP + 绝对不重复的高端节点名 + 自动生成分享链接

set -e

echo "开始部署 Shadowsocks + Shadow-TLS v3 + BBR..."

# 1. 安装 Docker + jq（用于解析地理位置）
curl -fsSL https://get.docker.com | sh
sudo apt update >/dev/null 2>&1 && sudo apt install -y jq >/dev/null 2>&1
sudo systemctl start docker
sudo systemctl enable docker >/dev/null 2>&1

# 2. 获取公网IP + 设置密码（可改）
IP=$(curl -s https://ifconfig.me || curl -s https://api.ipify.org || echo "127.0.0.1")
PASSWORD="mT6XP6daHwD4CAhvFJfM"   # ← 改这里或后面用 vim .env 改

# 3. 写入 docker-compose.yml
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

# 4. 创建 .env 文件（改密码专用）
echo "PASSWORD=$PASSWORD" > .env

# 5. 开启 BBR + 优化（永久生效）
sudo bash -c 'cat > /etc/sysctl.d/99-bbr.conf << "EOF"
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.ipv4.tcp_slow_start_after_idle=0
net.ipv4.tcp_notsent_lowat=16384
vm.swappiness=10
EOF'
sudo sysctl -p /etc/sysctl.d/99-bbr.conf >/dev/null

# 6. 启动容器
docker compose up -d || docker-compose up -d
sleep 5

# 7. 生成绝对不重复的高端节点名 + 分享链接
IP_LAST=$(echo $IP | awk -F. '{print $(NF-1)$NF}')                    # IP末尾两段
RAND=$(head /dev/urandom | tr -dc A-HJ-NP-Z2-9 | head -c4)            # 随机4位
COUNTRY_CODE=$(curl -s https://ipinfo.io/json | jq -r '.country // "XX"')

case $COUNTRY_CODE in
  US) FLAG="🇺🇸" ;; JP) FLAG="🇯🇵" ;; SG) FLAG="🇸🇬" ;; DE) FLAG="🇩🇪" ;;
  GB) FLAG="🇬🇧" ;; KR) FLAG="🇰🇷" ;; HK) FLAG="🇭🇰" ;; AU) FLAG="🇦🇺" ;;
  CA) FLAG="🇨🇦" ;; FR) FLAG="🇫🇷" ;; NL) FLAG="🇳🇱" ;; IN) FLAG="🇮🇳" ;;
  *)  FLAG="🌍" ;;
esac

NODE_NAME="${FLAG} MSFT·${IP_LAST}-${RAND}"    # ← 绝对不重复的高端名字

SS_BASE64=$(echo -n "aes-256-gcm:$PASSWORD@$IP:24000" | base64 -w0)
SHADOWTLS_JSON=$(echo -n "{\"version\":2,\"host\":\"www.microsoft.com\",\"port\":\"443\",\"password\":\"$PASSWORD\",\"address\":\"$IP\"}" | base64 -w0)

SS_LINK="ss://$SS_BASE64#${NODE_NAME}-Plain"
SHADOWTLS_LINK="ss://$SS_BASE64?shadow-tls=$SHADOWTLS_JSON#${NODE_NAME}"

# 8. 美观输出
clear
echo "部署成功！BBR 已开启！"
echo "========================================================"
echo "节点名称 : $NODE_NAME"
echo "服务器IP : $IP"
echo "端口     : 443"
echo "密码     : $PASSWORD"
echo "加密     : aes-256-gcm"
echo "伪装域名 : www.microsoft.com"
echo "========================================================"
echo "推荐链接（直接复制这个）↓"
echo "$SHADOWTLS_LINK"
echo ""
echo "改密码方法："
echo "   vim .env  → 修改 PASSWORD=新密码 → docker compose up -d"
echo ""
docker compose ps
