#!/bin/bash
set -e

NEXUS_URL="http://localhost:8081"
NEW_PASSWORD="your-strong-password"  # ← 원하는 비밀번호로 변경

echo "⏳ Nexus 기동 대기 중..."
until curl -sf "$NEXUS_URL/service/rest/v1/status" > /dev/null; do
  sleep 5
  echo "  ... 아직 기동 중"
done
echo "✅ Nexus 기동 완료"

INIT_PW=$(docker exec nexus cat /nexus-data/admin.password)
AUTH="admin:$INIT_PW"

# ── 1. 비밀번호 변경 ──────────────────────────────────────
echo "🔑 비밀번호 변경 중..."
curl -sf -u "$AUTH" -X PUT "$NEXUS_URL/service/rest/v1/security/users/admin/change-password" \
  -H "Content-Type: text/plain" \
  -d "$NEW_PASSWORD"
AUTH="admin:$NEW_PASSWORD"

# ── 2. Anonymous Access 비활성화 ─────────────────────────
echo "🔒 Anonymous access 비활성화..."
curl -sf -u "$AUTH" -X PUT "$NEXUS_URL/service/rest/v1/security/anonymous" \
  -H "Content-Type: application/json" \
  -d '{"enabled": false}'

# ── 3. Realm 활성화 (Docker + npm) ───────────────────────
echo "🔐 Realm 활성화 (Docker, npm)..."
curl -sf -u "$AUTH" -X PUT "$NEXUS_URL/service/rest/v1/security/realms/active" \
  -H "Content-Type: application/json" \
  -d '["NexusAuthenticatingRealm", "DockerToken", "NpmToken"]'

# ══════════════════════════════════════════════════════════
# DOCKER
# ══════════════════════════════════════════════════════════

# ── 4. Docker Hosted (내부 이미지 push용) ────────────────
echo "🐳 Docker hosted repository 생성..."
curl -sf -u "$AUTH" -X POST "$NEXUS_URL/service/rest/v1/repositories/docker/hosted" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "docker-hosted",
    "online": true,
    "storage": {
      "blobStoreName": "default",
      "strictContentTypeValidation": true,
      "writePolicy": "allow"
    },
    "docker": {
      "v1Enabled": false,
      "forceBasicAuth": true,
      "httpPort": 8082
    }
  }'

# ── 5. Docker Proxy (Docker Hub 캐싱) ────────────────────
echo "🐳 Docker proxy repository 생성..."
curl -sf -u "$AUTH" -X POST "$NEXUS_URL/service/rest/v1/repositories/docker/proxy" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "docker-proxy",
    "online": true,
    "storage": {
      "blobStoreName": "default",
      "strictContentTypeValidation": true
    },
    "proxy": {
      "remoteUrl": "https://registry-1.docker.io",
      "contentMaxAge": 1440,
      "metadataMaxAge": 1440
    },
    "docker": {
      "v1Enabled": false,
      "forceBasicAuth": true
    },
    "dockerProxy": {"indexType": "HUB"}
  }'

# ── 6. Docker Group (hosted + proxy 통합) ────────────────
echo "🐳 Docker group repository 생성..."
curl -sf -u "$AUTH" -X POST "$NEXUS_URL/service/rest/v1/repositories/docker/group" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "docker-group",
    "online": true,
    "storage": {
      "blobStoreName": "default",
      "strictContentTypeValidation": true
    },
    "group": {
      "memberNames": ["docker-hosted", "docker-proxy"]
    },
    "docker": {
      "v1Enabled": false,
      "forceBasicAuth": true,
      "httpPort": 8083
    }
  }'

# ══════════════════════════════════════════════════════════
# PYTHON (PyPI)
# ══════════════════════════════════════════════════════════

# ── 7. PyPI Hosted (내부 패키지 배포용) ──────────────────
echo "🐍 PyPI hosted repository 생성..."
curl -sf -u "$AUTH" -X POST "$NEXUS_URL/service/rest/v1/repositories/pypi/hosted" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "pypi-hosted",
    "online": true,
    "storage": {
      "blobStoreName": "default",
      "strictContentTypeValidation": true,
      "writePolicy": "allow"
    }
  }'

# ── 8. PyPI Proxy (pypi.org 캐싱) ────────────────────────
echo "🐍 PyPI proxy repository 생성..."
curl -sf -u "$AUTH" -X POST "$NEXUS_URL/service/rest/v1/repositories/pypi/proxy" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "pypi-proxy",
    "online": true,
    "storage": {
      "blobStoreName": "default",
      "strictContentTypeValidation": true
    },
    "proxy": {
      "remoteUrl": "https://pypi.org",
      "contentMaxAge": 1440,
      "metadataMaxAge": 1440
    }
  }'

# ── 9. PyPI Group ─────────────────────────────────────────
echo "🐍 PyPI group repository 생성..."
curl -sf -u "$AUTH" -X POST "$NEXUS_URL/service/rest/v1/repositories/pypi/group" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "pypi-group",
    "online": true,
    "storage": {
      "blobStoreName": "default",
      "strictContentTypeValidation": true
    },
    "group": {
      "memberNames": ["pypi-hosted", "pypi-proxy"]
    }
  }'

# ══════════════════════════════════════════════════════════
# JAVA (Maven)
# ══════════════════════════════════════════════════════════

# ── 10. Maven Releases ────────────────────────────────────
echo "☕ Maven releases repository 생성..."
curl -sf -u "$AUTH" -X POST "$NEXUS_URL/service/rest/v1/repositories/maven/hosted" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "maven-releases",
    "online": true,
    "storage": {
      "blobStoreName": "default",
      "strictContentTypeValidation": true,
      "writePolicy": "allow_once"
    },
    "maven": {
      "versionPolicy": "RELEASE",
      "layoutPolicy": "STRICT"
    }
  }'

# ── 11. Maven Snapshots ───────────────────────────────────
echo "☕ Maven snapshots repository 생성..."
curl -sf -u "$AUTH" -X POST "$NEXUS_URL/service/rest/v1/repositories/maven/hosted" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "maven-snapshots",
    "online": true,
    "storage": {
      "blobStoreName": "default",
      "strictContentTypeValidation": true,
      "writePolicy": "allow"
    },
    "maven": {
      "versionPolicy": "SNAPSHOT",
      "layoutPolicy": "STRICT"
    }
  }'

# ── 12. Maven Proxy (Maven Central 캐싱) ─────────────────
echo "☕ Maven proxy repository 생성..."
curl -sf -u "$AUTH" -X POST "$NEXUS_URL/service/rest/v1/repositories/maven/proxy" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "maven-proxy",
    "online": true,
    "storage": {
      "blobStoreName": "default",
      "strictContentTypeValidation": true
    },
    "proxy": {
      "remoteUrl": "https://repo1.maven.org/maven2/",
      "contentMaxAge": 1440,
      "metadataMaxAge": 1440
    },
    "maven": {
      "versionPolicy": "RELEASE",
      "layoutPolicy": "PERMISSIVE"
    }
  }'

# ── 13. Maven Group ───────────────────────────────────────
echo "☕ Maven group repository 생성..."
curl -sf -u "$AUTH" -X POST "$NEXUS_URL/service/rest/v1/repositories/maven/group" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "maven-group",
    "online": true,
    "storage": {
      "blobStoreName": "default",
      "strictContentTypeValidation": true
    },
    "group": {
      "memberNames": ["maven-releases", "maven-snapshots", "maven-proxy"]
    },
    "maven": {
      "versionPolicy": "MIXED",
      "layoutPolicy": "PERMISSIVE"
    }
  }'

# ══════════════════════════════════════════════════════════
# NODE.JS (npm)
# ══════════════════════════════════════════════════════════

# ── 14. npm Hosted (내부 패키지 배포용) ──────────────────
echo "📦 npm hosted repository 생성..."
curl -sf -u "$AUTH" -X POST "$NEXUS_URL/service/rest/v1/repositories/npm/hosted" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "npm-hosted",
    "online": true,
    "storage": {
      "blobStoreName": "default",
      "strictContentTypeValidation": true,
      "writePolicy": "allow"
    }
  }'

# ── 15. npm Proxy (npmjs.org 캐싱) ───────────────────────
echo "📦 npm proxy repository 생성..."
curl -sf -u "$AUTH" -X POST "$NEXUS_URL/service/rest/v1/repositories/npm/proxy" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "npm-proxy",
    "online": true,
    "storage": {
      "blobStoreName": "default",
      "strictContentTypeValidation": true
    },
    "proxy": {
      "remoteUrl": "https://registry.npmjs.org",
      "contentMaxAge": 1440,
      "metadataMaxAge": 1440
    },
    "npm": {
      "removeQuarantined": true
    }
  }'

# ── 16. npm Group ─────────────────────────────────────────
echo "📦 npm group repository 생성..."
curl -sf -u "$AUTH" -X POST "$NEXUS_URL/service/rest/v1/repositories/npm/group" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "npm-group",
    "online": true,
    "storage": {
      "blobStoreName": "default",
      "strictContentTypeValidation": true
    },
    "group": {
      "memberNames": ["npm-hosted", "npm-proxy"]
    }
  }'

# ══════════════════════════════════════════════════════════
# HELM
# ══════════════════════════════════════════════════════════

# ── 17. Helm Hosted (내부 차트 배포용) ───────────────────
echo "⎈  Helm hosted repository 생성..."
curl -sf -u "$AUTH" -X POST "$NEXUS_URL/service/rest/v1/repositories/helm/hosted" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "helm-hosted",
    "online": true,
    "storage": {
      "blobStoreName": "default",
      "strictContentTypeValidation": true,
      "writePolicy": "allow"
    }
  }'

# ── 18. Helm Proxy (Artifact Hub 캐싱) ───────────────────
echo "⎈  Helm proxy repository 생성..."
curl -sf -u "$AUTH" -X POST "$NEXUS_URL/service/rest/v1/repositories/helm/proxy" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "helm-proxy",
    "online": true,
    "storage": {
      "blobStoreName": "default",
      "strictContentTypeValidation": true
    },
    "proxy": {
      "remoteUrl": "https://charts.helm.sh/stable",
      "contentMaxAge": 1440,
      "metadataMaxAge": 1440
    }
  }'

# ══════════════════════════════════════════════════════════
# RAW (EXE 바이너리)
# ══════════════════════════════════════════════════════════

# ── 19. Raw Hosted (Agent / Loader EXE 저장용) ───────────
echo "📁 Raw hosted repository 생성 (Agent/Loader EXE용)..."
curl -sf -u "$AUTH" -X POST "$NEXUS_URL/service/rest/v1/repositories/raw/hosted" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "raw-hosted",
    "online": true,
    "storage": {
      "blobStoreName": "default",
      "strictContentTypeValidation": false,
      "writePolicy": "allow"
    }
  }'

# ══════════════════════════════════════════════════════════
# 완료
# ══════════════════════════════════════════════════════════
echo ""
echo "🎉 모든 설정 완료!"
echo ""
echo "  UI          → http://localhost:8081  (admin / $NEW_PASSWORD)"
echo "  Docker push → localhost:8082  (docker-hosted)"
echo "  Docker pull → localhost:8083  (docker-group)"
echo "  PyPI        → http://localhost:8081/repository/pypi-group/"
echo "  Maven       → http://localhost:8081/repository/maven-group/"
echo "  npm         → http://localhost:8081/repository/npm-group/"
echo "  Helm        → http://localhost:8081/repository/helm-hosted/"
echo "  Raw (EXE)   → http://localhost:8081/repository/raw-hosted/"