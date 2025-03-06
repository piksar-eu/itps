[< wstecz](../readme.md)

# Jak zamienić Orange Pi 5 w webserver?

[youtu.be/tPx3Y3KTgJQ](https://youtu.be/tPx3Y3KTgJQ)

---


# skopiowanie obrazu debiana na emmc
```sh
sudo dd if="/home/orangepi/Orangepi5plus_1.2.0_debian_bookworm_server_linux6.1.43.img" of=/dev/mmcblk0 bs=4M status=progress
```

# zmiana hasła roota
```sh
sudo passwd root
```

# wyłączenie logowania na konto roota przez ssh
```sh
sed -i 's/^PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
```

# zainicjowanie dysku nvme
```sh
# formatowanie
sudo mkfs.ext4 /dev/nvme0n1
# utworzeneie punktu montowania
sudo mkdir -p /mnt/capsule
# odczyt uuid dysku
sudo blkid /dev/nvme0n1
# dodanie punktu montowania do pliku /etc/fstab
UUID=49c1e904-9318-48c8-8b93-139ebb75b32c /mnt/capsule ext4 defaults 0 2
# zamontowanie wszystkich dysków
sudo mount -a
```

# instalacja dockera z oficjalnych źródeł
```sh
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker $USER
newgrp docker

# test
docker run hello-world
```

# zainicjowanie trybu swarm w dockerze
```sh
docker swarm init
```

# uruchomienie postgresa w docker swarmie
```sh
# dodanie sieci dockera
docker network create --scope=swarm --attachable --driver=overlay internal

# przygotowanie folderu na dane postgresa
mkdir -p /mnt/capsule/postgres/data
sudo chmod 777 /mnt/capsule/postgres/data

# utworzenie secretu z hasłem postgresa
printf 'Superstron9PAss' | docker secret create postgres-passwd -

# uruchomienie usługi postgresa
docker service create \
    --name webapp-postgres \
    --network internal \
    --env POSTGRES_PASSWORD_FILE=/run/secrets/postgres-passwd \
    --env PGDATA=/var/lib/postgresql/data/pgdata \
    --secret postgres-passwd \
    --mount type=bind,source=/mnt/capsule/postgres/data,destination=/var/lib/postgresql/data \
    --user postgres \
    postgres:15

# zmiejszenie uprawnień do folderu z danymi postgresa
sudo ls -la /mnt/capsule/postgres/data
sudo chown 999:19 /mnt/capsule/postgres/data
sudo chmod 700 /mnt/capsule/postgres/data
```

# uruchomienie webaplikacji jako usługi dockera
```sh
# pobranie repozytorium
git clone https://github.com/piksar-eu/webapp
cd webapp
# budowa obrazu dockera
docker build -f .docker/webapp/Dockerfile -t webapp .

# uruchomienie usługi
docker service create \
    --name webapp-app \
    --network internal \
    --env API_PORT=8080 \
    --env WEBSITE_PORT=80 \
    --env PG_HOST=webapp-postgres \
    --env PG_USER=postgres \
    --env PG_PASS='Superstron9PAss' \
    --env PG_DBNAME=postgres \
    --env CORS_ALLOWED_ORIGINS=http://10.1.1.198 \
    --publish published=80,target=80,mode=host \
    --publish published=8080,target=8080,mode=host \
    webapp:latest

# sprawdzenie listy i stanu usług
docker service ls
# sprawdzenie logów usługi
docker service logs -f webapp-app
```
