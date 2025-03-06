[< wstecz](../readme.md)

# Instaluję traefik na mini serwerze z dockerem

[youtu.be/o_GZKzJf2Cs](https://youtu.be/o_GZKzJf2Cs)

---

## usunięcie usługi webaplikacji
```sh
docker service rm webapp-app
```

## stworzenie konfiguracji traefika
*/mnt/capsule/traefik/config/traefik.yml*
```yml
entryPoints:
  web:
    address: ":80"
  websecure:
    address: ":443"

api:
  dashboard: true

providers:
  swarm:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
    watch: true
    network: proxy

log:
  level: INFO # DEBUG|INFO|WARNING|ERROR|CRITICAL
```

## dodanie sieci proxy do docker swarma
```sh
docker network create --scope=swarm --attachable --driver=overlay proxy
```

## utworzenie usługi traefika
```sh
docker service create \
    --name traefik \
    --publish published=80,target=80,mode=host \
    --publish published=443,target=443,mode=host \
    --mount type=bind,source=/var/run/docker.sock,destination=/var/run/docker.sock,readonly=true \
    --mount type=bind,source=/mnt/capsule/traefik/config,destination=/etc/traefik \
    --network proxy \
    --env TZ=Europe/Warsaw \
    --label traefik.enable=true \
    --label 'traefik.http.routers.traefik.rule=Host(`traefik.pragmatyczny.dev`)' \
    --label traefik.http.routers.traefik.entrypoints=websecure \
    --label traefik.http.routers.traefik.service=api@internal \
    --label traefik.http.routers.traefik.tls=true \
    --label traefik.http.services.traefik.loadbalancer.server.port=8080 \
    traefik:v3.3
```

## utworzenie usługi webaplikacji
```sh
docker service create \
    --name webapp-app \
    --network internal \
    --network proxy \
    --env API_PORT=8080 \
    --env WEBSITE_PORT=80 \
    --env PG_HOST=webapp-postgres \
    --env PG_USER=postgres \
    --env PG_PASS='Superstron9PAss' \
    --env PG_DBNAME=postgres \
    --env VITE_API_URL='https://pragmatyczny.dev' \
    --label traefik.enable=true \
    --label 'traefik.http.routers.webapp-website.rule=Host(`pragmatyczny.dev`) || Host(`www.pragmatyczny.dev`)' \
    --label traefik.http.routers.webapp-website.entrypoints=websecure \
    --label traefik.http.routers.webapp-website.tls=true \
    --label traefik.http.routers.webapp-website.service=webapp-website \
    --label traefik.http.services.webapp-website.loadbalancer.server.port=80 \
    --label traefik.http.routers.webapp-website.priority=1 \
    --label 'traefik.http.routers.webapp-api.rule=Host(`pragmatyczny.dev`) && PathPrefix(`/api`)' \
    --label traefik.http.routers.webapp-api.entrypoints=websecure \
    --label traefik.http.routers.webapp-api.tls=true \
    --label traefik.http.routers.webapp-api.service=webapp-api \
    --label traefik.http.routers.webapp-api.priority=2 \
    --label traefik.http.services.webapp-api.loadbalancer.server.port=8080 \
    webapp:latest
```

# Middleware

## dodanie dynamicznej konfiguracji do traefika
*/mnt/capsule/traefik/config/traefik.yml*
```yml
...
providers:
  ...
  file:
    filename: /etc/traefik/dynamic.yml
    watch: true
```

## security headers
```yaml
http:
  middlewares:
    security-headers:
      headers:
        customResponseHeaders:
          X-Robots-Tag: "none,noarchive,nosnippet,notranslate,noimageindex"
          Server: ""
          X-Powered-By: ""
          X-Forwarded-Proto: "https"
          Permissions-Policy: "geolocation=(), camera=(), microphone=(), usb=()"
          X-Download-Options: "noopen"
        sslProxyHeaders:
          X-Forwarded-Proto: "https"
        hostsProxyHeaders:
          - "X-Forwarded-Host"
        customRequestHeaders:
          X-Forwarded-Proto: "https"
        contentTypeNosniff: true
        customFrameOptionsValue: "SAMEORIGIN"
        browserXssFilter: true
        referrerPolicy: "strict-origin-when-cross-origin"
        forceSTSHeader: true
        stsIncludeSubdomains: true
        stsSeconds: 63072000
        stsPreload: true
        contentSecurityPolicy: "default-src 'self'; script-src 'self' 'unsafe-inline'; object-src 'none'; base-uri 'self'"
```

## dodanie middleware do routingu z frontendem
```sh
docker service update --label-add traefik.http.routers.webapp-website.middlewares=security-headers@file webapp-app
```

## rate limit
```yml
http:
  middlewares:
    rate-limit:
      rateLimit:
        average: 20
        period: 1
        burst: 50
```

## redirects
```yml
http:
  middlewares:
    nonwww-redirect:
      redirectRegex:
        regex: "^https?://www\\.(.*)"
        replacement: "https://$1"
        permanent: true
        
    www-redirect:
      redirectRegex:
        regex: "^https?://([^www.]+\\.[a-zA-Z]{2,})"
        replacement: "https://www.$1"
        permanent: true
        
```

# Logi

## dodanie access logów do traefika

*/mnt/capsule/traefik/config/traefik.yml*
```yml
accessLog:
  filePath: "/logs/traefik.log"
  format: json
  bufferingSize: 50
  fields:
    headers:
      defaultMode: drop
      names:
        User-Agent: keep
```

## konfiguracja logrotate

*/etc/logrotate.d/traefik*
```
/mnt/capsule/traefik/logs/traefik.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
    dateext
    dateformat -%Y%m%d-%H%M%S
}
```

# test konfiguracji
```sh
sudo logrotate -d /etc/logrotate.d/traefik
```

# wymuszenie rotowania
```sh
sudo logrotate -f /etc/logrotate.d/traefik
```