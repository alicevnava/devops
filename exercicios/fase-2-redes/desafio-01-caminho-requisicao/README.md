# Desafio 2.1 — O Caminho de uma Requisição: Cada Erro Conta uma História

Primeiro desafio da Fase 2 (Redes e segurança) da trilha de estudos: observar uma requisição web que funciona, camada por camada, e montar um **catálogo de sintomas** para diagnosticar chamados de "site fora do ar".

**Método:** provocar uma falha por vez, testar, anotar o sintoma e desfazer antes da próxima.

---

## Ambiente

| Item | Valor |
|---|---|
| **Servidor** | `servidor1` (Rocky Linux 10.2), IP fixo `192.168.50.10`, Apache nas portas 80 e 8080 (ver a [Fase 1](../../fase-1-linux/)) |
| **Cliente** | computador hospedeiro com Windows, IP `192.168.50.1` na rede interna, PowerShell com `curl.exe` |
| **Acesso** | SSH com chave pelo MobaXterm, em **duas abas** (uma para a captura de pacotes, outra para os comandos) |

---

## Conceitos

Quando alguém diz "o site não abre", o problema pode estar em várias camadas, sempre nesta ordem:

```
Nome (DNS) → Rota e IP → Firewall → Porta e serviço → Aplicação (permissões, SELinux)
```

| Camada | Pergunta | Comando de confirmação |
|---|---|---|
| **DNS** | o nome vira o IP certo? | `getent hosts`, `dig` |
| **Rede** | o pacote chega ao servidor? | `ping`, `tcpdump` |
| **Firewall** | o servidor deixa o pacote entrar? | `firewall-cmd --list-all` |
| **Porta e serviço** | tem algum programa escutando na porta? | `systemctl status`, `ss -tlnp` |
| **Aplicação** | o programa consegue entregar o que foi pedido? | logs, `ls -lZ`, `ausearch` |

### O aperto de mão do TCP

| Marcação no `tcpdump` | Nome | Significa |
|---|---|---|
| `S` | SYN | pedido para abrir a conexão |
| `.` | ACK | "recebi" |
| `P` | PUSH | pacote com dados |
| `F` | FIN | pedido para fechar a conexão |
| `R` | RST | recusa ("não tem ninguém nesta porta") |

---

## Enunciado

A equipe de suporte vai repassar chamados de "site fora do ar". Antes, é preciso conhecer o caminho de uma requisição que **funciona** e montar um catálogo: para cada tipo de falha, a mensagem que aparece, a camada responsável e o comando que confirma a causa.

### Objetivos

**Parte 1: observar uma requisição que funciona**

1. Consultar o DNS de um site da internet e identificar o IP, o servidor DNS que respondeu e o TTL.
2. Listar as portas em que o servidor escuta e o programa de cada uma.
3. Do Windows, fazer uma requisição detalhada ao site e identificar a conexão, o pedido e o código de resposta.
4. Capturar os pacotes da requisição e identificar o aperto de mão do TCP e o pedido HTTP.

**Parte 2: o catálogo de sintomas**

| # | Falha provocada | Onde testar |
|---|---|---|
| A | Pedir um nome que não existe (`http://servidor9`) | no servidor |
| B | Parar o Apache | do Windows |
| C | Tirar o `http` do firewall, sem `--permanent` | do Windows |
| D | Pedir uma porta em que nada escuta (`8081`) | do Windows e do servidor |
| E | Tirar a leitura do `index.html` para os outros | do Windows |

5. Registrar, para cada falha: mensagem, camada, comando que confirma e correção.
6. Explicar a diferença entre as falhas B e C, e por que ela importa num chamado.

---

## Parte 1 — Uma requisição que funciona

### Ferramentas

```bash
dnf provides dig
sudo dnf install bind-utils tcpdump
```

- O `dig` vem no pacote `bind-utils`, com outras ferramentas de DNS (`nslookup`, `host`).

### 1. Consulta DNS

```
$ dig rockylinux.org
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 49948
;; flags: qr rd ad; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 0
;; WARNING: recursion requested but not available

;; ANSWER SECTION:
rockylinux.org.         0       IN      A       76.223.126.88

;; Query time: 32 msec
;; SERVER: 172.28.64.1#53(172.28.64.1) (UDP)
```

A linha da resposta:

```
rockylinux.org.    0      IN      A       76.223.126.88
   nome          TTL   classe   tipo    resposta (IP)
```

| O que se procura | Onde | Valor |
|---|---|---|
| IP do site | `ANSWER SECTION`, última coluna | `76.223.126.88` |
| Servidor DNS que respondeu | `SERVER:` | `172.28.64.1`, porta 53, UDP |
| TTL | `ANSWER SECTION`, coluna depois do nome | `0` segundos |

- O `172.28.64.1` é o Windows, pelo Default Switch do Hyper-V: o mesmo endereço configurado em `/etc/resolv.conf` (`nameserver`) e mostrado como DNS da `eth0` no `nmcli device show`.
- O TTL `0` e o aviso `recursion requested but not available` acontecem porque o DNS do Default Switch não é um servidor DNS completo: ele só repassa as perguntas ao DNS do Windows. Para comparar com um DNS público: `dig @1.1.1.1 rockylinux.org`.

> ⚠️ O `dig` pergunta **só ao servidor DNS** e ignora o `/etc/hosts`. Já o `getent hosts`, o `curl` e o `ping` seguem a ordem do `/etc/nsswitch.conf` (primeiro o arquivo, depois o DNS). Por isso, `dig servidor1` responde `NXDOMAIN`, mas `getent hosts servidor1` encontra o nome cadastrado no `/etc/hosts`.

### 2. Portas e programas

```
$ sudo ss -tulnp
Netid State  Recv-Q Send-Q Local Address:Port  Peer Address:Port Process
udp   UNCONN 0      0          127.0.0.1:323        0.0.0.0:*
udp   UNCONN 0      0              [::1]:323           [::]:*
tcp   LISTEN 0      128          0.0.0.0:22         0.0.0.0:*     users:(("sshd",pid=889,fd=7))
tcp   LISTEN 0      511                *:8080             *:*     users:(("httpd",pid=75728,fd=6),...)
tcp   LISTEN 0      511                *:80               *:*     users:(("httpd",pid=75728,fd=4),...)
tcp   LISTEN 0      128             [::]:22            [::]:*     users:(("sshd",pid=889,fd=8))
```

- `-t` TCP, `-u` UDP, `-l` só as que escutam, `-n` números em vez de nomes, `-p` o processo. Sem `sudo`, a coluna `Process` fica vazia para processos de outros usuários.

| Porta | Endereço | Significa |
|---|---|---|
| 22/tcp | `0.0.0.0` e `[::]` | SSH, em todos os IPs (IPv4 e IPv6) |
| 80 e 8080/tcp | `*` | Apache, em todos os IPs |
| 323/udp | `127.0.0.1` e `[::1]` | `chronyd` (relógio), **só no localhost**: inacessível de fora |

A coluna **Local Address** mostra por onde cada serviço aceita conexões: `0.0.0.0` ou `*` significa qualquer placa; `127.0.0.1`, só de dentro do servidor.

### 3. Requisição detalhada (do Windows)

No PowerShell, usar `curl.exe` (o `curl` sozinho é um apelido para outro comando do PowerShell).

```
PS> curl.exe -v http://192.168.50.10
*   Trying 192.168.50.10:80...
* Established connection to 192.168.50.10 (192.168.50.10 port 80) from 192.168.50.1 port 62961
* using HTTP/1.x
> GET / HTTP/1.1
> Host: 192.168.50.10
> User-Agent: curl/8.21.0
> Accept: */*
>
* Request completely sent off
< HTTP/1.1 200 OK
< Date: Wed, 28 Oct 2026 14:48:13 GMT
< Server: Apache/2.4.63 (Rocky Linux)
< Content-Length: 15
< Content-Type: text/html; charset=UTF-8
<
Site da equipe
```

| Marcação | Bloco | O que mostra |
|---|---|---|
| `*` | a conexão | IP, porta de destino e a porta **temporária** de origem do cliente |
| `>` | o pedido | `GET /` (a página inicial), o `Host` pedido e quem pede (`User-Agent`) |
| `<` | a resposta | o **código** (`200 OK`), o servidor e a versão (`Server`), o tamanho e o tipo do conteúdo |
| sem marcação | o conteúdo | o `index.html` |

- O cabeçalho `Server` revela o programa e a versão, o que ajuda quem procura falhas conhecidas. Esconder essa informação é uma melhoria de segurança.
- `Date` vem em GMT: 14:48 GMT são 11:48 em Brasília.

### 4. Captura de pacotes

```bash
sudo tcpdump -i eth1 -n port 80
```

- `-i eth1` escuta a placa da rede interna; `-n` mostra IPs e portas em número; `port 80` filtra só o tráfego web (sem isso, a tela enche com o próprio SSH). `Ctrl+C` encerra.

```
11:50:35.302313 IP 192.168.50.1.62187 > 192.168.50.10.http: Flags [S], seq 593259244, ...
11:50:35.302357 IP 192.168.50.10.http > 192.168.50.1.62187: Flags [S.], seq 4255533255, ack 593259245, ...
11:50:35.302470 IP 192.168.50.1.62187 > 192.168.50.10.http: Flags [.], ack 1, ...
11:50:35.306447 IP 192.168.50.1.62187 > 192.168.50.10.http: Flags [P.], seq 1:78, ack 1, length 77: HTTP: GET / HTTP/1.1
11:50:35.306473 IP 192.168.50.10.http > 192.168.50.1.62187: Flags [.], ack 78, ...
11:50:35.306773 IP 192.168.50.10.http > 192.168.50.1.62187: Flags [P.], seq 1:262, ack 78, length 261: HTTP: HTTP/1.1 200 OK
11:50:35.321292 IP 192.168.50.1.62187 > 192.168.50.10.http: Flags [F.], seq 78, ack 262, ...
11:50:35.321444 IP 192.168.50.10.http > 192.168.50.1.62187: Flags [F.], seq 262, ack 79, ...
11:50:35.321583 IP 192.168.50.1.62187 > 192.168.50.10.http: Flags [.], ack 263, ...
9 packets captured
```

| Fase | Pacotes |
|---|---|
| Abertura (aperto de mão) | `[S]` → `[S.]` → `[.]` |
| Dados | `[P.]` com o `GET` (77 bytes) → `[.]` → `[P.]` com o `200 OK` (261 bytes) |
| Encerramento | `[F.]` → `[F.]` → `[.]` |

A conversa inteira levou 19 milissegundos. A linha `dropped privs to tcpdump` mostra que o `tcpdump` começa como root para escutar a placa e depois passa a rodar como um usuário comum, por segurança.

---

## Parte 2 — O catálogo de sintomas

### A. Nome que não existe

```
$ curl -v http://servidor9
* Could not resolve host: servidor9
curl: (6) Could not resolve host: servidor9

$ dig servidor9
;; ->>HEADER<<- opcode: QUERY, status: NXDOMAIN, id: 39204
;; flags: qr rd ra ad; QUERY: 1, ANSWER: 0, AUTHORITY: 1, ADDITIONAL: 1
;; AUTHORITY SECTION:
.                       86146   IN      SOA     a.root-servers.net. nstld.verisign-grs.com. ...
;; Query time: 1316 msec
```

- Não há a linha `Trying ...`: o `curl` parou **antes** de conectar, ao tentar transformar o nome em IP.
- `NXDOMAIN`: o nome não existe. Sem domínio no nome, a pergunta subiu até os **servidores raiz** da internet (`a.root-servers.net`), o que explica os 1316 ms.
- `getent hosts servidor9` não mostra nada, e `echo $?` mostra um código diferente de `0`.

**Num caso real**, o nome certo se confirma com quem abriu o chamado (o endereço exato ou um print), na documentação ou no inventário de sistemas, e testando o nome completo (com o domínio), o DNS interno e um DNS público (`dig @IP nome`). `NXDOMAIN` indica que o nome não existe naquele DNS; ausência de resposta (`timed out`) indica que o próprio servidor DNS está inacessível.

### B. Apache parado

```bash
sudo systemctl stop httpd
```

```
PS> curl.exe -v http://192.168.50.10
*   Trying 192.168.50.10:80...
* connect to 192.168.50.10 port 80 from 0.0.0.0 port 53184 failed: Connection refused
* Failed to connect to 192.168.50.10:80 after 2054 ms: Could not connect to server
curl: (7) Failed to connect to 192.168.50.10:80 after 2054 ms: Could not connect to server
```

```
13:42:36.705963 IP 192.168.50.1.53184 > 192.168.50.10.http: Flags [S], seq 51038892, ...
13:42:36.706007 IP 192.168.50.10.http > 192.168.50.1.53184: Flags [R.], seq 0, ack 51038893, ...
... (repetido 5 vezes, a cada meio segundo)
```

- O servidor responde ao `[S]` com **`[R.]`** (recusa), **na hora**. Quem responde é o sistema operacional: o servidor está ligado, a rede e o firewall funcionam, mas nenhum programa escuta na porta.
- O Windows tenta 5 vezes e desiste em ~2 segundos.
- Com o Apache parado, as portas 80 e 8080 somem do `sudo ss -tlnp`.

Para voltar: `sudo systemctl start httpd` (o `restart` é para reiniciar algo que está rodando).

### C. `http` fora do firewall

```bash
sudo firewall-cmd --remove-service=http      # sem --permanent: some com o --reload
```

```
PS> curl.exe -v http://192.168.50.10
*   Trying 192.168.50.10:80...
* connect to 192.168.50.10 port 80 from 0.0.0.0 port 61966 failed: Timed out
* Failed to connect to 192.168.50.10:80 after 21061 ms: Could not connect to server
curl: (28) Failed to connect to 192.168.50.10:80 after 21061 ms: Could not connect to server
```

Com o filtro `port 80` só aparecem os `[S]` sem resposta. Para ver o aviso do firewall, é preciso incluir o ICMP no filtro:

```
$ sudo tcpdump -i eth1 -n 'port 80 or icmp'
13:50:48.516315 IP 192.168.50.1.53793 > 192.168.50.10.http: Flags [S], ...
13:50:48.516353 IP 192.168.50.10 > 192.168.50.1: ICMP host 192.168.50.10 unreachable - admin prohibited filter, length 60
13:50:49.528240 IP 192.168.50.1.53793 > 192.168.50.10.http: Flags [S], ...
13:50:49.528329 IP 192.168.50.10 > 192.168.50.1: ICMP host 192.168.50.10 unreachable - admin prohibited filter, length 60
13:50:51.530144 IP 192.168.50.1.53793 > 192.168.50.10.http: Flags [S], ...
13:50:51.530279 IP 192.168.50.10 > 192.168.50.1: ICMP host 192.168.50.10 unreachable - admin prohibited filter, length 60
13:50:55.535329 IP 192.168.50.1.53793 > 192.168.50.10.http: Flags [S], ...
13:50:55.535363 IP 192.168.50.10.http > 192.168.50.1.53793: Flags [S.], ...      ← firewall restaurado
...  HTTP: GET / HTTP/1.1  ...  HTTP: HTTP/1.1 200 OK  ...
```

- O firewall **rejeita com um aviso** ICMP (*admin prohibited filter*: bloqueado por regra do administrador). Um filtro só de porta esconde esse aviso, porque o ICMP não tem porta.
- O Windows ignora o aviso e continua tentando, com intervalos de 1, 2 e 4 segundos, até desistir em ~21 segundos (`Timed out`).
- Nessa captura, o `firewall-cmd --reload` foi rodado durante as tentativas: a regra voltou e a quarta tentativa foi atendida com `200 OK`.
- Um cliente Linux respeita o aviso ICMP e desiste na hora, com `No route to host`. A mesma falha aparece com mensagens diferentes, conforme o sistema de quem testa.

Para voltar: `sudo firewall-cmd --reload` e conferir com `sudo firewall-cmd --list-services`.

### D. Porta sem serviço

```
PS> curl.exe -v http://192.168.50.10:8081
*   Trying 192.168.50.10:8081...
* connect to 192.168.50.10 port 8081 from 0.0.0.0 port 63260 failed: Timed out
* Failed to connect to 192.168.50.10:8081 after 21072 ms: Could not connect to server
```

De fora, a falha parece a do firewall: a porta 8081 não está liberada, e o firewall barra o pacote **antes** de o sistema conferir se há um serviço nela. De dentro do servidor, onde o `localhost` não passa pelo firewall, aparece a camada de verdade:

```
$ curl -v http://localhost:8081
*   Trying [::1]:8081...
* connect to ::1 port 8081 from ::1 port 36656 failed: Conexão recusada
*   Trying 127.0.0.1:8081...
* connect to 127.0.0.1 port 8081 from 127.0.0.1 port 42466 failed: Conexão recusada
* Failed to connect to localhost port 8081 after 0 ms: Could not connect to server

$ sudo firewall-cmd --list-ports
8080/tcp
```

- O `curl` tenta primeiro o IPv6 (`::1`) e depois o IPv4, porque `localhost` tem os dois endereços.
- `sudo ss -tlnp` não mostra nada na 8081.

> ℹ️ Um teste de fora mostra só a **primeira** camada que falha. Testar de dentro (`localhost`) e de fora ajuda a separar o que é firewall do que é serviço.

### E. Arquivo sem permissão de leitura

```
$ ps -eo user,comm | grep httpd
root     httpd
apache   httpd
apache   httpd
apache   httpd
apache   httpd

$ ls -l /var/www/html/index.html
-rw-r--r--. 1 alice_estudo alice_estudo 15 out 22 11:23 /var/www/html/index.html
$ sudo chmod o-r /var/www/html/index.html
$ ls -l /var/www/html/index.html
-rw-r-----. 1 alice_estudo alice_estudo 15 out 22 11:23 /var/www/html/index.html
```

- O Apache lê os arquivos como o usuário **`apache`** (só o processo principal roda como root). Como o arquivo é de outro usuário e outro grupo, o `apache` cai no bloco dos **outros**.

```
PS> curl.exe -v http://192.168.50.10
* Established connection to 192.168.50.10 (192.168.50.10 port 80) from 192.168.50.1 port 61202
> GET / HTTP/1.1
...
< HTTP/1.1 403 Forbidden
< Server: Apache/2.4.63 (Rocky Linux)
<
<title>403 Forbidden</title>
<h1>Forbidden</h1>
<p>You don't have permission to access this resource.</p>
```

```
$ sudo tail -5 /var/log/httpd/error_log
...
[Wed Oct 28 14:03:36.653950 2026] [core:error] [pid 75727:tid 75851] (13)Permission denied: [client 192.168.50.1:61202] AH00132: file permissions deny server access: /var/www/html/index.html
```

- Desta vez a saída chega ao bloco `<`: a conexão funcionou e o Apache respondeu, recusando entregar o arquivo.
- A porta de origem do pedido (`61202`) é a mesma que aparece no log (`[client 192.168.50.1:61202]`): é assim que se liga o pedido de um usuário à linha exata do log.
- O 403 também pode ser o **SELinux** (ver o [Desafio 1.3](../../fase-1-linux/desafio-03-selinux-apache/)); nesse caso, a confirmação vem do `ausearch -m avc`.

Para voltar: `sudo chmod o+r /var/www/html/index.html` (o `curl` volta a mostrar `200 OK`).

---

## O catálogo

| # | Falha | Mensagem de erro | Camada | Comando que confirma | Como corrigir |
|---|---|---|---|---|---|
| A | Nome que não existe | `Could not resolve host` | DNS | `getent hosts`, `dig` (`NXDOMAIN`) | confirmar o nome com o solicitante ou na documentação; verificar o registro no DNS |
| B | Serviço parado | `Connection refused` (~2 s) | porta e serviço | `systemctl status`, `sudo ss -tlnp` | `sudo systemctl start` e conferir o `enable` |
| C | Serviço fora do firewall | `Timed out` (~21 s no Windows) | firewall | `firewall-cmd --list-services`, `tcpdump 'port 80 or icmp'` | `firewall-cmd --permanent --add-service=http` + `--reload` |
| D | Porta sem serviço | de fora: `Timed out`; de dentro: `Connection refused` | firewall e serviço | `sudo ss -tlnp`, `firewall-cmd --list-ports` | usar a porta certa, ou configurar o serviço e liberar a porta |
| E | Arquivo sem leitura | `403 Forbidden` | aplicação | `/var/log/httpd/error_log`, `ls -l` (e `ausearch -m avc` para o SELinux) | ajustar a permissão (`chmod o+r`) ou o dono e o grupo |

### B x C: por que a diferença importa

| | B (serviço parado) | C (firewall) |
|---|---|---|
| Resposta do servidor | `[R.]`: "não tem ninguém nesta porta" | ICMP *admin prohibited*: "bloqueado por regra" |
| O que o Windows faz | desiste rápido | insiste e espera |
| Tempo até o erro | ~2 segundos | ~21 segundos |

O usuário não envia a mensagem técnica, mas descreve o que viu:

- "Dá erro **na hora**" → o servidor responde, mas o serviço não: começar por `systemctl status` e `ss`.
- "Fica **carregando** e depois dá erro" → algo no caminho barra ou o servidor está inacessível: começar pelo firewall e pela rede.

**Regra geral:** o `curl -v` que **para no `*`** aponta para DNS, rede, firewall ou serviço; o que **chega ao `<` com erro** aponta para a aplicação.

---

## Erros que aconteceram e como foram resolvidos

| Sintoma | Causa | Correção |
|---|---|---|
| `dig` não funcionou | O pacote `bind-utils` não vem no Minimal Install | `sudo dnf install bind-utils` |
| Leitura trocada da saída do `dig` (o `172.28.64.1` lido como IP do site) | O `SERVER` é quem respondeu; o IP do site fica na `ANSWER SECTION` | Ler a linha da resposta: nome, TTL, classe, tipo, IP |
| Coluna `Process` vazia no `ss -tulnp` | Sem `sudo`, o `ss` só mostra processos do próprio usuário | `sudo ss -tulnp` |
| Na falha C, a captura só mostrou `[S]` sem resposta | O filtro `port 80` esconde o aviso ICMP do firewall | `tcpdump 'port 80 or icmp'` |
| Na falha C, o `curl` terminou com `200 OK` | O `--reload` foi rodado enquanto o `curl` ainda tentava | Esperar o `curl` desistir antes do `--reload` |
| Na falha D, o resultado esperado era `Connection refused`, mas veio `Timed out` | A porta 8081 não está liberada no firewall, que barra antes do serviço | Testar também de dentro do servidor (`curl localhost:8081`) |
