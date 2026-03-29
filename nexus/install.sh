# 1. 권한 설정
sudo chown -R 200:200 ./nexus-data
chmod +x setup.sh

# 2. Nexus 실행
docker compose up -d

# 3. 설정 자동화 스크립트 실행 (최초 1회만)
./setup.sh