# Desafio 2.4 — Balanceamento de carga com Nginx

Quarto desafio da Fase 2 (Redes e segurança) da trilha de estudos: colocar dois servidores web atrás do Nginx, dividir os pedidos entre eles, ver o que acontece quando um cai (e quando os dois caem), usar pesos e um servidor de reserva.

**Método:** um passo por vez, `nginx -t` antes de todo `reload`, e um cabeçalho na resposta (`X-Backend`) para provar qual servidor atendeu cada pedido.

---

## Ambiente

| Item | Valor |
|---|---|
| **Servidor** | `servidor1` (Rocky Linux 10.2), IP fixo `192.168.50.10` |
| **Ponto de partida** | HTTPS do [Desafio 2.3](../desafio-03-https/): Nginx na 443 repassando para o Apache em `127.0.0.1:8080` |
| **Backend A** | Apache em `127.0.0.1:8080` (página `Site da equipe`) |
| **Backend B** | servidor web do Python em `127.0.0.1:8123` (página `Servidor B`) |
| **Terminais** | duas abas do MobaXterm: a **padrão** (todos os comandos) e a **do Python** (só rodando o backend B) |

```
Cliente ──HTTPS──► Nginx :443 ──┬──► A: Apache  127.0.0.1:8080
                                └──► B: Python  127.0.0.1:8123
```

> O B é um servidor Python simples para que cada backend possa ser derrubado sem derrubar o outro: se os dois fossem o mesmo Apache, `systemctl stop httpd` pararia os dois.

---

## Conceitos

| Termo | Significa |
|---|---|
| **Balanceamento de carga** | distribuir os pedidos entre vários servidores iguais |
| **`upstream`** | no Nginx, um grupo de backends com um nome; o `proxy_pass` aponta para o grupo |
| **Round-robin** | o método padrão: um pedido para cada servidor, em rodízio |
| **Failover** | quando um servidor falha, o pedido é repassado para outro sem o cliente perceber |
| **Verificação passiva de saúde** | o Nginx só descobre que um backend caiu quando um pedido real falha; depois disso, para de usá-lo por um tempo (`max_fails=1`, `fail_timeout=10s` por padrão) |
| **`weight`** | peso: um servidor com `weight=3` recebe 3 vezes mais pedidos que um com peso 1 |
| **`backup`** | servidor de reserva: só recebe pedidos quando todos os principais estão fora |

---

## Enunciado

O site da equipe ficou popular e, quando o Apache para para manutenção, o site inteiro cai. A equipe quer dois servidores web atrás do Nginx, dividindo os pedidos, e que o site continue no ar se um deles cair.

### Objetivos

1. Subir o **backend B** em `127.0.0.1`, com uma página que diga `Servidor B`.
2. Criar um grupo **`upstream`** com os dois backends e fazer o HTTPS usar esse grupo.
3. Provar que os pedidos **alternam** entre A e B.
4. Adicionar o cabeçalho **`X-Backend`** com o backend que respondeu.
5. **Derrubar um backend** e provar que o site continua no ar; achar a falha no `error.log`.
6. **Derrubar os dois** e explicar o erro.
7. Fazer o A receber **3 vezes mais** pedidos que o B.

**Bônus:** marcar o B como **reserva** (`backup`).

---

## Passo a passo

### 1. Backend B

Na **aba do Python**:

```bash
mkdir ~/site-b
echo "Servidor B" > ~/site-b/index.html
python3 -m http.server 8081 --bind 127.0.0.1 --directory ~/site-b
```

| Parte | O que faz |
|---|---|
| `python3 -m http.server` | servidor web simples que já vem no Python |
| `8081` | a porta (depois trocada para 8123, ver passo 3) |
| `--bind 127.0.0.1` | escuta só no localhost: ninguém de fora acessa direto |
| `--directory ~/site-b` | a pasta servida |

Resultado: `Serving HTTP on 127.0.0.1 port 8081 (http://127.0.0.1:8081/) ...` e o terminal fica ocupado. **Isso é o esperado**: a aba fica dedicada ao servidor, e `Ctrl+C` o encerra.

Na **aba padrão**, testar os dois backends direto:

```bash
ss -tln | grep 8081
curl http://127.0.0.1:8080
curl http://127.0.0.1:8081
```

```
Site da equipe
Servidor B
```

### 2. O grupo `upstream`

Backup antes de mexer:

```bash
sudo cp /etc/nginx/conf.d/site.conf /etc/nginx/conf.d/site.conf.bak-2.3
```

O `include` do `nginx.conf` só carrega arquivos terminados em `.conf`, então o `.bak-2.3` não interfere.

No topo do `/etc/nginx/conf.d/site.conf`, **fora** dos blocos `server`:

```nginx
upstream backends {
    server 127.0.0.1:8080;   # A (Apache)
    server 127.0.0.1:8081;   # B (Python)
}
```

E no bloco da porta 443, o `proxy_pass` passa a apontar para o **nome do grupo**:

```nginx
        proxy_pass http://backends;
```

| Parte | Significa |
|---|---|
| `upstream backends { }` | cria o grupo `backends` (o nome é livre) |
| `server IP:porta;` | um membro do grupo. Precisa ser o endereço real: um nome como `A` faria o Nginx procurar uma máquina chamada "A" |
| `proxy_pass http://backends;` | manda os pedidos para o grupo; o Nginx escolhe o membro |

```bash
sudo nginx -t
sudo systemctl reload nginx
curl -k https://localhost
```

`-k` porque o certificado vale para `servidor1.estudos.local`, `servidor1` e `192.168.50.10`, não para `localhost`.

### 3. Só o A respondia: SELinux de novo

Rodando o `curl` várias vezes, só aparecia `Site da equipe`, e a aba do Python não recebia nada. O site **não dava erro**: o Nginx tentava o B, falhava e repassava para o A sem avisar ninguém. Uma **falha silenciosa**.

```bash
sudo ausearch -m avc -ts recent
```

```
type=AVC msg=audit(1793284208.499:1413): avc:  denied  { name_connect } for  pid=229874 comm="nginx" dest=8081 scontext=system_u:system_r:httpd_t:s0 tcontext=system_u:object_r:transproxy_port_t:s0 tclass=tcp_socket permissive=0
```

O `semanage` não vem na instalação mínima:

```bash
dnf provides semanage
sudo dnf install -y policycoreutils-python-utils
sudo semanage port -l | grep -w 8081
sudo semanage port -l | grep -w 8080
```

```
transproxy_port_t              tcp      8081
http_cache_port_t              tcp      8080, 8118, 8123, 10001-10010
```

| Comando | O que faz |
|---|---|
| `dnf provides semanage` | descobre qual pacote fornece o comando |
| `semanage port -l` | lista as portas com rótulo no SELinux |
| `grep -w` | procura o número como palavra inteira (`8081` não pega `18081`) |

A 8081 já vem rotulada como `transproxy_port_t` (proxy transparente). A boolean `httpd_can_network_relay`, ligada no [Desafio 2.2](../desafio-02-proxy-reverso-nginx/), cobre portas de servidor web e de proxy (como a 8080, `http_cache_port_t`), mas **não** esse rótulo.

**Opções avaliadas:**

| Opção | Comando | Avaliação |
|---|---|---|
| 1. Liberar qualquer porta | `setsebool -P httpd_can_network_connect on` | abre demais: um Nginx invadido poderia conectar em banco de dados, SSH etc. |
| 2. Trocar o rótulo da 8081 | `semanage port -m -t http_cache_port_t -p tcp 8081` | correta quando a porta **não pode** mudar. `-m` (modificar), porque a porta já tem rótulo; `-a` daria erro |
| 3. **Mudar o B de porta** ✅ | usar uma porta que já seja `http_cache_port_t` | nada muda no SELinux. Escolhida porque o B é nosso e a porta é livre |

Na aba do Python, `Ctrl+C` e:

```bash
python3 -m http.server 8123 --bind 127.0.0.1 --directory ~/site-b
```

No `upstream`, a linha do B passou a ser `server 127.0.0.1:8123;`. Depois, `nginx -t` e `reload`.

### 4. Round-robin funcionando

```
$ curl -k https://localhost
Site da equipe
$ curl -k https://localhost
Site da equipe
$ curl -k https://localhost
Servidor B
$ curl -k https://localhost
Site da equipe
$ curl -k https://localhost
Servidor B
$ curl -k https://localhost
Site da equipe

$ sudo ausearch -m avc -ts recent
<no matches>
```

Aba do Python:

```
127.0.0.1 - - [29/Oct/2026 13:47:30] "GET / HTTP/1.1" 200 -
127.0.0.1 - - [29/Oct/2026 13:49:31] "GET / HTTP/1.0" 200 -
127.0.0.1 - - [29/Oct/2026 13:49:33] "GET / HTTP/1.0" 200 -
```

- **A alternância não é perfeita** (começou A, A) porque o Nginx tem **2 workers**, cada um com seu próprio contador de rodízio. No total, a divisão fica equilibrada.
  ```
  $ ps -ef | grep "nginx: worker"
  nginx     256715   95023  0 13:48 ?        00:00:00 nginx: worker process
  nginx     256716   95023  0 13:48 ?        00:00:00 nginx: worker process
  ```
- **`HTTP/1.1` x `HTTP/1.0`:** o pedido das 13:47:30 foi o meu `curl` direto na 8123; os outros vieram do Nginx, que fala HTTP/1.0 com os backends por padrão.

### 5. Cabeçalho `X-Backend`

Dentro do `location /` da porta 443:

```nginx
        add_header X-Backend $upstream_addr;
```

| Parte | Significa |
|---|---|
| `add_header` | acrescenta um cabeçalho na **resposta** para o cliente (o `proxy_set_header` acrescenta no **pedido** para o backend) |
| `X-Backend` | nome do cabeçalho (`X-` = personalizado) |
| `$upstream_addr` | variável que o Nginx preenche com o `IP:porta` do backend que atendeu |

```bash
curl -k -I https://localhost
```

`-I` mostra só os cabeçalhos da resposta.

```
HTTP/1.1 200 OK
Server: nginx
Content-Type: text/html; charset=UTF-8
Content-Length: 15
ETag: "f-65e6e9b17047d"
Accept-Ranges: bytes
X-Backend: 127.0.0.1:8080

HTTP/1.1 200 OK
Server: nginx
Content-Type: text/html
Content-Length: 11
X-Backend: 127.0.0.1:8123
```

| Cabeçalho | A (Apache) | B (Python) |
|---|---|---|
| `Content-Length` | 15 ("Site da equipe" + quebra de linha) | 11 ("Servidor B" + quebra de linha) |
| `ETag`, `Accept-Ranges` | tem | não tem |
| `Server` | `nginx` | `nginx`: o Nginx substitui o `Server: SimpleHTTP/... Python/...` do backend |

Final do bloco `location /`:

```nginx
    location / {
        proxy_pass http://backends;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        add_header X-Backend $upstream_addr;
    }
```

### 6. Um backend fora: failover

```bash
sudo systemctl stop httpd
ss -tln | grep 8080
curl -k -I https://localhost
```

```
HTTP/1.1 200 OK
X-Backend: 127.0.0.1:8080, 127.0.0.1:8123

HTTP/1.1 200 OK
X-Backend: 127.0.0.1:8123

HTTP/1.1 200 OK
X-Backend: 127.0.0.1:8123
```

- **Primeiro pedido:** o Nginx tentou o A, levou "conexão recusada" e **tentou de novo no B** (`proxy_next_upstream`, ligado por padrão). O cliente recebeu `200 OK`.
- **Seguintes:** o A nem foi tentado.

```bash
sudo grep 8080 /var/log/nginx/error.log | tail -3
```

```
[error] *70 connect() failed (111: Connection refused) while connecting to upstream, ... upstream: "http://127.0.0.1:8080/"
[warn]  *70 upstream server temporarily disabled while connecting to upstream, ... upstream: "http://127.0.0.1:8080/"
```

Depois de 1 falha, o A foi marcado como fora do ar por **10 segundos**. Passado o prazo, o Nginx tenta de novo com um pedido real.

**Os números do erro dizem a camada:**

| Erro | Causa | Camada |
|---|---|---|
| `(13: Permission denied)` | SELinux bloqueou (Desafio 2.2 e porta 8081) | segurança |
| `(111: Connection refused)` | ninguém escutando na porta | serviço |

### 7. Os dois fora: 502

Na aba do Python, `Ctrl+C`. Na aba padrão:

```
$ curl -k -I https://localhost
HTTP/1.1 502 Bad Gateway
$ curl -k -I https://localhost
HTTP/1.1 502 Bad Gateway

$ sudo tail -4 /var/log/nginx/error.log
[warn]  *79 upstream server temporarily disabled ... upstream: "http://127.0.0.1:8123/"
[error] *79 connect() failed (111: Connection refused) ... upstream: "http://127.0.0.1:8080/"
[warn]  *79 upstream server temporarily disabled ... upstream: "http://127.0.0.1:8080/"
[error] *82 no live upstreams while connecting to upstream ... upstream: "http://backends/"
```

- **`502 Bad Gateway`:** o Nginx funciona, mas nenhum backend respondeu.
- **Pedido `*79`:** tentou os dois, os dois recusaram, e os dois foram marcados como fora.
- **Pedido `*82`:** **"nenhum backend vivo"**. Com os dois marcados, o Nginx nem tentou conectar e respondeu 502 na hora. O `upstream:` mostra o nome do grupo porque nenhum membro foi escolhido.

### 8. Pesos

Subir os dois de novo:

```bash
sudo systemctl start httpd                                          # aba padrão
python3 -m http.server 8123 --bind 127.0.0.1 --directory ~/site-b   # aba do Python
ss -tln | grep -E "8080|8123"
```

`grep -E "8080|8123"` mostra linhas com uma **ou** outra porta.

```nginx
upstream backends {
    server 127.0.0.1:8080 weight=3;   # A (Apache)
    server 127.0.0.1:8123;            # B (Python)
}
```

```bash
curl -k -s -I https://localhost | grep X-Backend
```

`-s` esconde a barra de progresso; `grep` mostra só o cabeçalho que interessa. Resultado de 13 pedidos: **10 no A e 3 no B**, no padrão A, A, A, B.

**Uso real:** servidores de capacidades diferentes, ou migração gradual (servidor novo com `weight=1` contra `weight=9` do antigo, recebendo 10% do tráfego no começo).

### 9. Bônus: servidor de reserva

```nginx
    server 127.0.0.1:8123 backup;   # B (Python)
```

| Momento | O que foi feito | `X-Backend` |
|---|---|---|
| Normal | — | só `127.0.0.1:8080` (o B fica ocioso) |
| A em manutenção | `sudo systemctl stop httpd` | `127.0.0.1:8080, 127.0.0.1:8123` no primeiro pedido, depois só `127.0.0.1:8123` |
| A de volta | `sudo systemctl start httpd` + ~10 s | só `127.0.0.1:8080` |

**Por que esperar ~10 s:** o A tinha sido marcado como fora por 10 segundos (`fail_timeout`). Nesse intervalo o Nginx não o tenta, mesmo que ele já tenha voltado.

### Configuração final

```nginx
upstream backends {
    server 127.0.0.1:8080 weight=3;   # A (Apache)
    server 127.0.0.1:8123 backup;     # B (Python)
}

server {
    listen 80 default_server;
    server_name _;
    server_tokens off;

    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl default_server;
    server_name _;
    server_tokens off;

    ssl_certificate /etc/pki/nginx/server.crt;
    ssl_certificate_key /etc/pki/nginx/private/server.key;

    location / {
        proxy_pass http://backends;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        add_header X-Backend $upstream_addr;
    }
}
```

> O backend B não sobe sozinho no boot (roda no terminal). Se a VM reiniciar, o site continua no ar pelo A; para voltar a ter a reserva, rodar o `python3 -m http.server` de novo.

---

## Erros que aconteceram e como foram resolvidos

| Sintoma | Causa | Correção |
|---|---|---|
| `OSError: [Errno 99] Cannot assign requested address` | Digitado `--bind 12.0.0.1`: um programa só pode escutar num IP que pertence à máquina | `--bind 127.0.0.1` (ver os IPs com `ip -br addr`) |
| `curl: (7) Failed to connect to 127.0.0.1 port 8081 after 0 ms` | O servidor Python tinha sido encerrado com `Ctrl+C`; falhar em 0 ms = conexão recusada, nada escutando | Subir de novo e não mexer na aba do Python |
| `-bash: proxy_pass: comando não encontrado` | Linha de configuração digitada no terminal | Escrever dentro do arquivo, com o `vi` |
| Só o A respondia, sem erro para o cliente | SELinux: a 8081 é `transproxy_port_t`, não coberta pela `httpd_can_network_relay` (`ausearch` mostrou `denied { name_connect }`) | Mudar o B para a 8123 (`http_cache_port_t`) |
| `sudo: semanage: comando não encontrado` | O pacote não vem na instalação mínima | `dnf provides semanage` → `sudo dnf install -y policycoreutils-python-utils` |
| `tail -5` do `error.log` sem o erro da 8081 | As últimas linhas eram as mensagens do `reload` | `sudo grep 8081 /var/log/nginx/error.log` |
| `sudo: nginix: comando não encontrado` | Erro de digitação | `sudo nginx -t` |

---

## Resumo

- `upstream` cria o grupo; `proxy_pass http://<grupo>;` usa o grupo. Cada `server` é `IP:porta`.
- Round-robin é o padrão. Com vários workers, a alternância não é perfeita pedido a pedido, mas é equilibrada no total.
- `add_header X-Backend $upstream_addr;` mostra quem atendeu. Dois endereços no cabeçalho = houve failover.
- Um backend fora: o Nginx tenta o próximo (failover) e marca o que falhou como fora por 10 s (`max_fails=1`, `fail_timeout=10s`). Verificação **passiva**.
- Todos fora: `502 Bad Gateway`; no log, `no live upstreams`.
- `111: Connection refused` = serviço parado; `13: Permission denied` = SELinux.
- SELinux: antes de liberar geral, ver o rótulo da porta (`semanage port -l`) e preferir a solução mais restrita. Aqui, bastou mudar de porta.
- `weight=` para servidores diferentes ou migração gradual; `backup` para reserva.
