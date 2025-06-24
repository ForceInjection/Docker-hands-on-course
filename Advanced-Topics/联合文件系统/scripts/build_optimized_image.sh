#!/bin/bash
# 高效镜像构建脚本

APP_NAME="web-app"
VERSION=${1:-"latest"}
REGISTRY=${2:-"localhost:5000"}

echo "=== 构建高效的 Web 应用镜像 ==="

# 1. 创建项目结构
mkdir -p web-app-demo/{src,public,config}
cd web-app-demo

# 创建 package.json
cat > package.json << 'EOF'
{
  "name": "web-app-demo",
  "version": "1.0.0",
  "scripts": {
    "build": "webpack --mode production",
    "start": "node server.js"
  },
  "dependencies": {
    "express": "^4.18.0",
    "webpack": "^5.70.0",
    "webpack-cli": "^4.9.0"
  }
}
EOF

# 创建简单的应用
cat > src/app.js << 'EOF'
console.log('Hello from optimized container!');
EOF

cat > server.js << 'EOF'
const express = require('express');
const app = express();
const port = 3000;

app.get('/', (req, res) => {
  res.send('Hello from optimized container!');
});

app.listen(port, () => {
  console.log(`App listening at http://localhost:${port}`);
});
EOF

# 创建 nginx 配置
cat > nginx.conf << 'EOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';
    
    access_log /var/log/nginx/access.log main;
    
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
    
    server {
        listen 80;
        server_name localhost;
        
        location / {
            root /usr/share/nginx/html;
            index index.html index.htm;
            try_files $uri $uri/ /index.html;
        }
        
        location /health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }
    }
}
EOF

# 创建 .dockerignore
cat > .dockerignore << 'EOF'
node_modules
npm-debug.log
.git
.gitignore
README.md
Dockerfile*
.dockerignore
*.md
.nyc_output
coverage
.env
EOF

# 2. 构建镜像
echo "\n构建镜像..."
time docker build -t $APP_NAME:$VERSION .

# 3. 分析镜像
echo "\n=== 镜像分析 ==="
docker images $APP_NAME:$VERSION
docker history $APP_NAME:$VERSION

# 4. 测试镜像
echo "\n=== 测试镜像 ==="
docker run -d --name test-$APP_NAME -p 8080:80 $APP_NAME:$VERSION
sleep 5
curl -f http://localhost:8080/health || echo "健康检查失败"
docker logs test-$APP_NAME
docker rm -f test-$APP_NAME

# 5. 推送镜像（可选）
if [ "$REGISTRY" != "localhost:5000" ]; then
    echo "\n=== 推送镜像 ==="
    docker tag $APP_NAME:$VERSION $REGISTRY/$APP_NAME:$VERSION
    docker push $REGISTRY/$APP_NAME:$VERSION
fi

echo "\n构建完成！"
cd ..
rm -rf web-app-demo