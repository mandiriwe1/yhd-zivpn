#!/bin/bash
# YHD ZIVPN PULL MENU (STABLE CLEAN VERSION)

set -e
export DEBIAN_FRONTEND=noninteractive

BIN="/usr/local/bin/zivpn"
CONF="/etc/zivpn/config.json"
DB="/etc/zivpn/users.db"
URL="https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-amd64"

mkdir -p /etc/zivpn
touch $DB

# ================= INSTALL DEPENDENCY =================
apt-get update -y >/dev/null 2>&1
apt-get install -y wget curl jq openssl iproute2 procps >/dev/null 2>&1

# ================= DOWNLOAD BINARY =================
for i in 1 2 3 4 5; do
  wget -q --timeout=20 --tries=1 "$URL" -O "$BIN" && break
  sleep 2
done

chmod +x "$BIN"

if [ ! -s "$BIN" ]; then
  echo "❌ Binary gagal download"
  exit 1
fi

# ================= CONFIG =================
cat > $CONF <<EOF
{
  "listen": ":5667",
  "cert": "/etc/zivpn/zivpn.crt",
  "key": "/etc/zivpn/zivpn.key",
  "obfs": "zivpn",
  "auth": {
    "mode": "passwords",
    "config": []
  }
}
EOF

# ================= SSL =================
openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 \
-subj "/CN=YHD-ZIVPN" \
-keyout /etc/zivpn/zivpn.key \
-out /etc/zivpn/zivpn.crt >/dev/null 2>&1

# ================= SERVICE =================
cat > /etc/systemd/system/zivpn.service <<EOF
[Unit]
Description=YHD ZIVPN PANEL
After=network.target

[Service]
ExecStart=$BIN server -c $CONF
Restart=always
User=root
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable zivpn
systemctl restart zivpn

# ================= FUNCTIONS =================

add_user() {
  read -p "Password baru: " u
  echo "$u" >> $DB

  users=$(jq -r '.auth.config[]?' $CONF 2>/dev/null | grep -v "^$" || true)
  users="$users"$'\n'"$u"

  printf '%s\n' "$users" | jq -R . | jq -s . > /tmp/u.json
  jq ".auth.config = $(cat /tmp/u.json)" $CONF > /tmp/c.json
  mv /tmp/c.json $CONF

  systemctl restart zivpn
  echo "✔ Akun dibuat"
}

list_user() {
  echo ""
  echo "=== LIST AKUN ==="

  if [ ! -s "$DB" ]; then
    echo "Tidak ada akun"
  else
    nl -w2 -s'. ' "$DB"
  fi

  echo ""
}

delete_user() {
  read -p "Hapus user: " u

  grep -v "$u" $DB > /tmp/db.tmp || true
  mv /tmp/db.tmp $DB

  users=$(jq -r '.auth.config[]?' $CONF 2>/dev/null | grep -v "$u" || true)

  printf '%s\n' "$users" | jq -R . | jq -s . > /tmp/u.json
  jq ".auth.config = $(cat /tmp/u.json)" $CONF > /tmp/c.json
  mv /tmp/c.json $CONF

  systemctl restart zivpn
  echo "✔ User dihapus"
}

restart_srv() {
  systemctl restart zivpn
  echo "✔ Server restart"
}

change_domain() {
  read -p "Domain baru: " d
  jq --arg d "$d" '.domain=$d' $CONF > /tmp/c.json
  mv /tmp/c.json $CONF
  systemctl restart zivpn
  echo "✔ Domain diganti"
}

# ================= DASHBOARD (VERSI LAMA) =================

banner() {
clear

IP=$(curl -s https://api.ipify.org || echo "-")
ISP=$(curl -s ipinfo.io/org 2>/dev/null || echo "-")
UPTIME=$(uptime -p 2>/dev/null)
CPU=$(top -bn1 | awk '/Cpu/ {print $2+$4}')
RAM=$(free -m | awk 'NR==2{printf "%.1f%%",$3*100/$2}')

BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GREEN='\033[0;32m'
NC='\033[0m'

echo ""
echo -e "            ${BLUE}YHD ZIVPN${NC}"
echo -e "        ${YELLOW}━━━━━━━━━━━━━━━━${NC}"
echo ""

echo -e "${WHITE}STATUS : ${GREEN}ONLINE${NC}"
echo -e "${WHITE}IP VPS : ${CYAN}$IP${NC}"
echo -e "${WHITE}ISP    : ${YELLOW}$ISP${NC}"
echo -e "${WHITE}UPTIME : ${CYAN}$UPTIME${NC}"
echo -e "${WHITE}CPU    : ${GREEN}$CPU%${NC}"
echo -e "${WHITE}RAM    : ${CYAN}$RAM${NC}"

echo -e "${YELLOW}━━━━━━━━━━━━━━━━${NC}"
echo ""
}

# ================= MENU =================

menu() {
while true; do
  banner

  echo -e "\033[1;33m1) Create Password\033[0m"
  echo -e "\033[1;33m2) List Password\033[0m"
  echo -e "\033[1;33m3) Delete Password\033[0m"
  echo -e "\033[1;33m4) Restart Server\033[0m"
  echo -e "\033[1;33m5) Change Domain\033[0m"
  echo -e "\033[1;33m6) Exit\033[0m"
  echo ""

  read -p "Pilih menu : " opt

  case $opt in
    1) add_user ;;
    2) list_user ;;
    3) delete_user ;;
    4) restart_srv ;;
    5) change_domain ;;
    6) exit ;;
    *) echo "Menu salah" ;;
  esac

  echo ""
  read -p "Enter lanjut..."
done
}

menu
