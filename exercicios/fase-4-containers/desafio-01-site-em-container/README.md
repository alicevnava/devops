# Desafio 4.1 — O "Site da equipe" num container

Primeiro desafio da Fase 4 (Containers) da trilha de estudos: empacotar o "Site da equipe" numa **imagem de container** com o **Podman**, rodar sem root, operar o container, usar um volume com SELinux e fazê-lo subir no boot como serviço do systemd (**Quadlet**).

**Arquivos:** [`containers/site-equipe/`](../../../containers/site-equipe/) (`Containerfile`, `index.html`, `site-equipe.container`)

**Método:** primeiro uma imagem pública, depois a própria; investigar cada erro pelo log do programa e pelo SELinux.

---

## Ambiente

| Item | Valor |
|---|---|
| **Servidor** | `servidor1` (Rocky Linux 10.2), usuário `alice_estudo` |
| **Podman** | 5.8.2, **rootless** (sem root) |
| **Portas** | 80 e 443 já são do Nginx do sistema ([Desafio 2.2](../../fase-2-redes/desafio-02-proxy-reverso-nginx/)); os containers usam 8090 e 8091 |

---

## Conceitos

| Termo | Significa |
|---|---|
| **Imagem** | o pacote: sistema de arquivos com o programa e tudo de que ele precisa. Fica guardada; não roda |
| **Container** | uma imagem **rodando**: processos isolados, com o próprio sistema de arquivos, usando o **kernel do servidor** |
| **Registro** | o "repositório de imagens" (`docker.io`, `quay.io`) |
| **Tag** | a versão da imagem (`nginx:1.31`); `latest` é só um nome que muda com o tempo |
| **Camadas** (*blobs*) | as partes de uma imagem; imagens com camadas iguais as compartilham |
| **Containerfile** | a receita de uma imagem (o mesmo formato do `Dockerfile`) |
| **Rootless** | containers rodando como usuário comum: quem escapar do container cai como esse usuário, não como root |
| **Volume** | uma pasta do servidor que aparece dentro do container |
| **Quadlet** | um arquivo `.container` que o systemd transforma num serviço |

---

## Enunciado

Hoje o site depende do Apache instalado e configurado à mão na `servidor1`. A equipe quer o site **empacotado**, para rodar igual em qualquer máquina com Podman.

### Objetivos

1. Instalar o Podman e rodar o primeiro container, sem root.
2. Rodar uma imagem pública do Nginx e acessá-la por uma porta da `servidor1`.
3. Escrever um Containerfile com a página do site numa imagem do Nginx.
4. Construir a imagem `site-equipe` e rodá-la.
5. Operar o container: `ps`, `logs`, `exec`, `stop`, `rm`, `images`.
6. Servir uma pasta da `servidor1` com um volume, resolvendo o SELinux.
7. Guardar no repositório e entregar por pull request.

**Bônus:** subir no boot como serviço do systemd (Quadlet).

---

## Passo a passo

### 1. Instalar e o primeiro container

```bash
sudo dnf install -y podman
podman --version
podman run --rm quay.io/podman/hello
podman info | grep -i rootless
```

```
podman version 5.8.2
Trying to pull quay.io/podman/hello:latest...
...
!... Hello Podman World ...!
...
  rootlessNetworkCmd: pasta
    rootless: true
```

| Parte | O que faz |
|---|---|
| `podman run` | baixa a imagem, se necessário, e cria um container |
| `--rm` | apaga o container quando ele termina |
| `quay.io/podman/hello` | registro `quay.io`, imagem `podman/hello` |
| `rootless: true` | os containers rodam como `alice_estudo` |

A instalação trouxe, entre outros, o `container-selinux` (regras do SELinux para containers), o `crun` (quem cria os containers), o `conmon` (vigia cada container) e o `passt` (a rede no modo rootless).

### 2. Uma imagem pública do Nginx

```bash
podman run -d --name teste-nginx -p 8090:80 docker.io/library/nginx:latest
podman ps
curl http://localhost:8090
```

```
CONTAINER ID  IMAGE                           COMMAND               CREATED        STATUS        PORTS                 NAMES
bd599caf2119  docker.io/library/nginx:latest  nginx -g daemon o...  6 seconds ago  Up 7 seconds  0.0.0.0:8090->80/tcp  teste-nginx

<title>Welcome to nginx!</title>
```

| Parte | O que faz |
|---|---|
| `-d` | em segundo plano |
| `--name` | nome para usar nos comandos seguintes |
| `-p 8090:80` | porta 8090 da `servidor1` → porta 80 do container |
| `docker.io/library/nginx:latest` | nome completo: o Podman não precisa perguntar de qual registro baixar |

A página vem de **outro** Nginx, completo, dentro do container, e não do Nginx do sistema.

### 3. Containerfile

```bash
cd ~/repos/devops
git switch -c container-site-equipe
mkdir -p containers/site-equipe
cd containers/site-equipe
cp /var/www/html/index.html .
vi Containerfile
```

```dockerfile
FROM docker.io/library/nginx:1.31
COPY index.html /usr/share/nginx/html/index.html
EXPOSE 80
```

| Linha | O que faz |
|---|---|
| `FROM` | a imagem base, com a versão **fixada** |
| `COPY` | coloca a página onde o Nginx da imagem procura o site |
| `EXPOSE 80` | documenta a porta; quem a liga ao servidor é o `-p` |

### 4. Construir e rodar

A primeira versão usou `nginx:1.27`:

```
$ podman build -t site-equipe:1.0 .
STEP 1/3: FROM docker.io/library/nginx:1.27
...
STEP 2/3: COPY index.html /usr/share/nginx/html/index.html
STEP 3/3: EXPOSE 80
Successfully tagged localhost/site-equipe:1.0

$ podman images
REPOSITORY               TAG         IMAGE ID      CREATED        SIZE
localhost/site-equipe    1.0         1b9df7fa56f7  6 seconds ago  197 MB
docker.io/library/nginx  latest      c05939e13a61  7 days ago     167 MB
docker.io/library/nginx  1.27        1e5f3c5b981a  19 months ago  197 MB
```

A `1.27` tinha **19 meses** sem atualização: uma versão fora de suporte, sem correções de segurança. **Fixar a versão é certo, mas ela precisa ser mantida.** Para ver a atual:

```
$ podman run --rm docker.io/library/nginx:latest nginx -v
/docker-entrypoint.sh: ... Configuration complete; ready for start up
nginx version: nginx/1.31.8
```

As linhas `/docker-entrypoint.sh` são o script de inicialização da imagem. Com `FROM docker.io/library/nginx:1.31` (sem o `.8`, para receber as correções da 1.31):

```
$ podman build -t site-equipe:1.1 .
STEP 1/3: FROM docker.io/library/nginx:1.31
Copying blob 7cb4701ce7cd skipped: already exists
...
Successfully tagged localhost/site-equipe:1.1

$ podman stop site-equipe
$ podman rm site-equipe
$ podman run -d --name site-equipe -p 8090:80 localhost/site-equipe:1.1
$ curl http://localhost:8090
Site da equipe

$ podman images
REPOSITORY               TAG         IMAGE ID      CREATED         SIZE
localhost/site-equipe    1.1         8ab8da98d5ba  21 seconds ago  167 MB
localhost/site-equipe    1.0         1b9df7fa56f7  18 minutes ago  197 MB
docker.io/library/nginx  1.31        c05939e13a61  7 days ago      167 MB
docker.io/library/nginx  latest      c05939e13a61  7 days ago      167 MB
```

- `skipped: already exists`: as camadas da 1.31 eram as mesmas da `latest` já baixada.
- `1.31` e `latest` com o **mesmo IMAGE ID**: a mesma imagem com dois nomes. Daqui a uns meses, a `latest` aponta para outra; a `1.31` continua a 1.31.
- Imagem mudou → tag nova (`1.1`). A `1.0` fica guardada para voltar, se preciso.
- `stop` para; `rm` apaga o **container** (a imagem fica). A porta 8090 só fica livre depois do `rm`.

### 5. Operar o container

| Comando | O que faz |
|---|---|
| `podman ps` / `podman ps -a` | rodando / todos, inclusive parados |
| `podman logs [--tail N]` | a saída do container (no Nginx, o log de acesso, no formato do [Desafio 3.3](../../fase-3-git-bash-python/desafio-03-texto-log-nginx/)) |
| `podman exec -it site-equipe bash` | um terminal **dentro** do container |
| `podman stop` / `start` | parar / religar o **mesmo** container |

**Dentro do container**, o `ps` não existe: a imagem leva só o necessário. Os processos aparecem em `/proc`:

```
root@a94ab6afdcea:/# ls /proc | grep '^[0-9]'
1
24
25
26
30
31
```

O processo **1** é o Nginx (o papel do systemd no servidor); se ele termina, o container para. Os outros: workers, o `bash` do `exec` e o próprio `ls`. A contagem recomeça do 1: isolamento de processos.

**Por fora:**

```
$ ps aux | grep "nginx: master"
root        1143  ...  nginx: master process /usr/sbin/nginx
alice_e+  763041  ...  nginx: master process nginx -g daemon off;

$ podman stop site-equipe
$ podman ps -a
CONTAINER ID  IMAGE                      ...  STATUS                     PORTS                 NAMES
a94ab6afdcea  localhost/site-equipe:1.1  ...  Exited (0) 21 seconds ago  0.0.0.0:8090->80/tcp  site-equipe
$ podman start site-equipe
$ curl http://localhost:8090
Site da equipe
```

- O Nginx do container é o PID 1 lá dentro e o **763041** aqui fora, com dono `alice_estudo` (rootless).
- `Exited (0)`: parou limpo.

### 6. Volume e SELinux

```bash
mkdir ~/site-volume
echo "Site da equipe (pelo volume)" > ~/site-volume/index.html
podman run -d --name site-volume -p 8091:80 -v ~/site-volume:/usr/share/nginx/html:ro docker.io/library/nginx:1.31
curl http://localhost:8091
```

| Parte | O que faz |
|---|---|
| `-v pasta_do_servidor:caminho_no_container` | a pasta aparece dentro do container, no lugar do que a imagem tinha ali |
| `:ro` | só leitura |

```
<title>403 Forbidden</title>

$ ls -lZ ~/site-volume
-rw-r--r--. 1 alice_estudo alice_estudo unconfined_u:object_r:user_home_t:s0 29 nov 12 11:50 index.html

$ podman logs --tail 3 site-volume
... "/usr/share/nginx/html/index.html" is forbidden (13: Permission denied) ...

$ sudo ausearch -m avc -ts recent | tail -5
<no matches>
```

- Permissão `-rw-r--r--` e mesmo assim `13`: o padrão do SELinux ([Desafio 1.3](../../fase-1-linux/desafio-03-selinux-apache/)). O processo do container é `container_t` e não pode ler `user_home_t`: um container não deve enxergar a home.
- **Sem AVC no `ausearch`:** a política tem regras **`dontaudit`**, negações que não são registradas para não encher o log. A pista veio do log do próprio programa.

**Correção com `:Z`:**

```
$ podman rm -f site-volume
$ podman run -d --name site-volume -p 8091:80 -v ~/site-volume:/usr/share/nginx/html:ro,Z docker.io/library/nginx:1.31
$ curl http://localhost:8091
Site da equipe (pelo volume)
$ ls -lZ ~/site-volume
-rw-r--r--. 1 alice_estudo alice_estudo system_u:object_r:container_file_t:s0:c114,c143 29 nov 12 11:50 index.html
```

| Opção | Efeito |
|---|---|
| `Z` | reetiqueta a pasta como `container_file_t` com as **categorias** deste container (`c114,c143`): só ele lê. Outro container, com outras categorias, também seria barrado |
| `z` | rótulo compartilhado entre containers |

> ⚠️ Nunca `:Z` em pastas do sistema (`/home`, `/etc`, `/var`): o Podman reetiquetaria tudo, e o resto do sistema deixaria de ler.

```
$ echo "Site da equipe (alterado sem reconstruir)" > ~/site-volume/index.html
$ curl http://localhost:8091
Site da equipe (alterado sem reconstruir)
```

| | `COPY` na imagem | Volume `-v` |
|---|---|---|
| Mudar o conteúdo | reconstruir | editar o arquivo |
| Levar para outro servidor | a imagem leva tudo | a pasta vai junto |
| Uso típico | o código da aplicação | dados: uploads, banco, configuração |

### 7. Bônus: Quadlet, o container como serviço

```bash
podman rm -f site-equipe
mkdir -p ~/.config/containers/systemd
vi ~/.config/containers/systemd/site-equipe.container
```

```ini
[Unit]
Description=Site da equipe em container

[Container]
Image=localhost/site-equipe:1.1
ContainerName=site-equipe
PublishPort=8090:80

[Service]
Restart=always

[Install]
WantedBy=default.target
```

| Linha | Equivale a |
|---|---|
| `[Container]` | vira um `podman run` |
| `Image=`, `ContainerName=`, `PublishPort=` | a imagem, o `--name`, o `-p` |
| `Restart=always` | se cair, sobe de novo |
| `WantedBy=default.target` | sobe com o systemd **do usuário** |

```bash
systemctl --user daemon-reload
systemctl --user start site-equipe.service
sudo loginctl enable-linger alice_estudo
```

| Parte | O que faz |
|---|---|
| `--user` | o systemd **do usuário**, sem `sudo` (o container é rootless) |
| `daemon-reload` | o Quadlet lê o `.container` e **gera** o `site-equipe.service` |
| `enable-linger` | mantém o systemd do usuário rodando desde o boot, sem login |

**Prova, depois de `sudo reboot`:**

```
$ uptime
 13:18:33 up 0 min,  2 users,  load average: 0,00, 0,00, 0,00
$ podman ps -a
CONTAINER ID  IMAGE                         ...  STATUS                         PORTS                 NAMES
1de6419d3b90  docker.io/library/nginx:1.31  ...  Exited (0) About a minute ago  0.0.0.0:8091->80/tcp  site-volume
8303cf30d026  localhost/site-equipe:1.1     ...  Up 20 seconds                  0.0.0.0:8090->80/tcp  site-equipe
$ systemctl --user status site-equipe.service
● site-equipe.service - Site da equipe em container
     Loaded: loaded (/home/alice_estudo/.config/containers/systemd/site-equipe.container; generated)
     Active: active (running) since Thu 2026-11-12 13:18:18 -03; 36s ago
   Main PID: 1232 (conmon)
     CGroup: /user.slice/user-1000.slice/user@1000.service/app.slice/site-equipe.service
             ├─libpod-payload-8303cf30d026...
             │ ├─1234 "nginx: master process nginx -g daemon off;"
             │ ├─1261 "nginx: worker process"
             │ └─1262 "nginx: worker process"
             └─runtime
               ├─1228 /usr/bin/pasta --config-net -t 8090-8090:80-80 ...
               └─1232 /usr/bin/conmon --api-version 1 -c 8303cf30d026...
nov 12 13:18:18 ... site-equipe[1232]: 2026/11/12 16:18:18 [notice] 1#1: nginx/1.31.8
nov 12 13:18:18 ... site-equipe[1232]: 2026/11/12 16:18:18 [notice] 1#1: OS: Linux 6.12.0-...
$ curl http://localhost:8090
Site da equipe
```

- O `site-equipe` (Quadlet) subiu sozinho no boot; o `site-volume` (manual) não voltou.
- `generated`: o serviço foi gerado do `.container`.
- `conmon`: o vigia do container; `pasta`: a ligação da porta 8090 com a 80 no modo rootless.
- `OS: Linux 6.12.0`: o Nginx do container (num Debian) informa o kernel **da `servidor1`**.

### 8. Limpeza e entrega

```
$ podman rm site-volume
$ podman rmi localhost/site-equipe:1.0 docker.io/library/nginx:1.27
Untagged: docker.io/library/nginx:1.27
Deleted: 1e5f3c5b981a...
Error: localhost/site-equipe:1.0: image not known
$ podman images
REPOSITORY               TAG         IMAGE ID      CREATED      SIZE
localhost/site-equipe    1.1         8ab8da98d5ba  2 hours ago  167 MB
docker.io/library/nginx  1.31        c05939e13a61  7 days ago   167 MB
docker.io/library/nginx  latest      c05939e13a61  7 days ago   167 MB
quay.io/podman/hello     latest      5dd467fce50b  2 years ago  787 kB
```

Em `containers/site-equipe/`: `Containerfile`, `index.html`, uma cópia do `site-equipe.container` e um `README.md` com os comandos. Pull request #19.

---

## Erros que aconteceram e como foram resolvidos

| Sintoma | Causa | Correção |
|---|---|---|
| `sudo` desabilitado neste computador | Comando do Linux digitado no PowerShell do Windows | `ssh servidor1` antes |
| `podman ru --rm ...` → `unknown flag: --rm` | Subcomando `run` digitado errado | `podman run` |
| `nginix:lastest` → `requested access to the resource is denied` | Nome e tag errados. O Docker Hub responde "acesso negado" para imagens que não existem | `nginx:latest` |
| `cp: falta o operando arquivo de destino` | Faltou o destino | `cp /var/www/html/index.html .` |
| `context must be a directory: ".../0"` | `0` no lugar do `.` no `podman build` | `podman build -t ... .` |
| `nginx:1.27` com 19 meses | Versão fora de suporte | Ver a atual com `nginx -v` na `latest` e fixar `1.31` |
| `FROM: comando não encontrado` | Linha do Containerfile digitada no terminal | Editar o `Containerfile` no `vi` |
| `ps: command not found` dentro do container | A imagem é enxuta | Ler os processos em `/proc` |
| `403` no volume, primeiro com a pasta vazia | O `index.html` não tinha sido criado | Criar o arquivo |
| `403` com `(13: Permission denied)` e nenhum AVC | SELinux: `container_t` não lê `user_home_t`; a negação é `dontaudit` | `-v ...:ro,Z` |
| `logicnctl: comando não encontrado` | Digitação | `loginctl` |
| `Unit site-equipe.service:8090.service could not be found` | `:8090` virou parte do nome da unidade | `systemctl --user status site-equipe.service` |

---

## Resumo

- Imagem = pacote; container = imagem rodando, com processos e sistema de arquivos isolados e o **kernel do servidor**.
- `podman run -d --name -p` / `ps -a` / `logs` / `exec -it` / `stop` / `start` / `rm` / `images` / `rmi`.
- Containerfile: `FROM` com versão **fixada e mantida**, `COPY`, `EXPOSE`; `podman build -t nome:tag .`; tag nova a cada mudança.
- Rootless: os processos do container pertencem ao usuário comum.
- Volume com SELinux: `:Z` (privado) ou `:z` (compartilhado), nunca em pastas do sistema. Negações de container podem não aparecer no `ausearch` (`dontaudit`): olhar o log do programa.
- Quadlet: um `.container` em `~/.config/containers/systemd/`, `systemctl --user daemon-reload`, e `loginctl enable-linger` para subir no boot.
