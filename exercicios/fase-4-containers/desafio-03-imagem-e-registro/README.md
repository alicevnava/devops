# Desafio 4.3 — Imagens melhores e registro

Terceiro desafio da Fase 4 (Containers) da trilha de estudos: medir a imagem da `app-equipe`, reduzi-la trocando a base, acrescentar rótulos e um **healthcheck**, publicá-la no **GitHub Container Registry** e rodá-la na `servidor2`, que nunca construiu nada.

**Imagem:** [`ghcr.io/alicevnava/app-equipe`](https://github.com/users/alicevnava/packages/container/package/app-equipe) · **Arquivos:** [`containers/app-equipe/`](../../../containers/app-equipe/)

**Método:** medir antes de mudar; provar o healthcheck nos dois sentidos (`healthy` e `unhealthy`); testar a imagem publicada numa máquina limpa.

---

## Ambiente

| Item | Valor |
|---|---|
| **Construção** | `servidor1`, Podman 5.8.2 rootless, imagem `app-equipe` do [Desafio 4.2](../desafio-02-app-proxy-compose/) |
| **Registro** | `ghcr.io` (GitHub Container Registry), token *classic* com `write:packages` |
| **Teste** | `servidor2` ([Desafio 2.5](../../fase-2-redes/desafio-05-bastion-ssh/)), acessada com `ssh servidor2` pelo bastion |

---

## Conceitos

| Termo | Significa |
|---|---|
| **Camada** | cada instrução do Containerfile que muda arquivos gera uma camada; `podman history` lista todas |
| **Base `slim` / `alpine`** | Debian reduzido / Alpine Linux, feito para containers (BusyBox + `musl`) |
| **Rótulo** (`LABEL`) | metadado gravado na imagem; `org.opencontainers.image.*` é o padrão |
| **Healthcheck** | comando que o Podman roda dentro do container para saber se a aplicação responde |
| **Formato OCI / docker** | dois formatos de imagem; só o `docker` guarda o `HEALTHCHECK` |
| **Registro** | servidor de imagens (`docker.io`, `quay.io`, `ghcr.io`) |

---

## Enunciado

A imagem só existe na `servidor1`. Para rodar em outro servidor, ela precisa estar num registro; antes, a equipe quer uma imagem menor e que informe sozinha se está saudável.

### Objetivos

1. Medir a imagem atual (`podman history`).
2. Trocar a base por uma menor e comparar.
3. Acrescentar rótulos com origem e versão.
4. Acrescentar um healthcheck; ver `healthy` e `unhealthy`.
5. Publicar no `ghcr.io`.
6. Baixar e rodar na `servidor2`.
7. Entregar por pull request.

---

## Passo a passo

### 1. Medir

```
$ podman images | grep -E "REPOSITORY|app-equipe|python"
REPOSITORY                TAG         IMAGE ID      CREATED       SIZE
localhost/app-equipe      1.0         b70ff0782828  3 hours ago   124 MB
docker.io/library/python  3.12-slim   d497f3e5689c  11 hours ago  124 MB

$ podman history localhost/app-equipe:1.0
ID            CREATED       CREATED BY                                     SIZE
d89e56a14ada  3 hours ago   /bin/sh -c #(nop) CMD ["python3", "app.py"]    0B
<missing>     3 hours ago   /bin/sh -c #(nop) EXPOSE 5000                  0B
<missing>     3 hours ago   /bin/sh -c #(nop) USER 1001                    0B
<missing>     3 hours ago   /bin/sh -c #(nop) COPY file:ecdf01eeb9579f...  3.07kB
d497f3e5689c  3 hours ago   /bin/sh -c #(nop) WORKDIR /app                 0B
...
<missing>     11 hours ago  RUN /bin/sh -c set -eux; savedAptMark="$...    38.2MB
<missing>     11 hours ago  ENV PYTHON_VERSION=3.12.16                     0B
<missing>     11 hours ago  RUN /bin/sh -c set -eux; apt-get update; ...   4.12MB
<missing>     40 hours ago  # debian.sh --arch 'amd64' out/ 'trixie' '...  81.3MB
```

| Camada | Tamanho | O que é |
|---|---|---|
| `COPY` | 3.07kB | o `app.py` |
| `CMD`, `EXPOSE`, `USER`, `WORKDIR`, `ENV` | 0B | só metadados |
| `savedAptMark` | 38.2MB | o Python 3.12.16 |
| `apt-get update` | 4.12MB | pacotes do Debian para o Python |
| `debian.sh ... 'trixie'` | 81.3MB | o Debian 13 |

O código é 3 kB de 124 MB: para diminuir, é preciso trocar a **base**. `<missing>` = camadas construídas em outra máquina (a da imagem oficial); os IDs intermediários não vêm no download.

### 2. Base menor

```dockerfile
FROM docker.io/library/python:3.12-alpine
```

```
$ podman build -t app-equipe:1.1 app
$ podman images | grep -E "REPOSITORY|app-equipe|python"
REPOSITORY                TAG          IMAGE ID      CREATED        SIZE
localhost/app-equipe      1.1          5c4211c6c7f9  3 seconds ago  51.2 MB
localhost/app-equipe      1.0          b70ff0782828  3 hours ago    124 MB
docker.io/library/python  3.12-slim    d497f3e5689c  11 hours ago   124 MB
docker.io/library/python  3.12-alpine  4076016aea54  2 weeks ago    51.2 MB

$ curl -s http://127.0.0.1:5000/ ; echo
{"servico": "app-equipe", "container": "4d0eaaf8a9b6", "hora": "2026-11-24T16:32:52", "caminho": "/"}
$ podman exec app-teste cat /etc/os-release
NAME="Alpine Linux"
VERSION_ID=3.24.4
```

- 124 MB → **51,2 MB** (−59%), sem mudar o código (a aplicação usa só a biblioteca padrão do Python).
- A Alpine usa `musl` no lugar da `glibc`; bibliotecas Python com código em C às vezes dão trabalho nela, e por isso a `slim` continua comum.
- `"hora"` 3 h adiantada: o container está em **UTC**.

### 3 e 4. Rótulos e healthcheck

```dockerfile
FROM docker.io/library/python:3.12-alpine

LABEL org.opencontainers.image.source="https://github.com/alicevnava/devops" \
      org.opencontainers.image.description="Aplicação de exemplo em Python que responde em JSON" \
      org.opencontainers.image.version="1.2"

WORKDIR /app
COPY app.py .
USER 1001
EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD wget -q -O /dev/null http://127.0.0.1:5000/ || exit 1

CMD ["python3", "app.py"]
```

| Trecho | O que faz |
|---|---|
| `LABEL ...source=` | liga a imagem ao repositório no GitHub |
| `HEALTHCHECK ... CMD wget ...` | pede a página dentro do container (`wget` do BusyBox); falha → `exit 1` |
| `--interval=30s --timeout=3s --retries=3` | a cada 30 s; 3 s de limite; `unhealthy` só após 3 falhas seguidas |

```
$ podman build --format docker -t app-equipe:1.2 app
$ podman image inspect localhost/app-equipe:1.2 --format '{{json .Config.Healthcheck}}'
{"Test":["CMD-SHELL","wget -q -O /dev/null http://127.0.0.1:5000/ || exit 1"],"Interval":30000000000,"Timeout":3000000000,"Retries":3}
```

- `--format docker`: no formato OCI (o padrão do Podman), não existe o campo do `HEALTHCHECK`, e a instrução seria ignorada.
- `CMD-SHELL`: o comando foi escrito como texto, então roda num shell (que entende o `||`).
- Tempos em nanossegundos: `30000000000` = 30 s.

**`starting` → `healthy`:**

```
$ podman run -d --name app-teste -p 5000:5000 localhost/app-equipe:1.2
$ podman ps
... localhost/app-equipe:1.2   python3 app.py   8 seconds ago   Up 8 seconds (starting)   ...
$ podman healthcheck run app-teste
$ echo $?
0
$ podman ps
... localhost/app-equipe:1.2   python3 app.py   31 seconds ago  Up 30 seconds (healthy)   ...
```

**`unhealthy`: aplicação congelada com SIGSTOP** ([Desafio 1.4](../../fase-1-linux/desafio-04-processos-sinais/)):

```
$ podman inspect app-teste --format '{{.State.Pid}}'
855732
$ kill -STOP 855732
$ podman healthcheck run app-teste ; echo $?
Error: healthcheck command exceeded timeout of 3s
125
(3 vezes)
$ podman ps
... Up 8 minutes (unhealthy) ...
$ kill -CONT 855732
$ podman healthcheck run app-teste ; echo $?
0
$ podman ps
... Up 9 minutes (healthy) ...
```

- O PID é o do lado de fora (lá dentro é 1). O SIGSTOP precisa vir de fora: de dentro, o kernel protegeria o PID 1.
- `125` é o código do próprio Podman (o tempo esgotou); uma falha do `wget` seria `1`. Os dois contam como falha.
- **"Rodando" não é "funcionando":** o container continuou `Up`; só o healthcheck percebeu. No Kubernetes, a mesma ideia é a *probe*, e o container é reiniciado sozinho.

### 5. Publicar no `ghcr.io`

Token **classic** (os *fine-grained* não funcionam com o registro de containers): GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic), escopo `write:packages`, validade de 7 dias.

```
$ podman login ghcr.io -u alicevnava
Password:
Login Succeeded!
$ podman tag localhost/app-equipe:1.2 ghcr.io/alicevnava/app-equipe:1.2
$ podman images | grep app-equipe
localhost/app-equipe           1.2   09f24638ad4a  14 minutes ago  51.2 MB
ghcr.io/alicevnava/app-equipe  1.2   09f24638ad4a  14 minutes ago  51.2 MB
$ podman push ghcr.io/alicevnava/app-equipe:1.2
Copying blob 217819145e0f done
...
Writing manifest to image destination
$ podman logout ghcr.io
Removed login credentials for ghcr.io
```

| Parte | O que faz |
|---|---|
| `podman login` | a senha é o token; a credencial fica em `/run/user/1000/containers/auth.json`, apagado no reboot |
| `podman tag` | segundo nome para a mesma imagem (mesmo IMAGE ID): `registro/dono/imagem:tag` |
| `podman push` | envia as camadas |

No GitHub, o pacote apareceu **ligado ao repositório `devops`** (Package settings → Manage Actions access: `devops`, papel Admin), por causa do `LABEL ...source`. O pacote nasce **privado**; foi tornado **público** em Package settings → Danger Zone → Change visibility.

Prova, sem login:

```
$ podman rmi ghcr.io/alicevnava/app-equipe:1.2
Untagged: ghcr.io/alicevnava/app-equipe:1.2
$ podman pull ghcr.io/alicevnava/app-equipe:1.2
Copying blob f829fc669ce2 skipped: already exists
...
Writing manifest to image destination
```

### 6. Na `servidor2`

```
PS> ssh servidor2
[a_servidor2@servidor2 ~]$ sudo dnf install -y podman
[a_servidor2@servidor2 ~]$ podman run -d --name app -p 5000:5000 ghcr.io/alicevnava/app-equipe:1.2
[a_servidor2@servidor2 ~]$ podman images
REPOSITORY                     TAG   IMAGE ID      CREATED         SIZE
ghcr.io/alicevnava/app-equipe  1.2   09f24638ad4a  42 minutes ago  51.2 MB
[a_servidor2@servidor2 ~]$ podman ps
CONTAINER ID  IMAGE                              ...  STATUS                   PORTS                   NAMES
0b84fb142507  ghcr.io/alicevnava/app-equipe:1.2  ...  Up 17 minutes (healthy)  0.0.0.0:5000->5000/tcp  app
[a_servidor2@servidor2 ~]$ curl -s http://127.0.0.1:5000/ ; echo
{"servico": "app-equipe", "container": "0b84fb142507", "hora": "2026-11-24T17:38:17", "caminho": "/"}
[a_servidor2@servidor2 ~]$ podman healthcheck run app ; echo $?
0
```

A `servidor2` nunca viu o código, o Containerfile ou a base: só o Podman e o nome da imagem. O mesmo IMAGE ID nas duas máquinas, e o healthcheck veio dentro da imagem (o Podman já o rodava sozinho).

### 7. Compose com a imagem publicada

No `compose.yaml`, `app1` e `app2` passaram a usar `image: ghcr.io/alicevnava/app-equipe:1.2`, sem `build:`:

```
$ podman-compose ps
CONTAINER ID  IMAGE                              ...  STATUS                  ...  NAMES
14806d722e31  ghcr.io/alicevnava/app-equipe:1.2  ...  Up 1 second (starting)  ...  app-equipe_app1_1
3923f6965031  ghcr.io/alicevnava/app-equipe:1.2  ...  Up 1 second (starting)  ...  app-equipe_app2_1
88c8b4b887fd  docker.io/library/nginx:1.31       ...  Up Less than a second   ...  app-equipe_proxy_1
```

O `proxy` não tem `(starting)`: a imagem do Nginx não traz healthcheck. Entrega: PR #25.

---

## Erros que aconteceram e como foram resolvidos

| Sintoma | Causa | Correção |
|---|---|---|
| `kill -STOP <855732>` → erro de sintaxe | `<` e `>` eram só marcação; no Bash são redirecionamentos | `kill -STOP 855732` |
| `unrecognized command 'podman healtcheck'` | Digitação | `healthcheck` |
| Sem acesso à `servidor2` pelo MobaXterm (`timed out`) | SSH só pelo bastion (Desafio 2.5) | `ssh servidor2` no PowerShell |
| `ssh servidor2` dentro da `servidor2` → `Broken pipe`; `ssh servidor1` dentro da `servidor1` → `Permission denied` | Tentativa de conectar na própria máquina | Conferir o prompt: o `ssh` é feito a partir do Windows |
| `container name "app" is already in use` | O primeiro `run` já tinha criado o container | Seguir com ele |
| Documentação do 4.2 apagada (PR #24) | O botão **Revert** da página do PR #23 foi usado, e o PR de reversão aceito | Reverter o revert (`git revert 06c8959`), PR #26. Na página de um PR aceito, só o **Delete branch** |

---

## Resumo

- `podman history` mostra de onde vem o tamanho: quase sempre da base. Alpine: imagem bem menor, com a ressalva da `musl`.
- `LABEL org.opencontainers.image.source` liga a imagem ao repositório.
- `HEALTHCHECK` + `podman build --format docker`; `podman healthcheck run`; `starting` → `healthy` / `unhealthy` (3 falhas). "Up" não é "funcionando".
- Publicar: token classic `write:packages`, `podman login`, `podman tag registro/dono/imagem:tag`, `podman push`, `podman logout`. Pacote nasce privado.
- Uma imagem publicada roda em qualquer máquina com Podman, igual.
