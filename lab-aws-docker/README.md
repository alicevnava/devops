# Laboratório AWS com Docker

Empacotar uma aplicação de três camadas em containers Docker e orquestrar tudo com Docker Compose numa instância EC2 (Ubuntu).

**Tarefa:** o `compose.yml` inicial sobe **apenas o banco**, de propósito. É preciso:

1. Criar os **Dockerfiles** do backend e do frontend (empacotar cada um em uma imagem).
2. Adicionar os dois serviços ao **Compose**, para que os containers se encontrem pelo nome do serviço (`db`, `backend`).
3. Expor **somente a porta 80** do frontend. Banco e backend ficam acessíveis só dentro da rede do Docker (reduz a superfície de ataque).

---

## Conceitos

| Termo | O que é |
|---|---|
| **Dockerfile** | Arquivo com as instruções para montar uma imagem automaticamente. |
| **Imagem** | "Molde" de um ambiente. A partir dela se iniciam containers. |
| **Container** | Uma imagem em execução, onde a aplicação roda. |
| **Docker Compose** | Define e roda vários containers juntos, a partir de um arquivo `.yml`. |
| **.yml** | Arquivo de configuração em texto, organizado por indentação (espaços). |

## Arquitetura

```
Navegador ──:80──> frontend (Nginx) ──/api──> backend (Node.js :3000) ──> db (PostgreSQL :5432)
```

## Estrutura do projeto

```
aws-docker/
├── backend/
│   ├── Dockerfile        <- criado neste lab
│   ├── package.json
│   └── server.js
├── database/
│   └── init.sql
├── frontend/
│   ├── Dockerfile        <- criado neste lab
│   ├── index.html
│   └── nginx.conf
├── instance.env
└── compose.yml           <- completado neste lab
```

Nesta pasta do GitHub estão os arquivos **finais** criados no lab (`backend/Dockerfile`, `frontend/Dockerfile` e `compose.yml`). Os demais arquivos (`server.js`, `package.json`, `init.sql`, `index.html`, `nginx.conf`) foram fornecidos prontos na instância.

---

## Pré-requisitos

- Instância EC2 com Ubuntu 24.04 (noble) e a pasta `~/aws-docker` com os arquivos do projeto.
- Chave privada SSH (`.pem`) da instância.
- Security Group liberando as portas **22** (SSH) e **80** (HTTP).

> ⚠️ A chave `.pem` **nunca** deve ser enviada para o GitHub.

Nos comandos abaixo, troque `<IP_DA_INSTANCIA>` pelo IP público da sua instância.

---

## Parte 1 — Conhecer o ambiente

### 1.1 Conectar via SSH

```bash
ssh -i lab.pem ubuntu@<IP_DA_INSTANCIA>
```
**Esperado:** prompt `ubuntu@ip-...:~$`.

### 1.2 Entrar na pasta do projeto

```bash
cd ~/aws-docker
pwd
```
- `cd`: entra na pasta. O `~` é atalho para a pasta pessoal (`/home/ubuntu`).
- `pwd`: mostra em que pasta você está.

**Esperado:** `/home/ubuntu/aws-docker`

### 1.3 Ver o conteúdo

```bash
ls -la
cat README-EC2.txt
cat instance.env
```
- `ls -la`: lista tudo da pasta, inclusive arquivos ocultos, com permissões.
- `cat`: mostra o conteúdo de um arquivo na tela.
- `instance.env`: guarda variáveis de ambiente no formato `NOME=valor` (ex.: `INSTANCE_NAME=trainee-03`).

### 1.4 Ver se o Docker já está instalado

```bash
docker --version
```
**Esperado:** `command not found` (ainda não está instalado).

---

## Parte 2 — Instalar o Docker

### 2.1 Atualizar a lista de pacotes

```bash
sudo apt-get update
```

### 2.2 Instalar ferramentas necessárias

```bash
sudo apt-get install -y ca-certificates curl
```
- `curl`: baixa arquivos da internet.
- `ca-certificates`: permite validar conexões HTTPS.
- `-y`: responde "sim" automaticamente.

### 2.3 Criar a pasta das chaves de segurança

```bash
sudo install -m 0755 -d /etc/apt/keyrings
```
- Cria a pasta `/etc/apt/keyrings`.
- `-d`: indica que é um diretório. `-m 0755`: define as permissões.

### 2.4 Baixar a chave oficial da Docker

```bash
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
```
- Baixa a chave GPG da Docker. O `apt` usa essa chave para confirmar que os pacotes vieram mesmo da Docker e não foram adulterados.
- `-o`: onde salvar o arquivo.

### 2.5 Dar permissão de leitura à chave

```bash
sudo chmod a+r /etc/apt/keyrings/docker.asc
```
- `chmod`: altera permissões. `a+r`: todos (*all*) podem ler — assim o `apt` consegue usar a chave.

### 2.6 Cadastrar o repositório da Docker

Abra um arquivo novo no vim:

```bash
sudo vim /etc/apt/sources.list.d/docker.list
```

No vim: aperte `i` (modo inserção), digite a linha abaixo, aperte `Esc` e digite `:wq` + Enter (salvar e sair).

```
deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu noble stable
```

Confira:

```bash
cat /etc/apt/sources.list.d/docker.list
```
**Esperado:** a linha acima aparece na tela.

### 2.7 Atualizar de novo e instalar o Docker

```bash
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

| Pacote | Função |
|---|---|
| `docker-ce` | Docker Engine, o serviço que roda os containers |
| `docker-ce-cli` | O comando `docker` que você digita |
| `containerd.io` | Componente de baixo nível que executa os containers |
| `docker-buildx-plugin` | Constrói imagens a partir de Dockerfiles |
| `docker-compose-plugin` | O comando `docker compose` |

### 2.8 Confirmar a instalação

```bash
docker --version
docker compose version
```
**Esperado:** as versões do Docker e do Compose aparecem.

![Docker instalado](img/01-docker-version.png)

---

## Parte 3 — Habilitar o serviço e usar sem `sudo`

### 3.1 Habilitar e iniciar o Docker

```bash
sudo systemctl enable --now docker
systemctl is-enabled docker
systemctl is-active docker
```
- `enable`: inicia o Docker sozinho quando a máquina ligar. `--now`: inicia agora também.

**Esperado:** `enabled` e `active`.

### 3.2 Testar com `sudo`

```bash
sudo docker run --rm hello-world
```
Baixa uma imagem de teste, cria um container, executa e apaga o container ao terminar (`--rm`).

**Esperado:** mensagem `Hello from Docker!`.

### 3.3 Testar sem `sudo` (erro esperado)

```bash
docker ps
```
**Esperado:** `permission denied` — o usuário `ubuntu` ainda não faz parte do grupo `docker`.

### 3.4 Adicionar o usuário ao grupo `docker`

```bash
sudo usermod -aG docker ubuntu
```
- `usermod`: modifica um usuário.
- `-G docker`: adiciona ao grupo `docker`.
- `-a`: *append* — mantém o usuário nos outros grupos que já tinha.

### 3.5 Sair e reconectar (para o grupo novo valer)

```bash
exit
```
Conecte de novo pelo SSH e volte para a pasta:

```bash
cd ~/aws-docker
groups
docker ps
```
**Esperado:** `docker` aparece na lista de `groups`, e `docker ps` mostra uma tabela vazia, sem erro.

---

## Parte 4 — Subir o banco e confirmar os dados

### 4.1 Ver o compose inicial

```bash
cat compose.yml
```
**Esperado:** só o serviço `db` (imagem oficial do PostgreSQL), com variáveis que criam o banco `training` e o usuário `training_app`, um volume para guardar os dados, um healthcheck e **nenhuma porta publicada**.

### 4.2 Subir o banco

```bash
docker compose up -d
```
- Lê o `compose.yml` e cria tudo que está descrito.
- `-d`: roda em segundo plano.
- O Compose usa o nome da pasta (`aws-docker`) como nome do projeto e cria a rede `aws-docker_default`, onde os containers se encontram pelo nome.

### 4.3 Conferir

```bash
docker compose ps
docker compose logs db
```
**Esperado:** `db` com status `healthy`; nos logs, a criação da tabela e a inserção de três linhas (Linux, Redes e DevOps).

### 4.4 Consultar os dados direto no banco

```bash
docker compose exec db psql -U training_app -d training -c "SELECT * FROM items;"
```
- `docker compose exec db`: executa um comando dentro do container `db`.
- `psql -U training_app -d training`: conecta com o usuário `training_app` no banco `training`.
- `-c "SELECT ..."`: roda a consulta e sai.

**Esperado:** tabela com 3 itens.

```bash
docker volume ls
```
**Esperado:** aparece o volume `aws-docker_postgres_data`, onde os dados ficam guardados.

---

## Parte 5 — Dockerfile do backend

### 5.1 Ver a pasta

```bash
ls -la backend/
```
**Esperado:** `package.json` e `server.js`.

### 5.2 Criar o Dockerfile

```bash
vim backend/Dockerfile
```
`i` → digite o conteúdo abaixo → `Esc` → `:wq`

```dockerfile
FROM node:20-alpine
WORKDIR /app
COPY package.json ./
RUN npm install --omit=dev
COPY server.js ./
ENV PORT=3000
EXPOSE 3000
USER node
CMD ["node", "server.js"]
```

| Linha | O que faz |
|---|---|
| `FROM node:20-alpine` | Parte de uma imagem pequena com Node.js 20 |
| `WORKDIR /app` | Define a pasta de trabalho dentro do container |
| `COPY package.json ./` | Copia a lista de dependências |
| `RUN npm install --omit=dev` | Instala só as dependências de produção |
| `COPY server.js ./` | Copia o código da API |
| `ENV PORT=3000` | Define a variável de ambiente da porta |
| `EXPOSE 3000` | Documenta que o container usa a porta 3000 |
| `USER node` | Roda como usuário comum, não como root (mais seguro) |
| `CMD [...]` | Comando que inicia a aplicação |

> 💡 No vim, se for colar texto, digite `:set paste` + Enter antes do `i`, para a indentação não bagunçar.

### 5.3 Construir a imagem

```bash
docker build -t training-api ./backend
docker images
```
- `docker build`: monta uma imagem seguindo o Dockerfile.
- `-t training-api`: dá um nome (*tag*) à imagem.
- `./backend`: pasta usada no build — os `COPY` buscam arquivos a partir dela.

**Esperado:** `training-api` aparece na lista de imagens.

### 5.4 Testar o backend isolado (temporário)

```bash
docker run -d --name api-teste --network aws-docker_default --env-file instance.env -p 3000:3000 training-api
```
- `--name api-teste`: nome do container de teste.
- `--network aws-docker_default`: coloca na mesma rede do banco. Sem isso, o nome `db` não seria encontrado.
- `--env-file instance.env`: carrega as variáveis do arquivo.
- `-p 3000:3000`: publica a porta 3000 só para este teste.

```bash
docker logs api-teste
curl -i http://localhost:3000/health
curl -i http://localhost:3000/api/items
```
**Esperado:** `HTTP/1.1 200 OK` nos dois `curl`; o segundo retorna os itens em JSON.

### 5.5 Remover o container de teste

```bash
docker rm -f api-teste
```
Libera a porta 3000. **Esperado:** `api-teste`.

---

## Parte 6 — Dockerfile do frontend

### 6.1 Ver a pasta

```bash
pwd
ls frontend/
head -3 frontend/nginx.conf
```
- `head -3`: mostra só as 3 primeiras linhas.

**Esperado:** `index.html` e `nginx.conf`; o `nginx.conf` começa com um bloco `server {` (configuração de site, que vai em `conf.d/`).

### 6.2 Criar o Dockerfile

```bash
vim frontend/Dockerfile
```

```dockerfile
FROM nginx:1.27-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY index.html /usr/share/nginx/html/index.html
EXPOSE 80
```

| Linha | O que faz |
|---|---|
| `FROM nginx:1.27-alpine` | Parte da imagem oficial do Nginx |
| `COPY nginx.conf ...` | Substitui a configuração padrão do site (inclui o repasse de `/api` para o backend) |
| `COPY index.html ...` | Coloca a página na pasta pública do Nginx |
| `EXPOSE 80` | Documenta a porta 80 |

### 6.3 Construir e conferir

```bash
docker build -t training-web ./frontend
docker run --rm training-web cat /etc/nginx/conf.d/default.conf
docker run --rm training-web ls -l /usr/share/nginx/html
```
Os dois `docker run --rm` criam um container temporário só para olhar dentro da imagem, e apagam em seguida.

**Esperado:** aparece o conteúdo do seu `nginx.conf` e os arquivos `index.html` e `50x.html` (página de erro padrão do Nginx).

---

## Parte 7 — Completar o compose.yml e subir tudo

### 7.1 Backup do compose original

```bash
cp compose.yml compose.yml.bak
```

### 7.2 Editar o compose.yml

```bash
vim compose.yml
```
Apague o conteúdo antigo (no modo normal, digite `ggdG`: vai para o início e apaga até o fim), depois `:set paste`, `i`, cole o conteúdo do arquivo [`compose.yml`](compose.yml) desta pasta, `Esc`, `:wq`.

Pontos principais do arquivo:

| Trecho | Por quê |
|---|---|
| `backend` → `DB_HOST: db` | O backend acha o banco pelo **nome do serviço** |
| `depends_on` + `condition: service_healthy` | Cada serviço só sobe depois que o anterior estiver saudável |
| `healthcheck` | Testa se o serviço está respondendo de verdade |
| `ports: "80:80"` só no frontend | Única porta exposta para fora |
| `restart: unless-stopped` | Reinicia sozinho se cair (ou se a máquina reiniciar) |

### 7.3 Validar a sintaxe

```bash
docker compose config --quiet && echo "compose OK"
```
- `config --quiet`: lê e valida o arquivo sem mostrar o conteúdo.
- `&& echo`: só imprime se o comando anterior deu certo.

**Esperado:** `compose OK`.

### 7.4 Subir tudo

```bash
docker compose up -d --build
docker compose ps
```
- `--build`: força construir as imagens do backend e do frontend pelos Dockerfiles.

**Esperado:** três containers — `db` e `backend` com `healthy`, `frontend` com `Up` e porta `0.0.0.0:80->80/tcp`.

![Containers rodando](img/02-compose-ps.png)

---

## Parte 8 — Validar

### 8.1 Pelo terminal

```bash
curl -i http://localhost/health
curl -i http://localhost/api/items
curl -s -o /dev/null -w "%{http_code}\n" http://localhost/
```
O último mostra só o código HTTP da página principal.

**Esperado:** `200` nos três; o `/api/items` retorna os itens em JSON (passou por Nginx → backend → banco).

![Validação no terminal](img/03-curl-validacao.png)

### 8.2 Só a porta 80 está exposta

```bash
sudo ss -tlnp | grep -E ':(80|3000|5432)\b'
```
- `ss -tlnp`: lista as portas que estão escutando na máquina.
- `grep`: filtra só as portas 80, 3000 e 5432.

**Esperado:** aparece **apenas a porta 80**. As portas 3000 e 5432 ficam só dentro da rede do Docker.

### 8.3 Pelo navegador

Abra `http://<IP_DA_INSTANCIA>`.

**Esperado:** a página carrega com a lista de itens. No DevTools (F12 → Network), a chamada `items` retorna `200`. (Um `304` na página significa que o navegador usou o cache, porque nada mudou.)

![Página no navegador](img/04-navegador.png)

---

## Comandos úteis

| Objetivo | Comando |
|---|---|
| Estado dos containers | `docker compose ps` |
| Logs de um serviço | `docker compose logs <serviço>` |
| Derrubar tudo (mantém os dados) | `docker compose down` |
| Derrubar tudo e apagar os dados | `docker compose down -v` |
| Reconstruir e subir | `docker compose up -d --build` |
| Entrar no banco | `docker compose exec db psql -U training_app -d training` |

> ℹ️ A senha `training_password` no `compose.yml` é apenas de laboratório. Em produção, senhas ficam em arquivos `.env` fora do Git ou em um cofre de segredos.
