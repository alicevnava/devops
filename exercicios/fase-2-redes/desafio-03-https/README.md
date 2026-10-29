# Desafio 2.3 — HTTPS com uma CA própria

Terceiro desafio da Fase 2 (Redes e segurança) da trilha de estudos: criar uma autoridade certificadora (CA) própria, emitir um certificado para o servidor, colocar o Nginx em HTTPS, redirecionar o HTTP e fazer o Windows confiar no site, sem nenhum aviso no navegador.

**Método:** um passo por vez, `nginx -t` antes de todo `reload`, e prova do lado do cliente (Windows) e do lado da rede (`tcpdump`).

---

## Ambiente

| Item | Valor |
|---|---|
| **Servidor** | `servidor1` (Rocky Linux 10.2), IP fixo `192.168.50.10` |
| **Ponto de partida** | Proxy reverso do [Desafio 2.2](../desafio-02-proxy-reverso-nginx/): Nginx na porta 80 repassando para o Apache em `127.0.0.1:8080` |
| **Cliente** | Windows (`192.168.50.1`), PowerShell **como administrador**, `curl.exe`, Edge |
| **Nome do site** | `servidor1.estudos.local` (inventado para o laboratório, sem DNS) |

> Os valores `192.168.50.10`, `servidor1.estudos.local`, `alice_estudo` e os dados do `-subj` são da minha máquina. Troque pelos seus ao refazer.

---

## Conceitos

O **TLS** (o "S" do HTTPS) faz duas coisas:

1. **Cifra** a conversa: quem está no meio da rede não lê o conteúdo.
2. **Prova a identidade** do servidor: o cliente só aceita o certificado se ele foi **assinado por uma CA em que confia** e se o **nome** pedido está no certificado.

Qualquer um consegue criar um certificado dizendo "eu sou servidor1.estudos.local". O que faz o cliente acreditar é **quem assinou**.

```
AC Estudos (CA raiz, autoassinada)       ← o Windows precisa confiar nela
   └── assina ──► servidor1.estudos.local  ← o Nginx entrega este
```

| Termo | Significa |
|---|---|
| **CA** (autoridade certificadora) | quem assina certificados. Uma **CA raiz** é autoassinada e precisa estar instalada no cliente |
| **Chave privada** | o segredo de quem tem o certificado. Nunca sai do servidor (ou da CA) |
| **CSR** | o "pedido de certificado": chave pública + nome, enviado para a CA assinar |
| **SAN** (Subject Alternative Name) | a lista de nomes e IPs para os quais o certificado vale. Navegadores modernos olham **só** o SAN, não o CN |
| **SNI** | o nome do site que o cliente envia no começo do TLS, para o servidor escolher o certificado |
| **Revogação (CRL / OCSP)** | como a CA avisa que um certificado deixou de valer antes do vencimento |
| **301** | redirecionamento permanente: "este endereço agora é outro" |

---

## Enunciado

A equipe quer o site da equipe só em HTTPS. Não há orçamento para certificado público e o nome é interno, então a solução é uma CA própria, como as empresas fazem com a CA corporativa.

### Objetivos

1. Criar uma **CA própria** (chave + certificado raiz).
2. Gerar a **chave** e o **CSR** do servidor, com **SAN** para o nome, o nome curto e o IP.
3. **Assinar** o certificado com a CA e configurar o **Nginx na porta 443**.
4. **Redirecionar** todo o HTTP para HTTPS (301).
5. Liberar o **HTTPS no firewall**.
6. Fazer o **Windows confiar** no site: cadeado sem aviso no navegador.
7. **Inspecionar** o certificado pela linha de comando (`openssl x509` e `openssl s_client`).

### Resultado esperado

- `http://servidor1.estudos.local` → `301` para `https://servidor1.estudos.local/`.
- No Windows, `curl.exe` sem `-k` e o navegador aceitam o certificado.
- `openssl s_client` com a CA → `Verify return code: 0 (ok)`.
- Captura na porta 443 sem nada legível; na porta 80, tudo legível.

---

## Passo a passo

### 1. Criar a CA

Uma pasta só para a CA, que só o meu usuário acessa:

```bash
mkdir ~/ca
chmod 700 ~/ca
cd ~/ca
```

**Chave privada da CA** (4096 bits, porque ela vai durar anos e assinar tudo):

```bash
openssl genrsa -out ca-key.pem 4096
chmod 600 ca-key.pem
```

| Parte | O que faz |
|---|---|
| `genrsa` | gera uma chave RSA |
| `-out ca-key.pem` | arquivo de saída |
| `4096` | tamanho da chave em bits |
| `chmod 600` | só o dono lê e escreve: quem tem esta chave emite certificados "válidos" para qualquer nome |

**Certificado raiz** (autoassinado, válido por 5 anos):

```bash
openssl req -new -x509 -key ca-key.pem -out ca-cert.pem -days 1825 -subj "/C=BR/ST=DF/O=Estudos/CN=AC Estudos"
openssl x509 -noout -subject -issuer -dates -in ca-cert.pem
```

| Parte | O que faz |
|---|---|
| `req -new -x509` | cria um certificado já assinado (em vez de um pedido) |
| `-key ca-key.pem` | assina com a chave da própria CA → **autoassinado** |
| `-days 1825` | validade: 5 anos |
| `-subj "/C=BR/ST=DF/O=Estudos/CN=AC Estudos"` | identificação: país, estado, organização e nome comum |
| `x509 -noout -subject -issuer -dates` | confere o resultado: na CA raiz, `subject` e `issuer` são **iguais** |

> O OpenSSL atual já usa SHA-256 por padrão na assinatura, então não é preciso passar `-sha256`.

### 2. Chave e CSR do servidor

```bash
openssl genrsa -out servidor1-key.pem 2048
chmod 600 servidor1-key.pem
openssl req -new -key servidor1-key.pem -out servidor1.csr -subj "/C=BR/ST=DF/O=Estudos/CN=servidor1.estudos.local"
```

- `req -new` (sem `-x509`) gera um **pedido** (CSR), não um certificado.
- 2048 bits é o padrão para certificados de servidor, que são trocados com mais frequência.

O CSR não carrega o SAN. As extensões vão num arquivo à parte, `san.ext`, criado com o `vi`:

```
subjectAltName=DNS:servidor1.estudos.local,DNS:servidor1,IP:192.168.50.10
basicConstraints=CA:FALSE
keyUsage=digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
```

| Linha | Significa |
|---|---|
| `subjectAltName=...` | os nomes e o IP em que o certificado vale |
| `basicConstraints=CA:FALSE` | este certificado **não** pode assinar outros |
| `keyUsage=...` | a chave serve para assinatura e troca de chaves do TLS |
| `extendedKeyUsage=serverAuth` | serve para **servidor** TLS (não para cliente nem e-mail) |

### 3. Assinar e instalar no Nginx

**Assinar o CSR com a CA** (1 ano):

```bash
openssl x509 -req -in servidor1.csr -CA ca-cert.pem -CAkey ca-key.pem -CAcreateserial -out servidor1-cert.pem -days 365 -extfile san.ext
openssl x509 -noout -subject -issuer -dates -ext subjectAltName -in servidor1-cert.pem
```

| Parte | O que faz |
|---|---|
| `x509 -req -in servidor1.csr` | lê um pedido e transforma em certificado |
| `-CA ca-cert.pem -CAkey ca-key.pem` | quem assina: a CA |
| `-CAcreateserial` | cria o `ca-cert.srl`, que guarda o número de série do próximo certificado |
| `-extfile san.ext` | inclui as extensões (SAN etc.) |
| `x509 -noout ... -ext subjectAltName` | confere: `issuer` = AC Estudos e o SAN com os três nomes |

**Conferir a assinatura:**

```bash
openssl verify -CAfile ca-cert.pem servidor1-cert.pem
```

Resultado esperado: `servidor1-cert.pem: OK`.

**Copiar para o local padrão do Nginx no Rocky:**

```bash
sudo mkdir -p /etc/pki/nginx/private
sudo cp servidor1-cert.pem /etc/pki/nginx/server.crt
sudo cp servidor1-key.pem /etc/pki/nginx/private/server.key
sudo chmod 700 /etc/pki/nginx/private
sudo chmod 600 /etc/pki/nginx/private/server.key
sudo restorecon -Rv /etc/pki/nginx
ls -lZ /etc/pki/nginx /etc/pki/nginx/private
```

- `cp` cria arquivos novos, então o dono vira `root`, que é o que o Nginx espera.
- `restorecon -Rv` aplica o rótulo SELinux padrão da pasta (`cert_t`). Sem ele, os arquivos podem ficar com o rótulo da home (`user_home_t`) e o Nginx não consegue ler (ver [Desafio 1.3](../../fase-1-linux/desafio-03-selinux-apache/)).

**Bloco HTTPS no `/etc/nginx/conf.d/site.conf`:**

```nginx
server {
    listen 443 ssl default_server;
    server_name _;
    server_tokens off;

    ssl_certificate /etc/pki/nginx/server.crt;
    ssl_certificate_key /etc/pki/nginx/private/server.key;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

| Linha | Significa |
|---|---|
| `listen 443 ssl` | escuta na porta 443 **com TLS** |
| `ssl_certificate` | o certificado que vai para o cliente |
| `ssl_certificate_key` | a chave privada correspondente (fica só no servidor) |
| `location / { ... }` | o mesmo repasse para o Apache do Desafio 2.2: o TLS termina no Nginx |

```bash
sudo nginx -t
sudo systemctl reload nginx
```

### 4. Redirecionar HTTP → HTTPS

No bloco da porta 80, o `location / { ... }` inteiro foi trocado por uma única linha:

```nginx
server {
    listen 80 default_server;
    server_name _;
    server_tokens off;

    return 301 https://$host$request_uri;
}
```

| Parte | Significa |
|---|---|
| `return 301` | responde na hora com "mudou-se permanentemente", sem repassar ao Apache |
| `$host` | o nome que o cliente pediu (`servidor1.estudos.local`) |
| `$request_uri` | o caminho pedido (`/`, `/pagina?x=1`...): o cliente cai na mesma página, só que em HTTPS |

```bash
sudo nginx -t
sudo systemctl reload nginx
curl -v http://servidor1.estudos.local
```

```
< HTTP/1.1 301 Moved Permanently
< Server: nginx
< Location: https://servidor1.estudos.local/
```

> ⚠️ Na primeira tentativa, o `nginx -t` falhou com `unexpected "}"` na linha 7: faltava o `;` no fim do `return`. Regra: **se o `nginx -t` falhar, não dar `reload`**. Corrigir primeiro. `cat -n` mostra o arquivo com números de linha e ajuda a achar o erro.

### 5. Liberar o HTTPS no firewall

**Sintoma antes** (do Windows):

```
PS> curl.exe -v -k https://192.168.50.10
* connect to 192.168.50.10 port 443 from 0.0.0.0 port 49505 failed: Timed out
* Failed to connect to 192.168.50.10:443 after 21041 ms: Could not connect to server
```

`Timed out` em ~21 s é o sintoma de **firewall** do catálogo do [Desafio 2.1](../desafio-01-caminho-requisicao/): nenhuma resposta TCP voltou.

```bash
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload
sudo firewall-cmd --list-services
sudo firewall-cmd --info-service=https
```

| Comando | O que faz |
|---|---|
| `--permanent --add-service=https` | grava a regra que libera o serviço `https` |
| `--reload` | aplica a configuração gravada |
| `--list-services` | lista os serviços liberados |
| `--info-service=https` | mostra a porta que o serviço representa |

```
cockpit dhcpv6-client http https ssh
https
  ports: 443/tcp
```

**Depois** (ainda com `-k`, porque o Windows não confia na CA):

```
PS> curl.exe -v -k https://192.168.50.10
* Established connection to 192.168.50.10 (192.168.50.10 port 443) from 192.168.50.1 port 58642
* schannel: using IP address, SNI is not supported by OS.
< HTTP/1.1 200 OK
< Server: nginx
Site da equipe
```

- `-k` desliga **toda** a verificação do certificado. Serve só para testar se a porta responde.
- `SNI is not supported` aparece porque o acesso foi pelo IP: não há nome para enviar.
- As linhas `schannel: renegotiating` são o jeito do TLS do Windows registrar os dados de sessão do TLS 1.3. Não são erro.

### 6. Fazer o Windows confiar no site

#### 6a. O nome: arquivo `hosts`

`servidor1.estudos.local` não existe em nenhum DNS. O Windows consulta o arquivo `hosts` **antes** do DNS, então basta adicionar o nome lá. No PowerShell **como administrador** (a barra de título começa com "Administrador:"):

```powershell
Add-Content -Path C:\Windows\System32\drivers\etc\hosts -Value "192.168.50.10    servidor1.estudos.local"
Get-Content C:\Windows\System32\drivers\etc\hosts
ping servidor1.estudos.local
```

| Comando | O que faz |
|---|---|
| `Add-Content` | acrescenta uma linha **no fim** do arquivo (como o `>>` do Linux) |
| `Get-Content` | mostra o arquivo (como o `cat`) |
| `ping` | confirma a resolução: `Disparando servidor1.estudos.local [192.168.50.10]` |

> O arquivo se chama `hosts`, **sem extensão**. Salvar pelo Bloco de Notas sem ser administrador gera um `hosts.txt`, que o Windows ignora. Em empresa, quem faz este papel é um registro A no DNS (por exemplo, no DNS do Active Directory).

**Teste sem `-k`:**

```
PS> curl.exe -v https://servidor1.estudos.local
* schannel: SEC_E_UNTRUSTED_ROOT (0x80090325) - A cadeia de certificação foi emitida por uma autoridade que não é de confiança.
```

O **nome** passou (está no SAN). Falhou a **confiança**: a AC Estudos não está nas raízes do Windows.

#### 6b. A confiança: importar a CA

Copiar **somente** o `ca-cert.pem` da VM para a pasta Downloads do Windows (MobaXterm → aba **Sftp** → `/home/alice_estudo/ca/` → botão direito → **Download**).

> ⚠️ **Nunca** copiar o `ca-key.pem`. O certificado da CA é público; a chave é o que permite emitir certificados.

```powershell
certutil -addstore Root $env:USERPROFILE\Downloads\ca-cert.pem
```

| Parte | O que faz |
|---|---|
| `certutil` | ferramenta de certificados do Windows |
| `-addstore Root` | adiciona em "Autoridades de Certificação Raiz Confiáveis" do computador |
| `$env:USERPROFILE\Downloads\` | a pasta Downloads do usuário |

```
Root "Autoridades de Certificação Raiz Confiáveis"
Assinatura coincide com Chave pública
Certificado "AC Estudos" adicionado ao repositório.
CertUtil: -addstore : comando concluído com êxito.
```

`Assinatura coincide com Chave pública` confirma que é uma CA raiz autoassinada.

**Novo teste:**

```
PS> curl.exe -v https://servidor1.estudos.local
* schannel: next InitializeSecurityContext failed: CRYPT_E_NO_REVOCATION_CHECK (0x80092012) - A função de revogação não pôde verificar a revogação do certificado.
```

O erro mudou: a confiança passou. Agora o Windows quer conferir se o certificado foi **revogado**, mas o certificado não diz onde fica a lista de revogação (não há `crlDistributionPoints` no `san.ext`). O `curl.exe` trata isso como erro fatal; navegadores costumam deixar passar. No laboratório, desligar **só** essa checagem:

```
PS> curl.exe -v --ssl-no-revoke https://servidor1.estudos.local
* Established connection to servidor1.estudos.local (192.168.50.10 port 443) from 192.168.50.1 port 59584
> GET / HTTP/1.1
> Host: servidor1.estudos.local
< HTTP/1.1 200 OK
< Server: nginx
Site da equipe
```

- `--ssl-no-revoke` pula só a revogação; nome e CA continuam sendo verificados (diferente do `-k`).
- Em produção, a CA corporativa (por exemplo, AD CS) publica uma CRL e coloca o endereço em todo certificado.

**No navegador (Edge/Chrome):** `http://servidor1.estudos.local` → muda sozinho para `https://` → **cadeado sem aviso**, certificado emitido por **AC Estudos**. O Firefox usa um repositório próprio e mostraria aviso.

> Nada mudou no servidor entre o `SEC_E_UNTRUSTED_ROOT` e o sucesso. Quem mudou foi o **cliente**. Em empresa, a CA corporativa é distribuída para todas as máquinas por GPO.

### 7. Inspecionar o certificado

**O arquivo instalado no Nginx:**

```bash
openssl x509 -in /etc/pki/nginx/server.crt -noout -subject -issuer -dates -ext subjectAltName
```

| Parte | Mostra |
|---|---|
| `-noout` | não imprime o bloco `BEGIN CERTIFICATE` |
| `-subject` | **para quem** foi emitido |
| `-issuer` | **quem assinou** |
| `-dates` | validade (`notBefore` / `notAfter`) |
| `-ext subjectAltName` | os nomes e IPs do SAN |

```
subject=C=BR, ST=DF, O=Estudos, CN=servidor1.estudos.local
issuer=C=BR, ST=DF, O=Estudos, CN=AC Estudos
notBefore=Oct 28 19:22:26 2026 GMT
notAfter=Oct 28 19:22:26 2027 GMT
X509v3 Subject Alternative Name:
    DNS:servidor1.estudos.local, DNS:servidor1, IP Address:192.168.50.10
```

Subject e issuer diferentes: o certificado **não** é autoassinado.

**O que o servidor entrega pela rede:**

```bash
openssl s_client -connect 192.168.50.10:443 -servername servidor1.estudos.local -CAfile ~/ca/ca-cert.pem < /dev/null
```

| Parte | O que faz |
|---|---|
| `s_client` | cliente TLS de teste: faz o handshake e mostra tudo |
| `-servername` | envia o SNI |
| `-CAfile ~/ca/ca-cert.pem` | a CA em que confiar (o Rocky também não conhece a AC Estudos) |
| `< /dev/null` | entrada vazia, para o comando terminar sozinho |

Trechos da saída:

```
depth=1 C=BR, ST=DF, O=Estudos, CN=AC Estudos
verify return:1
depth=0 C=BR, ST=DF, O=Estudos, CN=servidor1.estudos.local
verify return:1
---
Certificate chain
 0 s:C=BR, ST=DF, O=Estudos, CN=servidor1.estudos.local
   i:C=BR, ST=DF, O=Estudos, CN=AC Estudos
   a:PKEY: RSA, 2048 (bit); sigalg: sha256WithRSAEncryption
---
Negotiated TLS1.3 group: X25519MLKEM768
New, TLSv1.3, Cipher is TLS_AES_256_GCM_SHA384
Protocol: TLSv1.3
This TLS version forbids renegotiation.
Verify return code: 0 (ok)
```

| Linha | Significa |
|---|---|
| `depth=1` / `depth=0` | a cadeia verificada: a CA (nível 1) assina o servidor (nível 0) |
| `Certificate chain` só com o `0` | o servidor manda só o próprio certificado; a CA raiz **nunca** vai pela rede, o cliente já precisa tê-la |
| `TLSv1.3` + `TLS_AES_256_GCM_SHA384` | versão mais nova do TLS, dados cifrados com AES-256 |
| `X25519MLKEM768` | troca de chaves **híbrida pós-quântica** (clássica + ML-KEM), padrão no OpenSSL do Rocky 10 |
| `Verify return code: 0 (ok)` | verificação completa sem erro |

---

## Testes

**1. Sem a CA, a verificação falha:**

```
$ openssl s_client -connect 192.168.50.10:443 -servername servidor1.estudos.local < /dev/null | grep "Verify return code"
depth=0 C=BR, ST=DF, O=Estudos, CN=servidor1.estudos.local
verify error:num=20:unable to get local issuer certificate
verify return:1
depth=0 C=BR, ST=DF, O=Estudos, CN=servidor1.estudos.local
verify error:num=21:unable to verify the first certificate
verify return:1
Verify return code: 21 (unable to verify the first certificate)
```

- Erro 20: o emissor (AC Estudos) não está nas CAs do sistema. Só aparece `depth=0`, porque a CA nunca entra na cadeia.
- Erro 21: por isso, nem o primeiro certificado pode ser validado.
- O `s_client` registra o erro e continua (`verify return:1`), porque é ferramenta de diagnóstico. O curl e o navegador param na hora.

**2. HTTPS: ninguém lê a conversa.** Na VM, `sudo tcpdump -i any -A port 443`; no Windows, `curl.exe --ssl-no-revoke https://servidor1.estudos.local`:

```
IP DESKTOP-DD357FU.64001 > servidor1.estudos.local.https: Flags [S], ...
IP servidor1.estudos.local.https > DESKTOP-DD357FU.64001: Flags [S.], ...
IP DESKTOP-DD357FU.64001 > servidor1.estudos.local.https: Flags [P.], seq 1:462, ack 1, win 255, length 461
.       .........=.<.5./...S.........servidor1.estudos.local.+..........
.....................   .http/1.1.3....... ..E..Z...5,\...CZk3dKh.. ......
IP servidor1.estudos.local.https > DESKTOP-DD357FU.64001: Flags [P.], seq 1:1831, ack 462, win 501, length 1830
.z...v..N.Z~T..S.\...'.[[..Tc*..FK.....& ..P.F.BU.W.#."n..........
```

- `-A` mostra o conteúdo dos pacotes como texto.
- Nenhum `GET`, `Host:` ou `Site da equipe` legível.
- **Mas** `servidor1.estudos.local` e `http/1.1` aparecem no primeiro pacote (ClientHello): são o **SNI** e o **ALPN**, que vão em texto puro. Quem está no meio da rede não vê o conteúdo, mas vê **qual site** foi acessado. A extensão ECH (Encrypted Client Hello) existe para cifrar isso também.

**3. HTTP: tudo legível.** `sudo tcpdump -i any -A port 80`; no Windows, `curl.exe -v http://servidor1.estudos.local`:

```
IP DESKTOP-DD357FU.51411 > servidor1.estudos.local.http: Flags [P.], seq 1:88, ack 1, win 255, length 87: HTTP: GET / HTTP/1.1
..GET / HTTP/1.1
Host: servidor1.estudos.local
User-Agent: curl/8.21.0
Accept: */*

IP servidor1.estudos.local.http > DESKTOP-DD357FU.51411: Flags [P.], seq 1:363, ack 88, win 502, length 362: HTTP: HTTP/1.1 301 Moved Permanently
HTTP/1.1 301 Moved Permanently
Server: nginx
Location: https://servidor1.estudos.local/
```

| | Porta 80 (HTTP) | Porta 443 (HTTPS) |
|---|---|---|
| Requisição | `GET`, `Host`, `User-Agent` legíveis | ilegível |
| Resposta | `301`, `Location` e o HTML legíveis | ilegível |
| O que vaza | **tudo** | só o nome do site (SNI) |

O primeiro pedido, antes do 301, sempre sai em texto puro. O cabeçalho **HSTS** existe para que o navegador vá direto para o HTTPS nas próximas visitas.

---

## Erros que aconteceram e como foram resolvidos

| Sintoma | Causa | Correção |
|---|---|---|
| `openssl: comando não encontrado` | A instalação mínima do Rocky traz só a biblioteca (`openssl-libs`), não a ferramenta de linha de comando | `sudo dnf install -y openssl` |
| Arquivo `ca-key.pem4096` criado | Faltou o espaço entre o nome do arquivo e o tamanho da chave | `openssl genrsa -out ca-key.pem 4096` |
| Arquivos da CA fora de `~/ca` | Foram criados antes de a pasta existir | `mkdir ~/ca` primeiro e mover os arquivos com `mv` |
| `genrasa`, `-subj` sem valor, `- CAcreateserial` | Erros de digitação | Conferir o comando antes de dar Enter; ler a mensagem de erro do `openssl` |
| `nginx -t` falhou por causa do `______` deixado no arquivo; o `reload` foi feito mesmo assim | O espaço em branco do exercício ficou na configuração | O `reload` falhou de forma segura (o Nginx continuou com a configuração anterior). Regra: **só dar `reload` se o `nginx -t` passar** |
| `unexpected "}" in /etc/nginx/conf.d/site.conf:7` | Faltou o `;` no fim do `return 301 ...` | `cat -n` para achar a linha e acrescentar o `;` |
| `Timed out` em ~21 s na porta 443 | O firewall não liberava o `https` | `firewall-cmd --permanent --add-service=https` + `--reload` |
| Bloco de Notas tentou salvar `hosts.txt` e pediu permissão | Bloco de Notas sem administrador e tipo "Documentos de texto (*.txt)" | `Add-Content` no PowerShell como administrador |
| `SEC_E_UNTRUSTED_ROOT` | O Windows não confiava na AC Estudos | `certutil -addstore Root ca-cert.pem` |
| `CRYPT_E_NO_REVOCATION_CHECK` | O certificado não tem endereço de CRL, e o `curl.exe` (schannel) exige a checagem | `--ssl-no-revoke` no laboratório; em produção, a CA publica uma CRL |
| `tcpdump port 80` não capturou nada | O teste do Windows foi feito com `https://` (porta 443) | Testar com `http://` |

---

## Como desfazer no Windows

```powershell
certutil -delstore Root "AC Estudos"
```

E apagar a linha `servidor1.estudos.local` do `C:\Windows\System32\drivers\etc\hosts`.

---

## Resumo

- Certificado = chave pública + nome, **assinado** por uma CA. O cliente confere **duas coisas**: o nome está no SAN? Quem assinou é uma CA confiável?
- Fluxo: chave da CA → certificado raiz → chave do servidor → CSR → assinar com `-extfile` (SAN) → `openssl verify`.
- A chave privada da CA é o bem mais valioso: `chmod 600`, pasta `700`, nunca copiada para lugar nenhum.
- Nginx: `listen 443 ssl` + `ssl_certificate` + `ssl_certificate_key`; arquivos em `/etc/pki/nginx` com `restorecon`. `return 301 https://$host$request_uri` no bloco da porta 80.
- `nginx -t` falhou → não dar `reload`.
- No cliente: o nome (DNS ou `hosts`) e a confiança (CA nas raízes). `-k` desliga tudo; `--ssl-no-revoke` desliga só a revogação.
- `openssl x509` lê um arquivo de certificado; `openssl s_client` mostra o que o servidor entrega de verdade.
- HTTPS esconde o conteúdo, mas não o nome do site (SNI).
