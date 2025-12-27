# Classroom Reservation System - Docker Deployment

Sistem za rezervacijo učilnic z Laravel aplikacijo, gostovan v Docker kontejnerjih z avtomatskim CI/CD pipeline in TLS podporo.

## Vsebina projekta

- **Laravel aplikacija** (PHP-FPM 8.2) - Custom multi-stage build
- **MySQL 8.0** - Relacijska baza podatkov
- **Redis 7** - Cache in session storage
- **Nginx** - Web server in reverse proxy
- **Certbot** - Let's Encrypt SSL certifikati

## Arhitektura

```
Internet → Nginx (Port 80/443) → PHP-FPM (Laravel)
                              ↓
                        MySQL + Redis
```

### Servisi

1. **laravel-app** - Laravel aplikacija (PHP-FPM 8.2)
   - Custom multi-stage Docker build
   - Minimalna Alpine slika
   - Non-root user (appuser:1000)
   - OPcache optimizacija

2. **nginx** - Web server
   - Serves static files
   - Proxies PHP requests to PHP-FPM
   - SSL/TLS support (Let's Encrypt)

3. **mysql** - MySQL 8.0 database
   - Persistent volume za podatke
   - Health checks
   - Auto-initialization z db.sql

4. **redis** - Redis 7 cache
   - Session storage
   - Cache driver
   - AOF persistence

5. **certbot** - Let's Encrypt certificates
   - Avtomatsko obnavljanje certifikatov
   - TLS/SSL konfiguracija

## Hitri začetek

### Lokalno razvojno okolje

```bash
# 1. Ustvarite .env datoteko
cat > .env << 'EOF'
DOMAIN=localhost
SSL_ENABLED=false
APP_ENV=local
APP_DEBUG=true

DB_DATABASE=ucilnice
DB_USERNAME=ucilnice
DB_PASSWORD=ucilnice
MYSQL_ROOT_PASSWORD=rootpassword

REDIS_PASSWORD=redispassword
EOF

# 2. Zgradite in zaženite
docker compose build laravel-app
docker compose up -d

# 3. Namestite vendor
docker run --rm -v $(pwd)/ucilnice:/app -w /app composer:2.6 composer install --no-dev --optimize-autoloader

# 4. Generirajte APP_KEY
docker compose exec laravel-app php artisan key:generate

# 5. Zaženite migracije
docker compose exec laravel-app php artisan migrate

# 6. Zgradite frontend assets
docker run --rm -v $(pwd)/ucilnice:/app -w /app node:20-alpine sh -c "npm install && npm run build"
```

Dostop: `http://localhost`

### Produkcijsko okolje s SSL

```bash
# 1. Nastavite domeno v .env
DOMAIN=your-domain.com
SSL_ENABLED=true

# 2. Zaženite servise
docker compose up -d

# 3. Pridobite SSL certifikat
./scripts/get-certificate.sh your-domain.com your-email@example.com

# 4. Zaženite certbot za avtomatsko obnavljanje
docker compose --profile ssl up -d certbot
```

Dostop: `https://your-domain.com`

## Docker Compose Servisi

### Laravel App (PHP-FPM)

- **Image**: Custom multi-stage build
- **Port**: 9000 (internal)
- **User**: Non-root (appuser:1000)
- **Volumes**: Application code, storage directory
- **Health Check**: PHP process check

**Multi-stage Build:**
1. **Composer Stage**: Installs dependencies, generates optimized autoloader
2. **PHP-FPM Stage**: Minimal Alpine runtime with PHP extensions

### Nginx

- **Image**: `nginx:alpine`
- **Ports**: 80 (HTTP), 443 (HTTPS)
- **Volumes**: Application code (read-only), SSL certificates
- **Health Check**: HTTP endpoint check

### MySQL 8.0

- **Image**: `mysql:8.0`
- **Port**: 3306 (internal)
- **Volume**: `mysql_data` (persistent)
- **Health Check**: `mysqladmin ping`
- **Init Script**: `db.sql` auto-imported on first run

### Redis 7

- **Image**: `redis:7-alpine`
- **Port**: 6379 (internal)
- **Volume**: `redis_data` (persistent, AOF enabled)
- **Health Check**: Redis CLI ping
- **Password**: Required (set via `REDIS_PASSWORD`)

### Certbot

- **Image**: `certbot/certbot:latest`
- **Volumes**: Certificate storage, webroot
- **Function**: Automatic Let's Encrypt certificate renewal
- **Profile**: `ssl` (only runs when needed)

## Varnost

### Implementirano

- Non-root containers (PHP-FPM runs as `appuser:1000`)
- Network isolation (services on separate networks)
- Health checks (all services)
- Security headers (Nginx)
- TLS/SSL (Let's Encrypt certificates)
- Redis password authentication
- MySQL root password protection
- Read-only volumes where possible

### Priporočila

1. Firewall: Restrict access to ports 80, 443 only
2. Secrets Management: Use Docker secrets or external vault
3. Regular Updates: Keep base images updated
4. Monitoring: Add Prometheus/Grafana
5. Log Aggregation: Centralized logging (ELK stack)

## CI/CD Pipeline

GitHub Actions workflow (`.github/workflows/docker-build.yml`):

- **Triggers**: Push to main/master, tags, PRs
- **BuildX**: Multi-platform builds (amd64, arm64)
- **Layer Caching**: Registry-based cache
- **Docker Hub**: Automatic push on main branch
- **Tags**: Semantic versioning, branch names, SHA

### Setup

1. Add secrets to GitHub:
   - `DOCKERHUB_USERNAME`
   - `DOCKERHUB_TOKEN`

2. Push to trigger build:
```bash
git push origin main
```

## Volumes

### Persistent Data

- `mysql_data`: MySQL database files
- `redis_data`: Redis AOF persistence
- `certbot_www`: Let's Encrypt webroot
- `certbot_conf`: Let's Encrypt certificates

## Razvoj

### Artisan ukazi

```bash
docker compose exec laravel-app php artisan migrate
docker compose exec laravel-app php artisan tinker
docker compose exec laravel-app php artisan route:list
```

### Composer

```bash
docker run --rm -v $(pwd)/ucilnice:/app -w /app composer:2.6 composer install
docker run --rm -v $(pwd)/ucilnice:/app -w /app composer:2.6 composer update
```

### NPM/Frontend

```bash
docker run --rm -v $(pwd)/ucilnice:/app -w /app node:20-alpine npm install
docker run --rm -v $(pwd)/ucilnice:/app -w /app node:20-alpine npm run build
```

### Logi

```bash
# Vsi servisi
docker compose logs -f

# Določen servis
docker compose logs -f laravel-app
docker compose logs -f nginx
docker compose logs -f mysql
docker compose logs -f redis
```

## Konfiguracija

### Environment Variables

Glavne spremenljivke v `.env`:

```env
DOMAIN=localhost                    # Domena (localhost za lokalno, domena za produkcijo)
SSL_ENABLED=false                  # Omogoči SSL (true za produkcijo)
APP_ENV=local                      # Okolje (local/production)
APP_DEBUG=true                      # Debug način

DB_DATABASE=ucilnice               # Ime baze podatkov
DB_USERNAME=ucilnice              # DB uporabnik
DB_PASSWORD=ucilnice              # DB geslo
MYSQL_ROOT_PASSWORD=rootpassword  # MySQL root geslo

REDIS_PASSWORD=redispassword      # Redis geslo
```

### Nginx Konfiguracija

- `docker/nginx/nginx.conf` - Glavna Nginx konfiguracija
- `docker/nginx/default.conf` - HTTP server block
- `docker/nginx/default-ssl.conf` - HTTPS server block
- `docker/nginx/entrypoint.sh` - Dynamic SSL configuration

### PHP Konfiguracija

- `docker/php/php.ini` - PHP nastavitve
- `docker/php/opcache.ini` - OPcache optimizacije

## Dokumentacija

- **README.md** - Ta datoteka (glavna dokumentacija)
- **README-LOCAL.md** - Navodila za lokalno razvojno okolje
- **README-LETSENCRYPT.md** - Navodila za Let's Encrypt SSL (opcijsko)
- **README-LETSENCRYPT-LOCAL.md** - Let's Encrypt za lokalno okolje (opcijsko)

## Odpravljanje težav

### Aplikacija ne deluje

```bash
# Preverite status
docker compose ps

# Preverite loge
docker compose logs laravel-app

# Preverite vendor
docker compose exec laravel-app ls -la /var/www/html/vendor
```

### Baza podatkov ne deluje

```bash
# Preverite MySQL log
docker compose logs mysql

# Testirajte povezavo
docker compose exec laravel-app php artisan tinker
>>> DB::connection()->getPdo();
```

### SSL certifikat se ne pridobi

```bash
# Preverite DNS
dig your-domain.com

# Preverite port 80
sudo firewall-cmd --list-ports

# Preverite certbot log
docker compose logs certbot
```

## Zahteve projekta

- **Minimum 4 različne storitve** - 5 servisov (laravel-app, nginx, mysql, redis, certbot)
- **Docker Compose** - Celoten stack z docker-compose.yml
- **Volumes** - mysql_data, redis_data, certbot volumes
- **Multi-stage build** - Custom Dockerfile z composer-stage in php-fpm stage
- **BuildX optimizacija** - GitHub Actions z BuildX in layer caching
- **CI/CD** - GitHub Actions za avtomatsko gradnjo in push
- **TLS** - Let's Encrypt z Certbot za SSL certifikate
- **Dokumentacija** - Obsežna dokumentacija z README datotekami  

## Licenca

MIT

## Avtorji

DevOps projekt - Sistem za rezervacijo učilnic

