# Desafio 3.3 — Texto no terminal: o que o log do Nginx conta

Terceiro desafio da Fase 3 (Git, Bash e Python) da trilha de estudos: responder perguntas sobre o tráfego do site lendo o **log de acesso do Nginx** com `awk`, `sort`, `uniq`, `head` e `wc`, encadeados por pipes, e transformar as respostas num script que recebe o log como argumento.

**Script final:** [`scripts/analisa-log.sh`](../../../scripts/analisa-log.sh)

**Método:** montar cada pipe **uma peça por vez**: rodar, olhar a saída, só então acrescentar o próximo `| comando`.

---

## Ambiente

| Item | Valor |
|---|---|
| **Servidor** | `servidor1` (Rocky Linux 10.2), Nginx dos [Desafios 2.2 a 2.4](../../fase-2-redes/) |
| **Log** | `/var/log/nginx/access.log` (só o root lê), analisado numa cópia em `~/access.log` |
| **Repositório** | `~/repos/devops`, configurado no [Desafio 3.1](../desafio-01-git/) |

---

## Enunciado

"Quem mais acessa o site? Estamos tendo muitos erros? Alguém está tentando entrar em páginas que não existem?" As respostas estão no log, uma linha por pedido.

### Objetivos

1. Entender o formato de uma linha do log: qual campo é o IP, o caminho, o código HTTP.
2. Gerar tráfego variado: páginas que existem e que não existem, do Windows e da própria VM.
3. Contar os pedidos.
4. Listar os IPs que mais acessam.
5. Contar os pedidos de cada código HTTP.
6. Listar só os erros (4xx e 5xx) e as páginas que os causaram.
7. Mostrar as páginas mais pedidas.

**Bônus:** um script, `scripts/analisa-log.sh`, que recebe o arquivo de log como argumento, entregue por pull request.

---

## Passo a passo

### 1. Gerar tráfego

Na `servidor1` (em qualquer pasta: o resultado vai para o log do Nginx):

```bash
for i in 1 2 3 4 5 6 7 8; do curl -k -s -o /dev/null https://localhost/; done
for pagina in /admin /login /wp-admin /.env /backup.zip; do curl -k -s -o /dev/null https://localhost$pagina; done
```

| Parte | O que faz |
|---|---|
| `for ... do ... done` | o `for` do [Desafio 3.2](../desafio-02-bash-verifica-servicos/), numa linha só |
| `curl -k -s -o /dev/null` | pedido silencioso (`-s`), página descartada (`-o /dev/null`) |
| `/admin /login /wp-admin /.env /backup.zip` | imitação de um robô procurando falhas, o que acontece o tempo todo em servidores na internet |

No Windows (PowerShell), para aparecer um segundo IP, um 404 e um 301:

```powershell
curl.exe --ssl-no-revoke -s -o NUL https://servidor1.estudos.local/
curl.exe --ssl-no-revoke -s -o NUL https://servidor1.estudos.local/
curl.exe --ssl-no-revoke -s -o NUL https://servidor1.estudos.local/nao-existe
curl.exe -s -o NUL http://servidor1.estudos.local/
```

`NUL` é o `/dev/null` do Windows.

### 2. Uma cópia do log

```bash
sudo cp /var/log/nginx/access.log ~/access.log
sudo chown alice_estudo: ~/access.log
tail -3 ~/access.log
```

```
192.168.50.1 - - [04/Nov/2026:09:08:27 -0300] "GET / HTTP/1.1" 200 15 "-" "curl/8.21.0" "-"
192.168.50.1 - - [04/Nov/2026:09:08:31 -0300] "GET /nao-existe HTTP/1.1" 404 196 "-" "curl/8.21.0" "-"
192.168.50.1 - - [04/Nov/2026:09:08:35 -0300] "GET / HTTP/1.1" 301 162 "-" "curl/8.21.0" "-"
```

- O log é `-rw-r-----`: "outros" não leem. Na cópia, não é preciso `sudo` a cada comando, e o log verdadeiro não é tocado.
- `chown alice_estudo:` (com o `:` sem nada depois) troca o dono e o grupo para o grupo principal do usuário.

### 3. Os campos

O `awk` corta cada linha em **todo espaço** e numera os pedaços (**campos**): `$1` é o primeiro, `$7` o sétimo. Para ver os pedaços de uma linha:

```bash
tail -1 ~/access.log | tr ' ' '\n' | cat -n
```

```
     1  192.168.50.1
     2  -
     3  -
     4  [04/Nov/2026:09:08:35
     5  -0300]
     6  "GET
     7  /
     8  HTTP/1.1"
     9  301
    10  162
    11  "-"
    12  "curl/8.21.0"
    13  "-"
```

`tr ' ' '\n'` troca cada espaço por uma quebra de linha; `cat -n` numera.

| Nº | O que é |
|---|---|
| **1** | **IP** de quem pediu |
| 2, 3 | identidade e usuário (quase sempre `-`) |
| **4** | **data e hora** (o `[` vem grudado) |
| 5 | fuso horário |
| 6 | método (`"GET`, com a aspa grudada) |
| **7** | **caminho pedido** |
| 8 | protocolo |
| **9** | **código HTTP** |
| **10** | tamanho da resposta em bytes |
| 11 | *referer*: de qual página veio o clique |
| 12 | *user agent*: qual programa pediu |
| 13 | `X-Forwarded-For` (o formato padrão do Nginx no Rocky acrescenta no fim) |

```
$ awk '{print $9}' ~/access.log | tail -3
200
404
301
```

`$1`, `$9` etc. dentro do `awk` são **campos**, não variáveis do Bash; por isso o programa vai entre aspas **simples**.

### 4. Quantos pedidos e quem mais acessa

```bash
wc -l ~/access.log
```

O pipe dos IPs, montado peça por peça:

```bash
awk '{print $1}' ~/access.log | head                              # só os IPs
awk '{print $1}' ~/access.log | sort | head                       # iguais lado a lado
awk '{print $1}' ~/access.log | sort | uniq -c                    # conta cada grupo
awk '{print $1}' ~/access.log | sort | uniq -c | sort -rn         # do maior para o menor
```

| Comando | O que faz |
|---|---|
| `sort` | ordena: iguais ficam vizinhos |
| `uniq -c` | junta linhas iguais **vizinhas** e conta |
| `sort -rn` | ordena como **número** (`-n`; sem ele, `10` viria antes de `9`) e do maior para o menor (`-r`) |

**Por que o `sort` antes do `uniq`:** o `uniq` só junta linhas **coladas**.

```
$ printf "A\nB\nA\nA\nB\n" | uniq -c
      1 A
      1 B
      2 A
      1 B
$ printf "A\nB\nA\nA\nB\n" | sort | uniq -c
      3 A
      2 B
```

No log, a primeira tentativa sem `sort` deu o resultado certo por coincidência (os pedidos de cada IP estavam agrupados). Depois de um pedido novo da `servidor1`, a diferença apareceu:

```
$ awk '{print $1}' ~/access.log | uniq -c
     13 127.0.0.1
      4 192.168.50.1
      1 127.0.0.1
$ awk '{print $1}' ~/access.log | sort | uniq -c
     14 127.0.0.1
      4 192.168.50.1
```

### 5. Códigos HTTP

```
$ awk '{print $9}' ~/access.log | sort | uniq -c | sort -rn
     11 200
      6 404
      1 301
```

11 + 6 + 1 = 18, o mesmo total do `wc -l`: conferir a soma ajuda a pegar filtros errados.

### 6. Só os erros

```bash
awk '$9 >= 400' ~/access.log
awk '$9 >= 400 {print $9, $7}' ~/access.log
awk '$9 >= 400' ~/access.log | wc -l
```

```
404 /admin
404 /login
404 /wp-admin
404 /.env
404 /backup.zip
404 /nao-existe

6
```

| Parte | O que faz |
|---|---|
| `$9 >= 400` antes das chaves | **filtro**: só passam as linhas com código 400 ou mais (4xx = erro do cliente, 5xx = erro do servidor) |
| sem ação | o `awk` imprime a linha inteira |
| `{print $9, $7}` | só código e caminho; a vírgula põe um espaço entre eles |

### 7. Páginas mais pedidas

```
$ awk '{print $7}' ~/access.log | sort | uniq -c | sort -rn | head -5
     12 /
      1 /wp-admin
      1 /nao-existe
      1 /login
      1 /.env
```

O `/` tem 12: os 11 com 200 mais o 301 do `http://`. No `sort` em português a pontuação é ignorada na ordenação: `/.env` fica entre `/backup.zip` e `/login`.

---

## Bônus: `scripts/analisa-log.sh`

```bash
#!/bin/bash
# Gera um relatório a partir de um log de acesso do Nginx.
# Uso: analisa-log.sh <arquivo de log>

if [ "$#" -ne 1 ]; then
    echo "Uso: $0 <arquivo de log>"
    exit 1
fi

log="$1"

if [ ! -f "$log" ]; then
    echo "Arquivo não encontrado: $log"
    exit 1
fi

echo "Total de pedidos:"
wc -l < "$log"

echo "IPs que mais acessam:"
awk '{print $1}' "$log" | sort | uniq -c | sort -rn | head -5

echo "Códigos HTTP:"
awk '{print $9}' "$log" | sort | uniq -c | sort -rn

echo "Páginas mais pedidas:"
awk '{print $7}' "$log" | sort | uniq -c | sort -rn | head -5

echo "Erros (4xx e 5xx):"
awk '$9 >= 400 {print $9, $7}' "$log"
```

| Trecho | O que faz |
|---|---|
| `[ "$#" -ne 1 ]` | se não vier exatamente um argumento (`-ne` = diferente): mensagem de uso e `exit 1` |
| `$0` | o nome do próprio script, como foi chamado |
| `log="$1"` | o primeiro argumento, com um nome que diz o que é |
| `[ ! -f "$log" ]` | se **não** (`!`) existe um arquivo (`-f`) com esse nome: `exit 1` |
| `wc -l < "$log"` | com `<`, o arquivo entra pela entrada do `wc`, que mostra só o número |
| `head -5` | num log real, as listas seriam enormes |

### Testes

```
$ ./scripts/analisa-log.sh ~/access.log
Total de pedidos:
18
IPs que mais acessam:
     14 127.0.0.1
      4 192.168.50.1
Códigos HTTP:
     11 200
      6 404
      1 301
Páginas mais pedidas:
     12 /
      1 /wp-admin
      1 /nao-existe
      1 /login
      1 /.env
Erros (4xx e 5xx):
404 /admin
404 /login
404 /wp-admin
404 /.env
404 /backup.zip
404 /nao-existe
$ echo $?
0

$ ./scripts/analisa-log.sh
Uso: ./scripts/analisa-log.sh <arquivo de log>
$ echo $?
1

$ ./scripts/analisa-log.sh /tmp/nao-existe.log
Arquivo não encontrado: /tmp/nao-existe.log
$ echo $?
1
```

### O mesmo script, outro log

O Rocky faz rotação dos logs (`logrotate`): o `access.log` é renomeado com a data e um novo começa.

```
$ sudo ls -l /var/log/nginx/
-rw-r-----. 1 nginx root  1663 nov  4 09:32 access.log
-rw-r--r--. 1 root  root  6376 out 29 14:17 access.log-20261030
```

```
$ ./scripts/analisa-log.sh ~/access-antigo.log
Total de pedidos:
66
IPs que mais acessam:
     48 127.0.0.1
     16 192.168.50.1
      2 192.168.50.10
Códigos HTTP:
     58 200
      3 502
      3 301
      1 404
      1 304
Páginas mais pedidas:
     65 /
      1 /favicon.ico
Erros (4xx e 5xx):
502 /
404 /favicon.ico
502 /
502 /
```

| O que apareceu | De onde veio |
|---|---|
| 3 × `502` | o SELinux barrando o Nginx no [Desafio 2.2](../../fase-2-redes/desafio-02-proxy-reverso-nginx/) e os dois backends derrubados no [Desafio 2.4](../../fase-2-redes/desafio-04-balanceamento/) |
| 3 × `301` | o redirecionamento HTTP → HTTPS do [Desafio 2.3](../../fase-2-redes/desafio-03-https/) |
| `404 /favicon.ico` | o navegador pedindo o ícone da aba, que o site não tem |
| `304` | *Not Modified*: o navegador usou a cópia em cache |
| `192.168.50.10` | pedidos de dentro da `servidor1` usando o IP dela |

### Entrega

Linha nova no [`scripts/README.md`](../../../scripts/README.md), `git add`, `git commit`, `git push -u origin script-analisa-log`, pull request, **Merge** (conferindo o "Merged"), **Delete branch**, e na `servidor1`:

```
$ git log --oneline --graph -3
*   4e75816 (HEAD -> main, origin/main, origin/HEAD) Merge pull request #5 from alicevnava/script-analisa-log
|\
| * a94f244 Adiciona o script analisa-log.sh
|/
*   ee8cfa5 Merge pull request #4 from alicevnava/docs-desafio-3-2
```

---

## Erros que aconteceram e como foram resolvidos

| Sintoma | Causa | Correção |
|---|---|---|
| `awk '{print $_}'` mostrou as linhas inteiras | O `_` era uma lacuna. No `awk`, `_` é uma variável sem valor (= 0), e `$0` é a linha inteira | `$9` (o código HTTP) |
| `uniq -c` sem `sort` deu o resultado certo | Coincidência: os pedidos de cada IP estavam agrupados no log | Um pedido novo misturou a ordem e mostrou o erro; regra: sempre `sort \| uniq -c` |

---

## Resumo

- O `awk` divide cada linha pelos espaços: `$1`, `$7`, `$9`... (`$0` = a linha toda). `tail -1 arquivo | tr ' ' '\n' | cat -n` mostra o número de cada campo.
- Contagem por valor: `awk '{print $N}' | sort | uniq -c | sort -rn | head`.
- O `uniq` só junta vizinhos: `sort` antes, sempre.
- Filtro no `awk`: condição antes das chaves (`'$9 >= 400 {print $9, $7}'`).
- `wc -l` conta linhas; `wc -l < arquivo` mostra só o número.
- Conferir que as partes somam o total.
- Script com argumento: validar `$#` e `[ -f ]` antes de usar, com mensagem e `exit 1`. O mesmo script serve para qualquer log.
