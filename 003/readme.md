[< wstecz](../readme.md)

# Serwer OrangePi publicznie dostępny

[youtu.be/Hoby6VG_IQ8](https://youtu.be/Hoby6VG_IQ8)

---


## Instalacja wireguarda


<table width="100%">
<tr><th width="50%">VPS</th><th>OrangePi</th></tr>
<tr><td colspan="2">
    <i>Instalacja wireguard</i>
    <pre><code>sudo apt update 
sudo apt install wireguard -y</code></pre>
</td></tr>

<tr><td colspan="2">
    <i>Generowanie kluczy</i>
    <pre><code>wg genkey | sudo tee /etc/wireguard/private.key
sudo chmod go= /etc/wireguard/private.key
sudo cat /etc/wireguard/private.key | wg pubkey | sudo tee /etc/wireguard/public.key</code></pre>
</td></tr>


<tr><td>
    <i>Konfiguracja wireguard</i>
    <pre><code>sudo ip link add wg0 type wireguard
sudo ip addr add 10.8.0.1/24 dev wg0
sudo wg set wg0 private-key /etc/wireguard/private.key
sudo wg set wg0 listen-port 51820
sudo ip link set wg0 up
sudo wg set wg0 peer nXUM7S2rANLMnevAHsioHaoVgmNTw0dcXifEid0qkB0= allowed-ips 10.8.0.2/32</code></pre>
</td>
<td>
    <br/>
    <pre><code>sudo ip link add wg0 type wireguard
sudo ip addr add 10.8.0.2/24 dev wg0
sudo wg set wg0 private-key /etc/wireguard/private.key
sudo ip link set wg0 up
sudo wg set wg0 peer LzjE0cdkFT+6ilng2+VX/waOpLjboRT/4ChwY8qX9jU= allowed-ips 0.0.0.0/0 endpoint 57.128.194.184:51820 persistent-keepalive 60</code></pre>
</td>
</tr>

<tr><td>
    <i>Instalacja haproxy</i>
    <pre><code>sudo apt install haproxy -y</code></pre>
</td>
<td></td>
</tr>

<tr><td>
    <i>Konfiguracja haproxy</i>
    <code>/etc/haproxy/haproxy.cfg</code>
    <pre><code>frontend web_frontend
    mode http
    bind :80
    default_backend web_backend
backend web_backend
    mode http
    option forwardfor
    server tcpserver 10.8.0.2:80
frontend websecure_frontend
    mode tcp
    bind :443
    default_backend websecure_backend
backend websecure_backend
    mode tcp
    option forwardfor
    server tcpserver 10.8.0.2:443</code></pre>
</td>
<td></td>
</tr>


<tr><td>
    <i>Restart haproxy</i>
    <pre><code>sudo systemctl restart haproxy</code></pre>
</td>
<td></td>
</tr>
</table>


## Dodanie skryptu do autostartu [vps](etc/init.d/tunnel_vps.sh) / [orangePi](etc/init.d/tunnel_orangepi.sh)
```sh
sudo update-rc.d tunnel.sh defaults
```

## Dodanie proxy protocol w traefiku
```yml
entryPoints:
  web:
    address: ":80"
    proxyProtocol:
      trustedIPs:
        - "10.8.0.1/32"
  websecure:
    address: ":443"
    proxyProtocol:
      trustedIPs:
        - "10.8.0.1/32"
```

## Dodanie obsługi certyfikatów SSL letsEncrypt do traefika

*traefik.yml*
```yml
...
certificatesResolvers:
  le:
    acme:
      email: 'admin@example.com'
      storage: /certificates/acme.json
      tlschallenge: true
```

## Aktualizacja polecenia do tworzenia traefika

```sh
docker service create \
    --name traefik \
    --publish published=80,target=80,mode=host \
    --publish published=443,target=443,mode=host \
    --mount type=bind,source=/var/run/docker.sock,destination=/var/run/docker.sock,readonly=true \
    --mount type=bind,source=/mnt/capsule/traefik/config,destination=/etc/traefik \
    --mount type=bind,source=/mnt/capsule/traefik/logs,destination=/logs \
    --mount type=bind,source=/mnt/capsule/traefik/certificates,destination=/certificates \
    --network proxy \
    --env TZ=Europe/Warsaw \
    --label traefik.enable=true \
    --label 'traefik.http.routers.traefik.rule=Host(`traefik.pragmatyczny.dev`)' \
    --label traefik.http.routers.traefik.entrypoints=websecure \
    --label traefik.http.routers.traefik.tls.certresolver=le \
    --label traefik.http.routers.traefik.service=api@internal \
    --label traefik.http.routers.traefik.tls=true \
    --label traefik.http.services.traefik.loadbalancer.server.port=8080 \
    traefik:v3.3
```