# 🐳 Docker Deployment Guide - SociWave

**Date:** November 20, 2025  
**Docker Version:** >= 20.10  
**Docker Compose Version:** >= 1.29

---

## 📦 What's Included

The Docker setup includes:
- **Multi-stage Dockerfile** - Optimized build (Flutter → Nginx)
- **Nginx Configuration** - Production-ready with gzip, caching, SPA routing
- **Docker Compose** - Easy orchestration with health checks
- **Security Headers** - XSS protection, frame options, content sniffing protection

---

## 🚀 Quick Start

### Option 1: Using Docker Compose (Recommended)

```bash
# Navigate to project root
cd /home/worker/sociwave

# Build and run
docker-compose -f docker/docker-compose.yml up -d

# Check logs
docker-compose -f docker/docker-compose.yml logs -f

# Access the app
# Open browser: http://localhost:8080
```

### Option 2: Using Docker Commands

```bash
# Build the image
docker build -f docker/Dockerfile -t sociwave-web:latest .

# Run the container
docker run -d \
  --name sociwave-web \
  -p 8080:80 \
  --restart unless-stopped \
  sociwave-web:latest

# Check logs
docker logs -f sociwave-web

# Access the app
# Open browser: http://localhost:8080
```

## 🔒 HTTPS with Free SSL (Caddy + Let's Encrypt)

1. **Point DNS:** Create an A record for your domain (e.g., `sociwave.tech`) to this server's public IP and make sure ports **80** and **443** are open.
2. **Create env file (`docker/.env`):**
   ```
   DOMAIN=sociwave.tech
   ACME_EMAIL=you@example.com
   API_BASE_URL=https://sociwave.tech/api
   FRONTEND_ORIGINS=http://localhost:8080,https://sociwave.tech,https://www.sociwave.tech
   ```
3. **Build & start with TLS proxy:**
   ```bash
   docker compose -f docker/docker-compose.yml up -d --build sociwave-backend sociwave-frontend sociwave-proxy
   ```
4. Caddy will automatically request and renew certificates and terminate HTTPS on ports 80/443 while proxying `/api/*` to the backend and all other traffic to the frontend.

---

## 🛠️ Build Process Explained

### Multi-Stage Build

**Stage 1: Flutter Build**
```dockerfile
FROM ghcr.io/cirruslabs/flutter:stable AS build
```
- Uses official Flutter Docker image
- Runs `flutter pub get`
- Builds optimized web app with `--tree-shake-icons`
- Build time: ~2-3 minutes
- Build output: 31MB in `/webapp/build/web`

**Stage 2: Nginx Serve**
```dockerfile
FROM nginx:alpine
```
- Uses lightweight Alpine Linux (5MB base)
- Copies built web app to Nginx
- Adds custom configuration
- Adds health check endpoint
- Final image size: ~40MB

### Build Optimization

The build process includes:
- ✅ Tree-shaking icons (99%+ reduction)
- ✅ Release mode compilation
- ✅ Minified JavaScript
- ✅ Removed source maps
- ✅ Gzip compression enabled
- ✅ Static asset caching

---

## 📋 Available Commands

### Docker Compose Commands

```bash
# Build the image
docker-compose -f docker/docker-compose.yml build

# Start the container
docker-compose -f docker/docker-compose.yml up -d

# Stop the container
docker-compose -f docker/docker-compose.yml down

# Rebuild and restart
docker-compose -f docker/docker-compose.yml up -d --build

# View logs
docker-compose -f docker/docker-compose.yml logs -f

# Check status
docker-compose -f docker/docker-compose.yml ps

# Execute command in container
docker-compose -f docker/docker-compose.yml exec sociwave-web sh
```

### Docker Commands

```bash
# Build image
docker build -f docker/Dockerfile -t sociwave-web:latest .

# Run container
docker run -d -p 8080:80 --name sociwave-web sociwave-web:latest

# Stop container
docker stop sociwave-web

# Remove container
docker rm sociwave-web

# View logs
docker logs -f sociwave-web

# Execute shell in container
docker exec -it sociwave-web sh

# Check container health
docker inspect --format='{{.State.Health.Status}}' sociwave-web

# Remove image
docker rmi sociwave-web:latest
```

---

## 🔧 Configuration Options

### Change Port

Edit `docker/docker-compose.yml`:
```yaml
ports:
  - "3000:80"  # Change 8080 to your preferred port
```

Or use Docker run:
```bash
docker run -d -p 3000:80 --name sociwave-web sociwave-web:latest
```

### Environment Variables

Add to `docker/docker-compose.yml`:
```yaml
environment:
  - NGINX_HOST=yourdomain.com
  - NGINX_PORT=80
  - TZ=Asia/Bangkok  # Set timezone
```

### Resource Limits

Already configured in `docker-compose.yml`:
```yaml
deploy:
  resources:
    limits:
      cpus: '1'
      memory: 512M
    reservations:
      cpus: '0.5'
      memory: 256M
```

Adjust based on your server capacity.

---

## 🌐 Nginx Configuration Features

The included `nginx.conf` provides:

### 1. Gzip Compression
- Reduces bandwidth by 60-80%
- Compresses JS, CSS, HTML, JSON, WASM
- Level 6 compression

### 2. Static Asset Caching
- Images: 1 year cache
- JavaScript/CSS: 1 year cache (versioned)
- Fonts: 1 year cache
- Service Worker: No cache (always fresh)

### 3. Security Headers
- `X-Frame-Options`: Prevent clickjacking
- `X-Content-Type-Options`: Prevent MIME sniffing
- `X-XSS-Protection`: XSS protection
- `Referrer-Policy`: Control referrer information

### 4. SPA Routing
- All routes serve `index.html`
- Proper 404 handling
- Client-side routing support

### 5. Performance
- Access logs disabled for static assets
- Efficient try_files directive
- HTTP/2 ready

---

## 📊 Health Check

Health check is configured at:
- **Endpoint:** `http://localhost/index.html`
- **Interval:** 30 seconds
- **Timeout:** 3 seconds
- **Retries:** 3 attempts
- **Start Period:** 5 seconds

Check health status:
```bash
# Docker Compose
docker-compose -f docker/docker-compose.yml ps

# Docker
docker inspect --format='{{.State.Health.Status}}' sociwave-web
```

Possible statuses:
- `starting` - Container is starting up
- `healthy` - Container is healthy
- `unhealthy` - Health check failed

---

## 🚀 Production Deployment

### Option 1: Deploy to AWS ECS

1. **Build and push to ECR:**
```bash
# Login to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin YOUR_ACCOUNT.dkr.ecr.us-east-1.amazonaws.com

# Tag image
docker tag sociwave-web:latest YOUR_ACCOUNT.dkr.ecr.us-east-1.amazonaws.com/sociwave-web:latest

# Push image
docker push YOUR_ACCOUNT.dkr.ecr.us-east-1.amazonaws.com/sociwave-web:latest
```

2. **Create ECS Task Definition:**
- Use Fargate or EC2 launch type
- Assign 0.5 vCPU, 1GB memory
- Map port 80
- Add health check

3. **Create ECS Service:**
- Choose cluster
- Set desired count: 1-3
- Configure load balancer
- Enable auto-scaling

### Option 2: Deploy to Google Cloud Run

```bash
# Build and push to GCR
docker build -f docker/Dockerfile -t gcr.io/YOUR_PROJECT/sociwave-web:latest .
docker push gcr.io/YOUR_PROJECT/sociwave-web:latest

# Deploy to Cloud Run
gcloud run deploy sociwave-web \
  --image gcr.io/YOUR_PROJECT/sociwave-web:latest \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --port 80
```

### Option 3: Deploy to DigitalOcean App Platform

1. **Create App:**
- Go to DigitalOcean Dashboard
- Apps → Create App
- Choose Docker Hub or GitHub

2. **Configure:**
- Dockerfile path: `docker/Dockerfile`
- HTTP port: 80
- Instance size: Basic ($5/month)

3. **Deploy:**
- Click "Deploy App"
- Get URL: `https://sociwave-xxxxx.ondigitalocean.app`

### Option 4: Deploy to Your Own Server (VPS)

```bash
# SSH to your server
ssh user@your-server.com

# Install Docker and Docker Compose
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
sudo apt-get install docker-compose-plugin

# Clone repository
git clone https://github.com/HauTranCong/sociwave.git
cd sociwave

# Run with Docker Compose
docker-compose -f docker/docker-compose.yml up -d

# Setup Nginx reverse proxy (optional)
# Edit /etc/nginx/sites-available/sociwave
server {
    listen 80;
    server_name yourdomain.com;
    
    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}

# Enable SSL with Let's Encrypt
sudo certbot --nginx -d yourdomain.com
```

---

## 🔍 Troubleshooting

### Issue: Build fails with "flutter: command not found"

**Solution:**
```bash
# Verify Docker has internet access
docker run --rm alpine ping -c 3 google.com

# Try with explicit Flutter version
# Edit Dockerfile, change:
FROM ghcr.io/cirruslabs/flutter:3.24.0 AS build
```

### Issue: Container exits immediately

**Solution:**
```bash
# Check logs
docker logs sociwave-web

# Verify nginx config
docker run --rm sociwave-web nginx -t

# Test manually
docker run -it --rm sociwave-web sh
nginx -t
```

### Issue: Port 8080 already in use

**Solution:**
```bash
# Check what's using the port
sudo lsof -i :8080
# or
sudo netstat -tulpn | grep 8080

# Change port in docker-compose.yml
ports:
  - "3000:80"  # Use different port
```

### Issue: High memory usage

**Solution:**
```bash
# Check memory usage
docker stats sociwave-web

# Reduce memory limit in docker-compose.yml
deploy:
  resources:
    limits:
      memory: 256M  # Reduce from 512M
```

### Issue: Slow build time

**Solution:**
```bash
# Use build cache
docker-compose -f docker/docker-compose.yml build --no-cache

# Or use pre-built image (after first build)
docker pull sociwave-web:latest
```

### Issue: Container unhealthy

**Solution:**
```bash
# Check health status
docker inspect sociwave-web | grep -A 10 Health

# Test health endpoint manually
docker exec sociwave-web curl -f http://localhost/index.html

# Restart container
docker restart sociwave-web
```

---

## 📈 Performance Optimization

### 1. Enable HTTP/2

Add to `nginx.conf`:
```nginx
listen 443 ssl http2;
```

### 2. Add CDN

Use Cloudflare or AWS CloudFront:
- Point CDN to your Docker container
- Enable caching rules
- Enable Brotli compression

### 3. Database (if needed later)

Add PostgreSQL service to `docker-compose.yml`:
```yaml
services:
  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: sociwave
      POSTGRES_USER: sociwave
      POSTGRES_PASSWORD: changeme
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
```

### 4. Redis (for caching)

```yaml
services:
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
```

---

## 🔒 Security Best Practices

### 1. Use HTTPS in Production

```bash
# Add SSL certificate to container
COPY ssl/cert.pem /etc/nginx/ssl/
COPY ssl/key.pem /etc/nginx/ssl/

# Update nginx.conf
listen 443 ssl;
ssl_certificate /etc/nginx/ssl/cert.pem;
ssl_certificate_key /etc/nginx/ssl/key.pem;
```

### 2. Run as Non-Root User

Add to `Dockerfile`:
```dockerfile
RUN addgroup -g 1001 -S nginx && \
    adduser -u 1001 -S nginx -G nginx
USER nginx
```

### 3. Scan for Vulnerabilities

```bash
# Install Trivy
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin

# Scan image
trivy image sociwave-web:latest
```

### 4. Use Docker Secrets

```yaml
services:
  sociwave-web:
    secrets:
      - api_key

secrets:
  api_key:
    file: ./secrets/api_key.txt
```

---

## 📊 Monitoring

### View Logs

```bash
# Follow logs
docker-compose -f docker/docker-compose.yml logs -f

# Last 100 lines
docker-compose -f docker/docker-compose.yml logs --tail=100

# Specific service
docker logs -f sociwave-web
```

### Container Stats

```bash
# Real-time stats
docker stats sociwave-web

# All containers
docker stats
```

### Nginx Access Logs

```bash
# View access logs
docker exec sociwave-web cat /var/log/nginx/access.log

# View error logs
docker exec sociwave-web cat /var/log/nginx/error.log
```

---

## 🧹 Cleanup

### Remove Everything

```bash
# Stop and remove containers
docker-compose -f docker/docker-compose.yml down

# Remove images
docker rmi sociwave-web:latest

# Remove unused images and cache
docker system prune -a

# Remove volumes (if any)
docker volume prune
```

### Update to New Version

```bash
# Pull latest code
cd /home/worker/sociwave
git pull origin main

# Rebuild and deploy
docker-compose -f docker/docker-compose.yml up -d --build

# Old containers are automatically replaced
```

---

## 📝 Docker Compose vs Kubernetes

**Use Docker Compose when:**
- ✅ Single server deployment
- ✅ Development/staging environment
- ✅ Small to medium traffic
- ✅ Simple orchestration needs

**Use Kubernetes when:**
- ⚠️ Multi-server cluster
- ⚠️ High availability requirements
- ⚠️ Auto-scaling needed
- ⚠️ Large-scale production

For most use cases, Docker Compose is sufficient!

---

## 🎯 Next Steps

After deploying with Docker:

1. **Test the deployment:**
   - Open http://localhost:8080
   - Verify all features work
   - Check browser console for errors

2. **Setup monitoring:**
   - Add logging service (ELK, Datadog)
   - Configure alerts
   - Track uptime

3. **Setup CI/CD:**
   - Auto-build on git push
   - Auto-deploy to production
   - Run tests before deploy

4. **Add domain:**
   - Point DNS to server IP
   - Setup SSL with Let's Encrypt
   - Configure reverse proxy

5. **Backup strategy:**
   - Regular database backups
   - Container image versioning
   - Config file backups

---

## 📚 Additional Resources

- [Docker Documentation](https://docs.docker.com/)
- [Nginx Documentation](https://nginx.org/en/docs/)
- [Flutter Web Deployment](https://docs.flutter.dev/deployment/web)
- [Docker Compose Reference](https://docs.docker.com/compose/compose-file/)

---

## 🆘 Support

If you encounter issues:
1. Check logs: `docker logs sociwave-web`
2. Verify health: `docker ps`
3. Test nginx config: `docker exec sociwave-web nginx -t`
4. Review this guide's troubleshooting section

---

*Docker Deployment Guide*  
*Phase 7 - Container Deployment*  
*Generated: November 20, 2025*
