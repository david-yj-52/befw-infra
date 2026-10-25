#!/bin/bash

# 에러 발생 시 스크립트 즉시 중단
set -e

echo "=========================================="
echo " 1. 시스템 패키지 업데이트 및 기본 유틸리티 설치"
echo "=========================================="
sudo apt-get update && sudo apt-get upgrade -y
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    git \
    htop \
    unzip \
    ufw

echo "=========================================="
echo " 2. Docker 공식 GPG 키 및 저장소 등록"
echo "=========================================="
sudo install -m 0755 -d /etc/apt/keyrings
if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
fi

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "=========================================="
echo " 3. Docker 및 Docker Compose 플러그인 설치"
echo "=========================================="
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

echo "=========================================="
echo " 4. Docker 서비스 활성화 및 시작"
echo "=========================================="
sudo systemctl start docker
sudo systemctl enable docker

echo "=========================================="
echo " 5. 현재 사용자(ubuntu)를 docker 그룹에 추가"
echo "=========================================="
TARGET_USER=${SUDO_USER:-$USER}
if [ "$TARGET_USER" != "root" ]; then
    sudo usermod -aG docker "$TARGET_USER"
    echo "사용자 '$TARGET_USER'가 docker 그룹에 추가되었습니다."
else
    echo "root 계정으로 실행되었습니다. 일반 계정으로 전환 후 'newgrp docker'를 실행해주세요."
fi

echo "=========================================="
echo " 6. 방화벽(UFW) 기본 설정 (SSH 허용)"
echo "=========================================="
sudo ufw allow OpenSSH
# Spring Boot(8080), RabbitMQ Management(15672), Solace(8080) 등 필요시 포트 개방 주석 해제 가능
# sudo ufw allow 8080/tcp
# sudo ufw allow 15672/tcp
sudo ufw --force enable

echo "=========================================="
echo " 모든 설치가 완료되었습니다!"
echo "=========================================="
docker --version
docker compose version
echo ""
echo "💡 안내: 그룹 권한을 완전히 적용하려면 SSH 연결을 끊고 재접속하거나,"
echo "   'newgrp docker' 명령어를 입력해 주세요."