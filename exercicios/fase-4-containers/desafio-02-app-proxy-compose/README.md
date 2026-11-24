# Desafio 4.2 — Dois containers numa rede, depois com Compose

Segundo desafio da Fase 4 (Containers) da trilha de estudos: uma aplicação em Python num container, atrás de um Nginx em outro, conversando por uma **rede** do Podman pelo **nome do container**. Primeiro à mão, depois descrito num arquivo **Compose**, e por fim com duas cópias da aplicação.

**Arquivos:** [`containers/app-equipe/`](../../../containers/app-equipe/) (`app/app.py`, `app/Containerfile`, `proxy/default.conf`, `compose.yaml`)

**Método:** testar a aplicação sozinha antes de juntar as peças; diante de cada falha, olhar `podman ps -a` e `podman logs`.

---

## Ambiente

| Item | Valor |
|---|---|
| **Servidor** | `servidor1` (Rocky Linux 10.2), usuário `alice_estudo` |
| **Podman** | 5.8.2, rootless ([Desafio 4.1](../desafio-01-site-em-container/)) |
| **Compose** | `podman-compose`, instalado com `pip3 install --user` |

```
curl ──► :8092 ──► [ proxy: Nginx ] ──rede "equipe"──► [ app: Python :5000 ]
                      (exposto)                          (sem porta exposta)
```

É a arquitetura do [Desafio 2.2](../../fase-2-redes/desafio-02-proxy-reverso-nginx/), com cada peça num container.

---

## Enunciado

### Objetivos

1. Escrever a aplicação em Python e a imagem dela (`app-equipe`).
2. Criar uma rede do Podman e rodar a aplicação nela, sem publicar porta.
3. Rodar o Nginx na mesma rede, como proxy reverso, chamando a aplicação pelo nome do container.
4. Provar que a aplicação só é acessível pelo proxy.
5. Descrever os dois containers num `compose.yaml` e subir tudo com `podman-compose`.
6. Entregar por pull request.

**Bônus:** duas cópias da aplicação atrás do proxy.

---

## Passo a passo

### 1. A aplicação

`app/app.py`:

```python
"""Aplicação de exemplo: responde em JSON com o nome do container."""

import json
import signal
import socket
import sys
from datetime import datetime
from http.server import BaseHTTPRequestHandler, HTTPServer


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        resposta = {
            "servico": "app-equipe",
            "container": socket.gethostname(),
            "hora": datetime.now().isoformat(timespec="seconds"),
            "caminho": self.path,
        }
        corpo = json.dumps(resposta).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(corpo)


def encerrar(sinal, quadro):
    sys.exit(0)


signal.signal(signal.SIGTERM, encerrar)

HTTPServer(("0.0.0.0", 5000), Handler).serve_forever()
```

| Trecho | O que faz |
|---|---|
| `Handler.do_GET` | responde a cada `GET` |
| `socket.gethostname()` | dentro de um container, é o **ID do container**: mostra qual respondeu |
| `("0.0.0.0", 5000)` | todas as interfaces IPv4 do container, porta 5000. Com `127.0.0.1`, nenhum outro container falaria com ela |
| `signal.signal(signal.SIGTERM, encerrar)` | trata o SIGTERM (ver passo 2) |

`app/Containerfile`:

```dockerfile
FROM docker.io/library/python:3.12-slim
WORKDIR /app
COPY app.py .
USER 1001
EXPOSE 5000
CMD ["python3", "app.py"]
```

| Linha | O que faz |
|---|---|
| `python:3.12-slim` | Python 3.12 numa imagem reduzida |
| `WORKDIR /app` | pasta de trabalho dentro da imagem |
| `USER 1001` | a aplicação roda como usuário comum **dentro** do container |
| `CMD [...]` | o comando que vira o PID 1 |

```bash
cd ~/repos/devops
git switch -c app-equipe
mkdir -p containers/app-equipe/app containers/app-equipe/proxy
cd containers/app-equipe
podman build -t app-equipe:1.0 app
```

`podman build ... app`: o contexto é a pasta `app`.

### 2. Testar a aplicação sozinha: três problemas

**a) O `app.py` com o conteúdo do Containerfile.**

```
$ podman run -d --name app-teste -p 5000:5000 localhost/app-equipe:1.0
$ curl http://localhost:5000/teste
curl: (7) Failed to connect to localhost port 5000 after 0 ms: Could not connect to server
$ podman ps -a
... localhost/app-equipe:1.0   python3 app.py   5 seconds ago   Exited (1) 5 seconds ago   ...   app-teste
$ podman logs app-teste
  File "/app/app.py", line 1
    FROM docker.io/library/python:3.12-slim
         ^^^^^^
SyntaxError: invalid syntax
```

A aplicação caiu ao iniciar e o container parou junto (ela é o PID 1). O texto do Containerfile tinha sido colado no `app.py`. Antes de construir, a sintaxe pode ser conferida sem rodar:

```
$ python3 -m py_compile app/app.py && echo "sintaxe ok"
sintaxe ok
```

**b) `Recv failure` pelo `localhost`: IPv6.**

```
$ curl http://localhost:5000/teste
curl: (56) Recv failure: Conexão fechada pela outra ponta
$ curl http://127.0.0.1:5000/teste
{"servico": "app-equipe", "container": "7382d188ea70", "hora": "2026-11-24T13:06:49", "caminho": "/teste"}
```

`localhost` aponta para `::1` (IPv6) e `127.0.0.1`; o `curl` tenta o IPv6 primeiro. O Podman repassa a conexão IPv6 para dentro do container, e a aplicação escuta só em IPv4 (`0.0.0.0`): a conexão é derrubada. O Nginx do 4.1 escuta nos dois, por isso não teve o problema. Pelo proxy (passo 3), também não importa: o Nginx fala com a aplicação pela rede, em IPv4.

**c) O SIGTERM ignorado pelo PID 1.**

```
$ time podman stop app-teste
WARN[0010] StopSignal SIGTERM failed to stop container app-teste in 10 seconds, resorting to SIGKILL
real    0m10,071s
$ podman ps -a | grep app-teste
... Exited (137) 4 seconds ago ...
```

- O `stop` manda **SIGTERM**; sem resposta em 10 s, **SIGKILL**.
- `137 = 128 + 9`: morto pelo sinal 9 (SIGKILL).
- O kernel só entrega um sinal ao **PID 1** de um container se o programa tiver dito explicitamente o que fazer com ele. O Python não trata o SIGTERM sozinho.

Correção no `app.py`: a função `encerrar` e o `signal.signal(...)`. Na primeira tentativa, a linha do `signal.signal` ficou **recuada**, dentro da função, depois do `sys.exit`: válida para o Python, mas nunca executada. Ela precisa estar no nível principal e **antes** do `serve_forever()`, que nunca termina.

```
$ time podman stop app-teste
app-teste
real    0m0,078s
$ podman ps -a | grep app-teste
... Exited (0) 4 seconds ago ...
```

> Num dos testes, o `podman run` falhou com `the container name "app-teste" is already in use`, e o `curl` e o `stop` acabaram falando com o container **antigo** (o mesmo `"container"` no JSON). Conferir o ID na resposta evita essa confusão.

### 3. A rede e os dois containers, à mão

```
$ podman network create equipe
$ podman network ls
NETWORK ID    NAME        DRIVER
ca2f898f18eb  equipe      bridge
2f259bab93aa  podman      bridge
$ podman run -d --name app --network equipe localhost/app-equipe:1.0
```

- Rede `bridge`: uma "ponte" virtual que liga os containers dela, como um switch. Nela, o DNS do Podman (`aardvark-dns`) resolve o nome de cada container.
- **Sem `-p`**: só quem está na rede `equipe` alcança a aplicação.

`proxy/default.conf`:

```nginx
server {
    listen 80;
    server_tokens off;

    location / {
        proxy_pass http://app:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

O `proxy_pass` usa o **nome do container**, não um IP.

```bash
podman run -d --name proxy \
  --network equipe \
  -p 8092:80 \
  -v ./proxy/default.conf:/etc/nginx/conf.d/default.conf:ro,Z \
  docker.io/library/nginx:1.31
```

- `-v arquivo:arquivo`: um volume de um arquivo só, que substitui a configuração padrão da imagem.
- A `\` no fim da linha continua o comando na linha seguinte (precisa ser o último caractere).

### 4. Provas

```
$ podman ps
CONTAINER ID  IMAGE                         ...  PORTS                 NAMES
dc6b0ebeb386  localhost/app-equipe:1.0      ...  5000/tcp              app
a879b7772095  docker.io/library/nginx:1.31  ...  0.0.0.0:8092->80/tcp  proxy

$ curl http://localhost:8092/teste
{"servico": "app-equipe", "container": "dc6b0ebeb386", "hora": "2026-11-24T13:28:47", "caminho": "/teste"}

$ curl http://127.0.0.1:5000
curl: (7) Failed to connect to 127.0.0.1 port 5000 after 0 ms: Could not connect to server

$ podman exec proxy getent hosts app
10.89.0.2       app.dns.podman
```

| Prova | O que mostra |
|---|---|
| `5000/tcp` sem `0.0.0.0:` | porta só declarada (`EXPOSE`), não publicada |
| JSON pela 8092 com `dc6b0ebeb386` | o pedido passou pelo proxy e chegou ao `app` |
| 5000 recusada | a aplicação não é acessível direto |
| `getent hosts app` | o DNS da rede resolve `app` → `10.89.0.2` (`app.dns.podman`) |

### 5. Compose

```bash
podman rm -f app proxy
podman network rm equipe
sudo dnf install -y python3-pip
pip3 install --user podman-compose
```

`compose.yaml` (primeira versão):

```yaml
services:
  app:
    build: ./app
    image: localhost/app-equipe:1.0
    networks:
      - equipe

  proxy:
    image: docker.io/library/nginx:1.31
    ports:
      - "8092:80"
    volumes:
      - ./proxy/default.conf:/etc/nginx/conf.d/default.conf:ro,Z
    networks:
      - equipe
    depends_on:
      - app

networks:
  equipe:
```

| Chave | Equivale a |
|---|---|
| `services:` | os containers; o nome de cada um vira o nome no DNS |
| `build:` / `image:` | `podman build` / a imagem |
| `ports:` / `volumes:` / `networks:` | `-p` / `-v` / `--network` |
| `depends_on:` | ordem de subida |
| `networks: equipe:` | cria a rede |

```
$ podman-compose up -d
...
app-equipe_app_1
app-equipe_proxy_1
$ podman-compose ps
CONTAINER ID  IMAGE                         ...  PORTS                 NAMES
2ff28daebfcd  localhost/app-equipe:1.0      ...  5000/tcp              app-equipe_app_1
08feeb9620ae  docker.io/library/nginx:1.31  ...  0.0.0.0:8092->80/tcp  app-equipe_proxy_1
$ curl http://localhost:8092/teste
{"servico": "app-equipe", "container": "2ff28daebfcd", "hora": "2026-11-24T13:33:04", "caminho": "/teste"}
$ podman-compose logs app
[app] | 10.89.0.3 - - [24/Nov/2026 13:33:04] "GET /teste HTTP/1.1" 200 -
$ podman-compose down
app-equipe_app_1
app-equipe_proxy_1
...
app-equipe_equipe
```

- O nome da **pasta** (`app-equipe`) vira o nome do projeto: `app-equipe_app_1`, rede `app-equipe_equipe`.
- No log da aplicação, quem pediu foi `10.89.0.3`: o **proxy**.
- `down` apaga containers e rede; as imagens ficam.

### 6. Bônus: duas cópias

```yaml
services:
  app1:
    build: ./app
    image: localhost/app-equipe:1.0
    networks:
      equipe:
        aliases:
          - app

  app2:
    image: localhost/app-equipe:1.0
    networks:
      equipe:
        aliases:
          - app

  proxy:
    image: docker.io/library/nginx:1.31
    ports:
      - "8092:80"
    volumes:
      - ./proxy/default.conf:/etc/nginx/conf.d/default.conf:ro,Z
    networks:
      - equipe
    depends_on:
      - app1
      - app2

networks:
  equipe:
```

`aliases: - app`: os dois containers também atendem pelo nome `app`. A configuração do Nginx não muda.

```
$ podman exec app-equipe_proxy_1 getent ahosts app
10.89.0.2       STREAM app.dns.podman
10.89.0.2       DGRAM
10.89.0.2       RAW
10.89.0.3       STREAM
10.89.0.3       DGRAM
10.89.0.3       RAW
$ curl -s http://localhost:8092/ ; echo
{"servico": "app-equipe", "container": "6edfdcaf57be", ...}
{"servico": "app-equipe", "container": "6edfdcaf57be", ...}
{"servico": "app-equipe", "container": "77ad4c3c1f5a", ...}
{"servico": "app-equipe", "container": "6edfdcaf57be", ...}
```

- `getent ahosts`: todos os IPs de um nome; cada IP aparece três vezes (TCP, UDP e acesso direto).
- O Nginx recebeu os dois IPs e faz round-robin. A alternância não é perfeita (2 workers, como no [Desafio 2.4](../../fase-2-redes/desafio-04-balanceamento/)).
- Limitação: o Nginx consulta o DNS só ao iniciar. Se um container for recriado com outro IP, o proxy precisa ser reiniciado. No Kubernetes, o **Service** resolve isso.

### 7. Entrega

PR #21 (`containers/app-equipe/`). Com o `git add` da pasta inteira, foi junto o `app/__pycache__/app.cpython-312.pyc`: o código compilado que o Python gera sozinho (aqui, criado pelo `py_compile`). Corrigido no PR #22:

```bash
git rm -r containers/app-equipe/app/__pycache__
vi .gitignore
```

```
# Python: código compilado, gerado automaticamente
__pycache__/
*.pyc
```

```
$ python3 -m py_compile containers/app-equipe/app/app.py
$ ls containers/app-equipe/app
app.py  Containerfile  __pycache__
$ git status
On branch gitignore-python
Changes to be committed:
        deleted:    containers/app-equipe/app/__pycache__/app.cpython-312.pyc
Untracked files:
        .gitignore
```

O `__pycache__` recriado não aparece no `git status`: o Git o ignora. `git rm` apaga **e** registra a remoção.

---

## Erros que aconteceram e como foram resolvidos

| Sintoma | Causa | Correção |
|---|---|---|
| Sem acesso à `servidor2` pelo MobaXterm (`timed out`) | Desafio 2.5: SSH só pelo bastion | `ssh servidor2` no PowerShell, ou SSH gateway no MobaXterm (e o 4.2 é na `servidor1`) |
| `no Containerfile or Dockerfile ... found in context directory` | O Containerfile ainda não existia na pasta `app` | Criar `app/Containerfile` |
| `Exited (1)` e `SyntaxError` na linha `FROM ...` | O conteúdo do Containerfile foi colado no `app.py` | Reescrever o `app.py`; conferir com `py_compile` |
| `Recv failure: Conexão fechada pela outra ponta` | `localhost` → IPv6; a aplicação escuta só em IPv4 | `127.0.0.1` no teste direto |
| `SIGTERM failed ... resorting to SIGKILL`, `Exited (137)` | PID 1 sem tratamento do SIGTERM | `signal.signal(signal.SIGTERM, encerrar)` |
| SIGKILL mesmo depois da correção | A linha do `signal.signal` estava recuada, dentro da função | Nível principal, antes do `serve_forever()` |
| `the container name ... is already in use` | Container com o mesmo nome ainda existia | `podman rm -f` antes |
| `flag needs an argument: 'v' in -v` | Comando longo copiado pela metade | Quebrar em linhas com `\` |
| Só uma cópia no bônus | O arquivo editado foi `comppose,yaml` | Apagar o errado (`rm 'comppose,yaml'`) e editar o `compose.yaml` |
| `.pyc` no repositório | `git add` da pasta inteira | `git rm -r` + `.gitignore` |
| `git push` recusado (`non-fast-forward`) na `gitignore-python` | A correção já tinha sido enviada antes; a branch local foi recriada com outro commit | `git branch -D` a local e abrir o PR da branch remota |

---

## Resumo

- Rede do Podman (`podman network create`): os containers se acham pelo **nome**; `getent hosts`/`ahosts` mostra o IP.
- Só o proxy publica porta; a aplicação fica acessível apenas pela rede.
- Diagnóstico: `podman ps -a` (`Exited (1)` = caiu; `137` = SIGKILL) e `podman logs`.
- PID 1 precisa tratar o SIGTERM para parar na hora.
- `0.0.0.0` é só IPv4; `localhost` pode ir por IPv6.
- Compose: `services`, `build`, `image`, `ports`, `volumes`, `networks`, `depends_on`; `podman-compose up -d` / `ps` / `logs` / `down`.
- `aliases` dá o mesmo nome a várias cópias; o DNS devolve todos os IPs.
- `.gitignore` para o que é gerado automaticamente; `git status` antes de todo commit.
