sudo bash -c '
echo "=========================================="
echo "1. WAITING FOR UBUNTU AUTO-UPDATES TO FINISH"
echo "=========================================="
while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 ; do
    echo "Ubuntu background updates are running. Waiting 5 seconds..."
    sleep 5
done
echo "Package manager is free! Proceeding..."

echo "=========================================="
echo "2. CLEAN UP PREVIOUS BROKEN ATTEMPTS"
echo "=========================================="
rm -f /etc/apt/sources.list.d/docker.list
if [ -d "/opt/tacticalrmm" ]; then
    rm -rf /opt/tacticalrmm
fi

echo "=========================================="
echo "3. DEPENDENCY & PREQUISITE PACKAGES"
echo "=========================================="
mkdir -p /etc/needrestart/conf.d
echo '"'"'$nrconf{restart} = "a";'"'"' > /etc/needrestart/conf.d/99-disable-prompt.conf
echo '"'"'$nrconf{kernelhints} = 0;'"'"' >> /etc/needrestart/conf.d/99-disable-prompt.conf

export DEBIAN_FRONTEND=noninteractive

apt-get update && apt-get install -y -o Dpkg::Options::="--force-confold" sudo curl gpg ca-certificates lsb-release gnupg

if id "pete" &>/dev/null; then
    usermod -aG sudo,docker pete
fi

echo "=========================================="
echo "4. DOCKER ENGINE INSTALLATION"
echo "=========================================="
if ! command -v docker &> /dev/null; then
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu noble stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
fi

echo "=========================================="
echo "5. SELF-SIGNED CERTIFICATE INFRASTRUCTURE"
echo "=========================================="
mkdir -p /opt/tacticalrmm/api/certs
mkdir -p /etc/letsencrypt/live/tactical.lan/

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /opt/tacticalrmm/api/certs/rmm.key \
  -out /opt/tacticalrmm/api/certs/rmm.crt \
  -subj "/C=US/ST=State/L=City/O=Tactical/CN=rmm.tactical.lan"

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/letsencrypt/live/tactical.lan/privkey.pem \
  -out /etc/letsencrypt/live/tactical.lan/fullchain.pem \
  -subj "/CN=tactical.lan"

chown -R pete:pete /opt/tacticalrmm

echo "=========================================="
echo "6. LAUNCH TACTICAL RMM INSTALLER ENVIRONMENT"
echo "=========================================="
cd /opt/tacticalrmm
curl -o install.sh https://raw.githubusercontent.com/amidaware/tacticalrmm/develop/install.sh

sed -i "s/certbot/echo \"Certbot skipped\"/g" install.sh
sed -i "s/\"22.04\"/\"24.04\"/g" install.sh

chmod +x install.sh

echo "pete ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/99-pete-installer
su - pete -c "cd /opt/tacticalrmm && ./install.sh --no-letsencrypt"
rm -f /etc/sudoers.d/99-pete-installer

echo "=========================================="
echo "7. BRINGING CONTAINER STACK ONLINE"
echo "=========================================="
if [ -f "/opt/tacticalrmm/docker-compose.yml" ]; then
    cd /opt/tacticalrmm
    docker compose up -d
fi

echo "=========================================="
echo "Setup steps completed successfully!"
echo "=========================================="
'
