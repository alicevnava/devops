# Desafio 2.2 — Proxy Reverso: o Apache atrás do Nginx

Segundo desafio da Fase 2 (Redes e segurança) da trilha de estudos: esconder o Apache atrás de um Nginx, fazer o repasse funcionar com o SELinux ativo, fechar a porta do backend no firewall, registrar o IP real dos clientes e esconder a versão do servidor.

**Método:** uma mudança por vez, `nginx -t` e `httpd -t` antes de aplicar, e teste do Windows depois de cada passo.

---

## Ambiente

| Item | Valor |
|---|---|
| **Servidor** | `servidor1` (Rocky Linux 10.2), IP fixo `192.168.50.10`, Apache do [Desafio 1.3](../../fase-1-linux/desafio-03-selinux-apache/) |
| **Cliente** | Windows (`192.168.50.1`), PowerShell com `curl.exe` |
| **Ponto de partida** | Apache nas portas 80 e 8080 de todos os IPs; firewall com `http` e `8080/tcp` liberados |

---

## Conceitos

Um **proxy reverso** fica **na frente** de outros servidores: recebe os pedidos dos clientes, repassa ao servidor de verdade (o *backend*) e devolve a resposta. O cliente nem sabe que o backend existe.

```
Windows ──► Nginx (porta 80, aberto à rede) ──► Apache (127.0.0.1:8080, escondido)
```

**Por que usar:** um único ponto de entrada, o backend protegido, e um lugar central para HTTPS e balanceamento de carga.

| Termo | Significa |
|---|---|
| **Backend** | o servidor que está atrás do proxy (aqui, o Apache) |
| **`502 Bad Gateway`** | o proxy funcionou, mas não conseguiu falar com o backend |
| **Boolean do SELinux** | uma chave de liga/desliga para um comportamento específico, como "servidor web pode abrir conexões" |
| **`X-Forwarded-For`** | cabeçalho em que o proxy informa ao backend o IP do cliente original |
| **Defesa em profundidade** | proteções em mais de uma camada, para que um erro numa delas não exponha o sistema |

---

## Enunciado

A equipe de segurança pediu que o Apache deixe de ficar exposto diretamente na rede. Todo acesso deve passar por um Nginx, e o Apache só deve aceitar conexões do próprio servidor.

### Objetivos

1. Fazer o **Apache** escutar **só** em `127.0.0.1:8080`.
2. Instalar o **Nginx** na porta 80, repassando os pedidos para o Apache.
3. Fazer funcionar com o **SELinux em Enforcing**.
4. Fechar a porta **8080** no firewall.
5. Fazer o log do Apache registrar o **IP real** do cliente.
6. **Bônus:** esconder a versão do Nginx no cabeçalho `Server`.

### Resultado esperado

- Do Windows, `http://192.168.50.10` responde `200 OK` com `Server: nginx`; a porta 8080 falha.
- `sudo ss -tlnp` mostra o `nginx` em `0.0.0.0:80` e o `httpd` só em `127.0.0.1:8080`.
- O log de acesso do Apache mostra `192.168.50.1`; `getenforce` mostra `Enforcing`.

---

## Passo a passo

### 1. Apache só no localhost

Dois programas não podem escutar na mesma porta: o Apache precisa sair da porta 80 antes de o Nginx entrar.

```
$ grep -n Listen /etc/httpd/conf/httpd.conf
47:Listen 80
48:Listen 8080
```

No `/etc/httpd/conf/httpd.conf`, as linhas antigas foram comentadas (para ficar o registro) e acrescentada a nova:

```
#Listen 80
#Listen 8080
Listen 127.0.0.1:8080
```

- Com um IP antes da porta, o Apache escuta **só** nesse endereço.
- No vi, `/^Listen 80$` busca a linha exata: `^` é o começo e `$` o fim da linha.

```bash
sudo httpd -t                  # confere a configuração: Syntax OK
sudo systemctl restart httpd
```

```
$ sudo ss -tlnp | grep httpd
LISTEN 0 511 127.0.0.1:8080 0.0.0.0:* users:(("httpd",pid=93230,fd=3),...)
$ curl http://127.0.0.1:8080
Site da equipe
```

Do Windows, o site passa a falhar com `Connection refused` (~2 s): ninguém escuta mais na porta 80 (falha B do [catálogo do Desafio 2.1](../desafio-01-caminho-requisicao/)).

### 2. Nginx na porta 80

```bash
sudo dnf install nginx
```

O `/etc/nginx/nginx.conf` já vem com um bloco `server` na porta 80 (página de boas-vindas). As configurações próprias vão em arquivos novos em `/etc/nginx/conf.d/`:

```bash
sudo vi /etc/nginx/conf.d/site.conf
```

```nginx
server {
    listen 80 default_server;
    server_name _;
    server_tokens off;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

(Versão final: as linhas `server_tokens` e `proxy_set_header` entraram nos objetivos 5 e 6.)

| Linha | Significa |
|---|---|
| `listen 80 default_server` | escuta na porta 80 e atende os pedidos que não combinam com nenhum outro bloco (como os feitos pelo IP) |
| `server_name _` | um nome que não combina com nada, usado no bloco padrão |
| `location /` | vale para todos os endereços |
| `proxy_pass http://127.0.0.1:8080;` | repassa para o Apache |

Com os dois blocos (o original e o novo) usando o nome `_`, o `nginx -t` avisa `conflicting server name "_" on 0.0.0.0:80, ignored`. Para deixar limpo, o bloco original do `nginx.conf` foi comentado. No vi, comentar um intervalo de linhas:

```
:37,45s/^/#/
```

> ⚠️ Conferir o intervalo antes de salvar. Comentar uma linha a mais (como o `include /etc/nginx/conf.d/*.conf;`) desliga o `site.conf`: o Nginx continua rodando, sem escutar em porta nenhuma, e o `nginx -t` ainda diz `syntax is ok`. Para tirar o `#` de uma linha: `:35s/^#//`.

```bash
sudo nginx -t                  # sempre antes de aplicar
sudo systemctl enable --now nginx
```

### 3. O 502 e o SELinux

```
PS> curl.exe -v http://192.168.50.10
< HTTP/1.1 502 Bad Gateway
< Server: nginx/1.26.3
```

O Nginx respondeu, mas não conseguiu falar com o Apache.

```
$ sudo ausearch -m avc -ts recent
type=AVC msg=audit(...): avc:  denied  { name_connect } for  pid=95024 comm="nginx" dest=8080
scontext=system_u:system_r:httpd_t:s0 tcontext=system_u:object_r:http_cache_port_t:s0 tclass=tcp_socket permissive=0
```

| Campo | Valor | Significa |
|---|---|---|
| `denied { name_connect }` | conectar | o processo tentou **abrir** uma conexão de rede |
| `comm="nginx"`, `dest=8080` | o Nginx, para a porta 8080 | o repasse para o Apache |
| `scontext=httpd_t` | rótulo do Nginx | o mesmo rótulo do Apache |
| `tcontext=http_cache_port_t` | rótulo da porta 8080 | porta de cache e proxy web |

Por padrão, o SELinux deixa um servidor web **receber** conexões, mas não **abrir** conexões para outros serviços: um servidor web invadido não pode ser usado para atacar outros sistemas.

```
$ getsebool -a | grep httpd_can_network
httpd_can_network_connect --> off
httpd_can_network_connect_cobbler --> off
httpd_can_network_connect_db --> off
httpd_can_network_memcache --> off
httpd_can_network_redis --> off
httpd_can_network_relay --> off
```

| Boolean | O que libera |
|---|---|
| `httpd_can_network_connect` | conexões para **qualquer** porta |
| `httpd_can_network_relay` | conexões só para portas de servidores web e proxies |

Pelo princípio do **menor privilégio**, a escolhida foi a `httpd_can_network_relay`:

```bash
sudo setsebool -P httpd_can_network_relay on
```

- `-P` grava de forma permanente; sem ele, a boolean volta a `off` no boot.

```
PS> curl.exe -v http://192.168.50.10
< HTTP/1.1 200 OK
< Server: nginx/1.26.3
< ETag: "f-65e6e9b17047d"
<
Site da equipe
```

O `Server` é do Nginx, mas o `ETag` e o `Last-Modified` são os mesmos que o Apache enviava antes: o conteúdo veio do Apache, repassado pelo Nginx.

### 4. Fechar a porta 8080 no firewall

```bash
sudo firewall-cmd --permanent --remove-port=8080/tcp
sudo firewall-cmd --reload
```

| Momento | Teste do Windows na 8080 | Quem barrou |
|---|---|---|
| Porta aberta no firewall | `Connection refused` (~2 s) | ninguém escuta na 8080 do IP `192.168.50.10` |
| Porta fechada no firewall | `Timed out` (~21 s) | o firewall |

O Apache já não aceitava conexões de fora, mas a porta foi fechada também no firewall: **defesa em profundidade**. Se alguém mudar o `Listen` por engano, o firewall continua protegendo, e vice-versa.

### 5. O IP real no log do Apache

Antes:

```
$ sudo tail -3 /var/log/httpd/access_log
127.0.0.1 - - [28/Oct/2026:14:28:33 -0300] "GET / HTTP/1.1" 200 15 "-" "curl/8.12.1"
127.0.0.1 - - [28/Oct/2026:14:42:50 -0300] "GET / HTTP/1.0" 200 15 "-" "curl/8.21.0"
127.0.0.1 - - [28/Oct/2026:14:47:01 -0300] "GET / HTTP/1.0" 200 15 "-" "curl/8.21.0"
```

- Para o Apache, quem pediu foi o Nginx (`127.0.0.1`). A primeira linha (`curl/8.12.1`) é um teste feito de dentro do próprio servidor.
- Os pedidos que passam pelo Nginx aparecem como `HTTP/1.0`: por padrão, o Nginx conversa com o backend nessa versão.

**No Nginx:** os três `proxy_set_header` do `site.conf` (ver o passo 2).

| Linha | O que faz |
|---|---|
| `Host $host` | repassa o nome pedido pelo cliente |
| `X-Real-IP $remote_addr` | envia o IP de quem se conectou ao Nginx |
| `X-Forwarded-For $proxy_add_x_forwarded_for` | o cabeçalho padrão; cada proxy no caminho acrescenta um IP |

**No Apache:** o `mod_remoteip` faz o Apache usar o IP do cabeçalho, mas só quando o pedido vem de um proxy confiável.

```
$ sudo httpd -M | grep remoteip
 remoteip_module (shared)
```

```bash
sudo vi /etc/httpd/conf.d/remoteip.conf
```

```apache
RemoteIPHeader X-Forwarded-For
RemoteIPInternalProxy 127.0.0.1
```

- `RemoteIPHeader`: qual cabeçalho traz o IP real.
- `RemoteIPInternalProxy`: de quem aceitar o cabeçalho. Sem essa limitação, qualquer cliente poderia inventar um IP.

```bash
sudo httpd -t
sudo systemctl restart httpd
```

Depois:

```
$ sudo tail -3 /var/log/httpd/access_log
127.0.0.1 - - [28/Oct/2026:14:47:01 -0300] "GET / HTTP/1.0" 200 15 "-" "curl/8.21.0"
127.0.0.1 - - [28/Oct/2026:14:48:41 -0300] "GET / HTTP/1.0" 200 15 "-" "curl/8.21.0"
192.168.50.1 - - [28/Oct/2026:14:49:25 -0300] "GET / HTTP/1.0" 200 15 "-" "curl/8.21.0"
```

### 6. Esconder a versão (bônus)

A linha `server_tokens off;` no bloco `server` do `site.conf` faz o Nginx mostrar só `nginx`, sem a versão, nos cabeçalhos e nas páginas de erro (antes, até o `502` mostrava `nginx/1.26.3`).

---

## Testes

```
PS> curl.exe -v http://192.168.50.10
< HTTP/1.1 200 OK
< Server: nginx
<
Site da equipe

$ sudo ss -tlnp | grep -E ':80|:8080'
LISTEN 0 511 127.0.0.1:8080 0.0.0.0:* users:(("httpd",pid=101649,fd=3),...)
LISTEN 0 511   0.0.0.0:80   0.0.0.0:* users:(("nginx",pid=102505,fd=9),...)

$ getenforce
Enforcing
$ getsebool httpd_can_network_relay
httpd_can_network_relay --> on

$ sudo firewall-cmd --list-all
public (default, active)
  interfaces: eth0 eth1
  services: cockpit dhcpv6-client http ssh
  ports:
```

---

## Erros que aconteceram e como foram resolvidos

| Sintoma | Causa | Correção |
|---|---|---|
| `nginx: [warn] conflicting server name "_" on 0.0.0.0:80, ignored` | Dois blocos `server` com o nome `_` na porta 80: o original do `nginx.conf` e o `site.conf` | Comentar o bloco original |
| `502 Bad Gateway` | O SELinux impediu o Nginx (`httpd_t`) de abrir conexão para a porta 8080 (`http_cache_port_t`) | `sudo setsebool -P httpd_can_network_relay on` |
| `Connection refused` na porta 80 depois de comentar o bloco original | O comentário pegou a linha `include /etc/nginx/conf.d/*.conf;`: o Nginx ficou sem nenhum site, e o `nginx -t` continuou dizendo `syntax is ok` | Tirar o `#` da linha (`:35s/^#//`) |
| `curl.exe: comando não encontrado` | O teste do Windows foi digitado no servidor Linux (lá, o comando é `curl`) | Rodar no PowerShell do Windows |
| O log do Apache continuou com `127.0.0.1` depois de criar o `remoteip.conf` | O Apache não tinha sido reiniciado | `sudo httpd -t` e `sudo systemctl restart httpd` |

---

## Resumo

- Proxy reverso: o Nginx recebe na porta 80 e repassa com `proxy_pass`; o backend escuta só no `127.0.0.1`.
- `502 Bad Gateway`: o proxy não alcança o backend. Investigar com `/var/log/nginx/error.log` e `ausearch -m avc`.
- SELinux: servidores web não abrem conexões por padrão; liberar com a boolean mais restrita que resolva (`httpd_can_network_relay`), com `setsebool -P`.
- `nginx -t` e `httpd -t` conferem a sintaxe, mas não provam que a configuração faz o que se quer: testar com `ss` e `curl`.
- `X-Forwarded-For` + `mod_remoteip` (com `RemoteIPInternalProxy`) preservam o IP real no log do backend.
- Defesa em profundidade: backend no localhost **e** porta fechada no firewall. `server_tokens off` esconde a versão.
