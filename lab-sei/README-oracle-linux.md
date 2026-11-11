# Laboratório SEI/SIP 4.0 em Oracle Linux 8

Instalação completa do **SEI** (Sistema Eletrônico de Informações) e do **SIP** (Sistema de Permissões) versão **4.0.12.15** em uma única VM **Oracle Linux 8.10**, seguindo o manual oficial `INSTALACAO 4.0.12.15.md`.

Este documento é a adaptação do [passo a passo para Amazon Linux 2](README.md) para o Oracle Linux 8. A comparação etapa por etapa está em [diferencas/aws-vs-oracle-linux.md](diferencas/aws-vs-oracle-linux.md).

> Objetivo deste documento: permitir que qualquer pessoa **replique o laboratório do zero apenas seguindo este passo a passo**.

## Sumário

- [Visão geral](#visão-geral)
- [Pré-requisitos](#pré-requisitos)
- [Variáveis do ambiente](#variáveis-do-ambiente)
- [Etapa 1 - Preparação](#etapa-1---preparação)
- [Etapa 2 - Pacote do SEI](#etapa-2---pacote-do-sei)
- [Etapa 3 - Apache](#etapa-3---apache)
- [Etapa 4 - PHP 7.3 e extensões](#etapa-4---php-73-e-extensões)
- [Etapa 5 - Memcached](#etapa-5---memcached)
- [Etapa 6 - Banco de dados (MySQL 8.0)](#etapa-6---banco-de-dados-mysql-80)
- [Etapa 7 - Permissões e publicação no Apache](#etapa-7---permissões-e-publicação-no-apache)
- [Etapa 8 - Configurar o SIP](#etapa-8---configurar-o-sip)
- [Etapa 9 - Configurar o SEI](#etapa-9---configurar-o-sei)
- [Etapa 10 - Acesso pelo navegador e primeiro login](#etapa-10---acesso-pelo-navegador-e-primeiro-login)
- [Etapa 11 - Solr](#etapa-11---solr)
- [Etapa 12 - Agendamentos](#etapa-12---agendamentos)
- [Etapa 13 - HTTPS](#etapa-13---https)
- [Etapa 14 - Finalização e validação](#etapa-14---finalização-e-validação)
- [Testes como usuário](#testes-como-usuário)
- [Problemas e soluções](#problemas-e-soluções)
- [Adaptações em relação ao manual](#adaptações-em-relação-ao-manual)
- [Pontos de melhoria](#pontos-de-melhoria)
- [Referências](#referências)

---

## Visão geral

### Arquitetura

Tudo roda na mesma VM. No manual (pensado para produção) cada serviço fica em um servidor separado.

| Serviço | Função | Porta | Configuração |
| --- | --- | --- | --- |
| Apache 2.4 | Servidor web: recebe o navegador e entrega as páginas | 80 / 443 | `/etc/httpd/conf.d/sei.conf` |
| PHP 7.3 (php-fpm) | Executa o código do SEI, do SIP e do InfraPHP | — | `/etc/php.d/99-sei.ini` |
| SIP | Login, usuários, perfis, unidades e permissões | — | `/opt/sip/config/ConfiguracaoSip.php` |
| SEI | Processos e documentos | — | `/opt/sei/config/ConfiguracaoSEI.php` |
| MySQL 8.0 | Bases `sei` e `sip` | 3306 | `/etc/my.cnf.d/99-sei.cnf` |
| Memcached | Cache de sessões e permissões | 11211 (só local) | `/etc/sysconfig/memcached` |
| Solr 8.2.0 (Java 8) | Indexação e pesquisa | 8983 (só 127.0.0.1) | `/opt/solr`, `/dados` |
| Cron | Agendamentos e limpeza | — | `/etc/cron.d/sei-*` |
| Repositório de arquivos | Documentos anexados | — | `/var/sei/arquivos` |
| SELinux (`Enforcing`) | Controla o que o Apache pode ler, gravar e acessar | — | booleans e rótulos (Etapas 1 e 9) |

### Fluxo de um login

1. O navegador acessa o SEI pelo Apache, que repassa ao PHP.
2. O SEI redireciona para o login do **SIP**.
3. O SIP confere o usuário na base `sip` e redireciona de volta ao SEI.
4. O SEI confirma o login chamando o **web service do SIP**.
5. As permissões ficam guardadas no **Memcached**.
6. O SEI lê e grava na base `sei` e envia os documentos ao **Solr** para indexação.

### Resultado esperado

- SEI e SIP acessíveis pelo navegador, com login funcionando
- Banco conectado, Memcached operacional e Solr respondendo às pesquisas
- Arquivos, permissões e rótulos do SELinux conforme esta documentação
- Agendamentos rodando e HTTPS ativo no servidor

---

## Pré-requisitos

| Item | Exigência |
| --- | --- |
| Sistema operacional | Oracle Linux 8 (`cat /etc/os-release`). Testado na versão 8.10 |
| Recursos | Mínimo 4 GB de RAM, 2 CPUs e 20 GB de disco (2 GB livres em `/tmp`). A VM do laboratório tinha 7,5 GiB de RAM, 2 CPUs e cerca de 24 GB livres |
| Acesso | SSH com o usuário `opc` e permissão de `sudo` |
| SELinux | `Enforcing` (padrão). **Não desativar**: esta documentação o configura |
| Firewall | `firewalld` ativo, liberando só o `ssh` (padrão da imagem) |
| Navegador | Túnel SSH do MobaXterm para a porta 80 da VM (ver [Etapa 10](#etapa-10---acesso-pelo-navegador-e-primeiro-login)) |
| Internet | Repositórios do Oracle Linux, PECL e `archive.apache.org` (Solr) |
| Pacote do SEI | `/opt/sei-lab/sei-4.0.12.15.zip` |
| Manual | `/opt/sei-lab/INSTALACAO 4.0.12.15.md` |

A pasta `/opt/sei-lab/` também traz um `README.txt` do bootstrap da VM, que só confirma a cópia do pacote e do manual.

Downloads externos usados (autorizados pelo responsável do laboratório):

| O quê | Origem |
| --- | --- |
| Extensão memcache 4.0.5.2 | PECL (`pecl install`) |
| Extensão igbinary | PECL (`pecl install`) |
| Solr 8.2.0 | `https://archive.apache.org/dist/lucene/solr/8.2.0/solr-8.2.0.tgz` |
| Hash do Solr | `https://archive.apache.org/dist/lucene/solr/8.2.0/solr-8.2.0.tgz.sha512` |

> Diferente da versão para Amazon Linux 2, aqui **não há repositório externo do MySQL**: o MySQL 8.0, o PHP 7.3 e o Java 8 vêm dos repositórios do próprio Oracle Linux.

---

## Variáveis do ambiente

Nos comandos abaixo, **troque os marcadores** pelos valores do seu ambiente.

| Marcador | Significado | Exemplo |
| --- | --- | --- |
| `SEU_ENDERECO` | Endereço usado pelo navegador **e** pela própria VM. Neste laboratório: `localhost` | `localhost` |
| `SUA_SIGLA` | Sigla do órgão (maiúsculas, sem espaço e sem acento) | `TRAINEE02` |
| `SUA_DESCRICAO` | Nome do órgão (sem acento) | `Laboratorio Trainee 02` |
| `SENHA_SEI_USER` | Senha do usuário de banco do sistema | escolha uma senha forte, **sem** `'`, `\`, `/` nem `&` |
| `IP_PRIVADO_DA_VM` | IP privado da VM (`ip -4 addr show`) | `10.x.x.x` |

> Por que `localhost`: o navegador chega à VM por um túnel SSH, então `localhost` no computador do usuário é a porta 80 da VM. E dentro da VM, `localhost` é o próprio Apache, o que permite ao SEI chamar o SIP. Os dois lados usam o mesmo endereço, que é o que a documentação exige. Se a sua VM tiver um DNS próprio, use-o no lugar.
>
> O nome da VM (`hostname -f`) **não serve** como endereço: neste ambiente ele resolve só para um endereço IPv6 local (`fe80::...`).

Dicas gerais:

- Rode **um comando por vez** e confira a saída antes de seguir.
- No vim: `i` edita, `Esc` sai da edição, `:wq` salva e sai, `:q!` sai sem salvar, `u` desfaz. **Nunca use Ctrl+Z** (pausa o vim).
- Antes de colar um bloco no vim, digite `:set paste`.
- Para trocar um texto numa linha no vim: `Esc` e depois `:NUMERO s/antigo/novo/` com Enter (por exemplo, `:21s/true/false/`). Depois do `:wq`, **sempre confira com `grep`**: se o comando não for aplicado, o arquivo fica como estava.
- Depois de editar qualquer `.php`, confira com `sudo php -l ARQUIVO`.
- **Não use `sudo` em comandos que gravam na sua pasta pessoal (`~`)**: os arquivos ficam do `root` e os próximos comandos sem `sudo` dão `Permission denied`. Se acontecer: `sudo chown -R opc:opc ~/PASTA`.
- No `grep` dos arquivos `.php` do SEI pode aparecer `Binary file ... matches` no final: é normal, os arquivos usam a codificação ISO-8859-1.

---

## Etapa 1 - Preparação

Conferir o sistema (deve ser Oracle Linux 8, que usa `dnf`):

```bash
cat /etc/os-release
```

Conferir memória, disco e CPU:

```bash
free -h
df -h
nproc
```

Atualizar os pacotes:

```bash
sudo dnf update -y
```

Esperado: `Complete!` (ou `Nothing to do.`). Se aparecer `Waiting for process with pid NNNN to finish.`, outro `dnf` (atualização automática de cache) está rodando: **espere**, não use `kill`.

Instalar utilitários (descompactar, editar, testar URLs e portas, ver árvore de pastas):

```bash
sudo dnf install -y unzip tar vim-enhanced curl wget tree nmap-ncat
which unzip vim tree nc wget
```

Esperado: cinco caminhos em `/usr/bin/`. No Oracle Linux o vim completo é o pacote `vim-enhanced`.

### SELinux

Ver o modo:

```bash
getenforce
```

Esperado neste laboratório: `Enforcing`. Então os parâmetros abaixo são **obrigatórios**. O manual os traz na seção 2 (em `/opt/sei-lab/INSTALACAO 4.0.12.15.md`, perto da linha 157):

```bash
grep -n -i selinux "/opt/sei-lab/INSTALACAO 4.0.12.15.md"
sed -n '155,175p' "/opt/sei-lab/INSTALACAO 4.0.12.15.md"
```

> No manual os comandos vêm colados na mesma linha e com `–P` (traço longo). Digite **um por linha** e com `-P` (hífen normal).

| Parâmetro | Para que serve |
| --- | --- |
| `httpd_can_network_connect` | O Apache/PHP abrir conexões de rede (SEI chamando o SIP e o Solr) |
| `httpd_can_network_memcache` | Acessar o Memcached |
| `httpd_execmem` | O PHP usar memória executável |
| `httpd_can_connect_ldap` | Conectar em LDAP/AD |
| `httpd_use_nfs` | Usar pastas em NFS |
| `httpd_can_network_connect_db` | Conectar no banco de dados |

Ver o estado atual (todos vêm `off`):

```bash
getsebool httpd_can_network_connect httpd_can_network_memcache httpd_execmem httpd_can_connect_ldap httpd_use_nfs httpd_can_network_connect_db
```

Ligar, um por vez (cada um demora de 20 a 60 segundos e **não mostra mensagem**; não use Ctrl+C):

```bash
sudo setsebool -P httpd_can_network_connect 1
sudo setsebool -P httpd_can_network_memcache 1
sudo setsebool -P httpd_execmem 1
sudo setsebool -P httpd_can_connect_ldap 1
sudo setsebool -P httpd_use_nfs 1
sudo setsebool -P httpd_can_network_connect_db 1
```

Conferir com o mesmo `getsebool` de cima. Esperado: seis linhas com `--> on`. O `-P` torna a mudança permanente (sobrevive ao reboot).

> O manual avisa que "eventualmente poderá ser necessária alteração de outros parâmetros". Os rótulos de gravação das pastas `temp` e do repositório de arquivos estão na [Etapa 9](#rótulos-do-selinux-para-gravação).

Ler o manual (sumário pelos títulos):

```bash
cd /opt/sei-lab
grep -n '^#' "INSTALACAO 4.0.12.15.md"
less "INSTALACAO 4.0.12.15.md"
```

No `less`: setas rolam, `Espaço` avança, `b` volta, `/texto` procura (a partir de onde você está) e `q` sai.

---

## Etapa 2 - Pacote do SEI

Ver o conteúdo do pacote sem extrair:

```bash
unzip -l /opt/sei-lab/sei-4.0.12.15.zip
```

Esperado: `NOTA_VERSAO.md`, `sei-Fontes-4.0.12.15.zip` e os dumps `sei-bd-mysql`, `sei-bd-oracle` e `sei-bd-sqlserver`.

Extrair em uma pasta de trabalho (**sem `sudo`**, na sua pasta pessoal):

```bash
mkdir -p ~/sei-pacote
unzip -q /opt/sei-lab/sei-4.0.12.15.zip -d ~/sei-pacote
ls ~/sei-pacote
```

> Cuidado com o `~`: `mkdir -p /sei-pacote` (sem o `~`) tenta criar a pasta na raiz do sistema e dá `Permission denied`. Se criar com `sudo` por engano: `sudo chown -R opc:opc ~/sei-pacote` e `sudo rmdir /sei-pacote`.

Extrair só os fontes e o dump do MySQL:

```bash
unzip -q ~/sei-pacote/sei-Fontes-4.0.12.15.zip -d ~/sei-pacote/fontes
unzip -q ~/sei-pacote/sei-bd-mysql-4.0.12.15.zip -d ~/sei-pacote/bd
ls ~/sei-pacote/fontes ~/sei-pacote/bd
```

Esperado: `infra sei sip` e os arquivos `sei_4.0.x.1_BD_Ref_Exec.sql` e `sip_4.0.x.1_BD_Ref_Exec.sql`.

Copiar para `/opt` (aqui o `sudo` é necessário):

```bash
sudo cp -r ~/sei-pacote/fontes/sei ~/sei-pacote/fontes/sip ~/sei-pacote/fontes/infra /opt/
```

O pacote não traz a pasta `sip/bin`. Criar para ficar igual ao manual:

```bash
sudo mkdir -p /opt/sip/bin
ls /opt/sei /opt/sip /opt/infra
```

Esperado:

```
/opt/infra:
infra_css  infra_js  infra_php

/opt/sei:
bin  config  scripts  temp  web

/opt/sip:
bin  config  scripts  temp  web
```

Em `ls /opt` aparecem também pastas que já vinham na VM (por exemplo `rh` e `unified-monitoring-agent`): não mexer.

---

## Etapa 3 - Apache

```bash
sudo dnf install -y httpd
sudo systemctl enable --now httpd
systemctl status httpd
```

Esperado: `enabled` e `active (running)`.

Testar:

```bash
curl -I http://localhost
```

Esperado: `HTTP/1.1 403 Forbidden` (é a página de teste padrão do Oracle Linux, "Apache 2 Test Page") ou `200 OK`. Não pode aparecer `Connection refused`.

---

## Etapa 4 - PHP 7.3 e extensões

### Instalar o PHP 7.3

O Oracle Linux 8 oferece o PHP 7.3 como "módulo" do `dnf`. O padrão do sistema é o 7.4, então a versão precisa ser escolhida **antes** de instalar:

```bash
dnf module list php
```

Esperado: uma tabela com os streams `7.2`, `7.3`, `7.4 [d]`, `8.0` e `8.2`.

```bash
sudo dnf module enable php:7.3 -y
sudo dnf install -y php-cli php-fpm
php -v
```

Esperado: `PHP 7.3.x (cli)` (no laboratório, `7.3.20`). O pacote `nginx-filesystem`, que vem como dependência, é só uma pasta: não instala o nginx.

### Extensões

| Grupo | Extensões | Uso no SEI |
| --- | --- | --- |
| Banco de dados | mysqli | Conversar com o MySQL |
| Comunicação | soap, curl, openssl, json, dom, libxml, SimpleXML | SEI ↔ SIP por web service (SOAP/XML) |
| Texto | mbstring, iconv, intl, gettext, pcre, ctype, filter | Acentos, datas e validação |
| Arquivos | gd, exif, fileinfo, zip, bz2, zlib, Phar | Imagens, tipos de arquivo, compactação |
| Cálculo | date, calendar, bcmath | Prazos e cálculos |
| Segurança | sodium, hash | Criptografia e hash dos documentos (ver nota abaixo) |
| Cache | memcache, igbinary | Ponte entre o PHP e o Memcached |
| Login corporativo | ldap | Integração com AD/LDAP |
| Upload | uploadprogress | Barra de progresso (opcional) |

O PHP instalado vem **básico**. Ver o que já está carregado:

```bash
php -m
```

Ver quais pacotes existem no repositório:

```bash
dnf list available "php-*"
```

Instalar as extensões que faltam (nomes dos pacotes no Oracle Linux 8):

| Extensão | Pacote |
| --- | --- |
| mysqli | `php-mysqlnd` |
| json | `php-json` |
| dom, SimpleXML | `php-xml` |
| soap | `php-soap` |
| mbstring | `php-mbstring` |
| intl | `php-intl` |
| gd | `php-gd` |
| zip | `php-pecl-zip` |
| bcmath | `php-bcmath` |
| ldap | `php-ldap` |

```bash
sudo dnf install -y php-mysqlnd php-json php-xml php-soap php-mbstring php-intl php-gd php-pecl-zip php-bcmath php-ldap
php -m
```

Esperado: `mysqli`, `json`, `dom`, `SimpleXML`, `soap`, `mbstring`, `intl`, `gd`, `zip`, `bcmath` e `ldap` na lista.

> **sodium:** não existe pacote no repositório padrão (nem `libsodium`). No código do SEI ela só é usada pelo **SEI Federação** (`/opt/sei/web/rn/InstalacaoFederacaoRN.php`). Para conferir depois de copiar os fontes: `grep -rl "sodium_" /opt/sei /opt/sip --include=*.php`. Neste laboratório ela **não foi instalada**; sem ela a Federação não funciona e o resto do sistema sim.

### Compilar as extensões memcache e igbinary

Ferramentas de compilação:

```bash
sudo dnf install -y php-devel php-pear gcc make zlib-devel
pecl version
```

Esperado: `PHP Version: 7.3.x`.

Compilar a memcache (responder **Enter** às perguntas). A versão 4.0.4 do manual não está mais disponível no PECL; a 4.0.5.2 é da mesma família e compatível com PHP 7:

```bash
sudo pecl install memcache-4.0.5.2
```

Esperado: `install ok: channel://pecl.php.net/memcache-4.0.5.2`.

Compilar a igbinary (o `pecl` escolhe a versão estável compatível com o PHP 7.3):

```bash
sudo pecl install igbinary
```

Esperado: `install ok: channel://pecl.php.net/igbinary-...`.

Ativar as duas (o número no nome define a ordem de leitura; a igbinary vai antes):

```bash
echo "extension=igbinary.so" | sudo tee /etc/php.d/30-igbinary.ini
echo "extension=memcache.so" | sudo tee /etc/php.d/40-memcache.ini
php -m | grep -E "igbinary|memcache"
```

Esperado: `igbinary` e `memcache` na lista.

### Ajustes do php.ini

Criar um arquivo próprio com os valores da seção 2 do manual:

```bash
sudo vim /etc/php.d/99-sei.ini
```

Conteúdo:

```ini
; Ajustes do SEI/SIP - manual secao 2 "Configuracao do PHP"
include_path = ".:/usr/share/pear:/usr/share/php:/opt/infra/infra_php"
default_charset = "ISO-8859-1"
session.gc_maxlifetime = 28800
short_open_tag = On
default_socket_timeout = 60
max_input_vars = 1000
html_errors = 0
post_max_size = 201M
upload_max_filesize = 200M
session.cookie_secure = 0
date.timezone = America/Sao_Paulo
```

| Diretiva | Motivo |
| --- | --- |
| `include_path` | Acrescenta a pasta do InfraPHP |
| `default_charset` | Acentuação do SEI (latin1) |
| `short_open_tag` | Sem isso aparece código PHP na tela (Problema nº 1 do manual) |
| `post_max_size` / `upload_max_filesize` | Upload de até 200 MB |
| `session.cookie_secure = 0` | Com 1 sem HTTPS, o login só recarrega a tela (Problema nº 9) |

Conferir:

```bash
php -i | grep short_open_tag
```

Esperado: `short_open_tag => On => On`.

### php-fpm

O Apache executa o PHP pelo **php-fpm**. Habilitar no boot e iniciar:

```bash
sudo systemctl enable php-fpm
sudo systemctl restart php-fpm
systemctl status php-fpm
```

Esperado: `enabled` e `active (running)`.

Como o php-fpm foi instalado **depois** que o Apache já estava rodando, reiniciar o Apache e testar o PHP por uma página temporária:

```bash
sudo systemctl restart httpd
echo "<?php phpinfo();" | sudo tee /var/www/html/teste.php
curl -s http://localhost/teste.php | grep short_open_tag
curl -s http://localhost/teste.php | grep "memcache support"
sudo rm /var/www/html/teste.php
curl -I http://localhost/teste.php
```

Esperado: `short_open_tag ... On`, `memcache support ... enabled` e, no último comando, `HTTP/1.1 404 Not Found`. A página é apagada porque expõe detalhes do servidor.

---

## Etapa 5 - Memcached

```bash
sudo dnf install -y memcached
cat /etc/sysconfig/memcached
```

No Oracle Linux a linha `OPTIONS` já vem como `OPTIONS="-l 127.0.0.1,::1"`, que aceita conexões só da própria máquina (IPv4 e IPv6 locais). **Não é preciso alterar nada.**

Ligar e testar:

```bash
sudo systemctl enable --now memcached
printf "stats\nquit\n" | nc 127.0.0.1 11211 | head -5
```

Esperado: linhas começando com `STAT` (pid, uptime, version...). A versão no laboratório foi a 1.5.22.

---

## Etapa 6 - Banco de dados (MySQL 8.0)

### Instalar

O manual aceita o MySQL 8.0 com PHP 7.3 (Problema nº 32), desde que o plugin de autenticação seja `mysql_native_password`. O Oracle Linux 8 traz o MySQL como módulo do `dnf`:

```bash
dnf module list mysql
sudo dnf module enable mysql:8.0 -y
sudo dnf install -y mysql-server
mysql --version
```

Esperado: `mysql  Ver 8.0.xx for Linux on x86_64`.

> Fixar o stream `8.0` evita que o `dnf` pegue a 8.4 de outro repositório que pode estar ativado na VM.

Ligar:

```bash
sudo systemctl enable --now mysqld
systemctl status mysqld
```

### Senha do root do banco

Nesta instalação **não existe senha temporária**: o arquivo `/var/log/mysqld.log` nem existe (o log fica em `/var/log/mysql/mysqld.log`). O `root` do banco começa sem senha. Definir a senha e proteger o banco:

```bash
sudo mysql_secure_installation
```

| Pergunta | Resposta |
| --- | --- |
| Validate password component? | n |
| New password / Re-enter new password | senha forte (digitar não mostra nada na tela) |
| Remove anonymous users? | y |
| Disallow root login remotely? | y |
| Remove test database and access to it? | y |
| Reload privilege tables now? | y |

Esperado: `All done!`. A pergunta "Change the password for root?" **não aparece** (não há senha antiga).

> Digite a senha com atenção: como o campo não mostra o que é digitado, um erro passa despercebido e o resultado é `ERROR 1045 ... Access denied`. Anote a senha num lugar seguro e **não a compartilhe**.

### Charset latin1

No Oracle Linux o `/etc/my.cnf` só manda ler a pasta `/etc/my.cnf.d`, e as seções `[mysqld]` ficam nos arquivos de dentro dela. Ver como está:

```bash
cat /etc/my.cnf
ls /etc/my.cnf.d
cat /etc/my.cnf.d/mysql-default-authentication-plugin.cnf
```

O arquivo `mysql-default-authentication-plugin.cnf` já traz `default_authentication_plugin=mysql_native_password`, então o Problema nº 32 do manual **já vem resolvido**.

Em vez de editar arquivos do sistema, criar um arquivo próprio:

```bash
sudo vim /etc/my.cnf.d/99-sei.cnf
```

```ini
# Ajustes do SEI - charset latin1 (Problema 10 do manual)
[mysqld]
character-set-server = latin1
collation-server = latin1_swedish_ci
max_allowed_packet = 64M

[client]
default-character-set = latin1
```

Os arquivos dessa pasta são lidos em ordem alfabética, então o `99-` vale por último. Reiniciar e conferir:

```bash
sudo systemctl restart mysqld
mysql -u root -p -e "SHOW VARIABLES LIKE 'character_set%';"
```

Esperado: `client`, `connection`, `database`, `results` e `server` como `latin1` (`character_set_system` como `utf8mb3` e `filesystem` como `binary` são normais).

### Bases e usuário do sistema

```bash
mysql -u root -p
```

Dentro do console (um comando por vez):

```sql
CREATE DATABASE sei CHARACTER SET latin1 COLLATE latin1_swedish_ci;
CREATE DATABASE sip CHARACTER SET latin1 COLLATE latin1_swedish_ci;
CREATE USER 'sei_user'@'localhost' IDENTIFIED BY 'SENHA_SEI_USER';
GRANT SELECT, INSERT, UPDATE, DELETE ON sei.* TO 'sei_user'@'localhost';
GRANT SELECT, INSERT, UPDATE, DELETE ON sip.* TO 'sei_user'@'localhost';
FLUSH PRIVILEGES;
SHOW DATABASES;
EXIT;
```

O manual exige um usuário **sem permissão de DDL** (não cria nem altera tabelas), por isso só SELECT, INSERT, UPDATE e DELETE.

### Restaurar as bases

Os dumps não têm `CREATE DATABASE` nem `USE`, então carregam na base indicada no comando:

```bash
mysql -u root -p sip < ~/sei-pacote/bd/sip_4.0.x.1_BD_Ref_Exec.sql
mysql -u root -p sei < ~/sei-pacote/bd/sei_4.0.x.1_BD_Ref_Exec.sql
```

Esperado: nenhuma saída. Conferir:

```bash
mysql -u root -p -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='sip';"
mysql -u root -p -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='sei';"
```

Esperado: 39 tabelas no SIP e 267 no SEI (os mesmos números do MySQL 5.7).

### Órgão e URLs

Base do SIP:

```bash
mysql -u root -p sip
```

```sql
UPDATE orgao SET sigla='SUA_SIGLA', descricao='SUA_DESCRICAO' WHERE id_orgao=0;
UPDATE sistema SET pagina_inicial='http://SEU_ENDERECO/sip' WHERE sigla='SIP';
UPDATE sistema SET pagina_inicial='http://SEU_ENDERECO/sei/inicializar.php', web_service='http://SEU_ENDERECO/sei/controlador_ws.php?servico=sip' WHERE sigla='SEI';
SELECT sigla, descricao FROM orgao;
SELECT sigla, pagina_inicial, web_service FROM sistema;
EXIT;
```

Esperado: o órgão com a sua sigla e as duas linhas de `sistema` com as URLs. O `NULL` no `web_service` do SIP é normal.

Base do SEI (a sigla **deve** ser a mesma):

```bash
mysql -u root -p sei
```

```sql
UPDATE orgao SET sigla='SUA_SIGLA', descricao='SUA_DESCRICAO' WHERE id_orgao=0;
SELECT id_orgao, sigla, descricao FROM orgao;
EXIT;
```

Testar o usuário do sistema (pede a senha do `sei_user`):

```bash
mysql -u sei_user -p -e "SELECT sigla FROM sip.orgao; SELECT sigla FROM sei.orgao;"
```

Esperado: `SUA_SIGLA` nas duas consultas. Se der `Access denied`, a senha foi digitada diferente da definida. Redefinir pelo root (e usar essa senha nos arquivos das Etapas 8 e 9):

```sql
ALTER USER 'sei_user'@'localhost' IDENTIFIED BY 'NOVA_SENHA_SEI_USER';
FLUSH PRIVILEGES;
```

---

## Etapa 7 - Permissões e publicação no Apache

### Dono e permissões (seção 3 do manual)

Fazer **depois** de instalar o Apache (é ele que cria o grupo `apache`).

```bash
sudo chown -R root:apache /opt/sei /opt/sip /opt/infra
```

SEI:

```bash
sudo find /opt/sei -type d -exec chmod 2750 {} \;
sudo find /opt/sei -type f -exec chmod 0640 {} \;
sudo find /opt/sei/temp -type d -exec chmod 2570 {} \;
```

SIP:

```bash
sudo find /opt/sip -type d -exec chmod 2750 {} \;
sudo find /opt/sip -type f -exec chmod 0640 {} \;
sudo find /opt/sip/temp -type d -exec chmod 2570 {} \;
```

Infra (não tem pasta temp):

```bash
sudo find /opt/infra -type d -exec chmod 2750 {} \;
sudo find /opt/infra -type f -exec chmod 0640 {} \;
```

| Permissão | Onde | Significado |
| --- | --- | --- |
| `2750` | pastas | root tudo, apache lê e entra, outros nada. O `2` (setgid) faz arquivos novos herdarem o grupo |
| `0640` | arquivos | root lê e grava, apache só lê |
| `2570` | `temp` | apache pode gravar (uploads, PDFs, ZIPs) |

> **Atenção ao terceiro comando de cada bloco:** o caminho tem que terminar em `/temp`. Sem ele, o `2570` é aplicado a **todas** as pastas do sistema. Se isso acontecer, refazer o primeiro e o terceiro comando, nessa ordem.

Conferir as pastas (precisa de `sudo`, porque os "outros" não têm acesso):

```bash
sudo ls -ld /opt/sei /opt/sei/temp /opt/sip /opt/sip/temp /opt/infra
```

Esperado: `drwxr-s--- root apache` e, nas pastas `temp`, `dr-xrws--- root apache`.

Conferir os arquivos, **contando** os que ficaram fora do padrão:

```bash
sudo find /opt/sei /opt/sip /opt/infra -type f ! -perm 0640 | wc -l
```

Esperado: `0`. Se der outro número, repetir os `find ... -type f` e contar de novo.

### Limpeza noturna da temp

```bash
sudo vim /etc/cron.d/sei-limpeza
```

```
# todos os dias a 1h da manha
00 01 * * * root rm -rf /opt/sei/temp/*
00 01 * * * root rm -rf /opt/sip/temp/*
```

> Arquivos em `/etc/cron.d/` têm a coluna do usuário (`root`). Esse formato não serve para o `crontab -e`.

```bash
cat /etc/cron.d/sei-limpeza
ls -l /etc/cron.d/sei-limpeza
```

Esperado: `-rw-r--r-- root root`.

### sei.conf (publicar /sei e /sip)

```bash
sudo vim /etc/httpd/conf.d/sei.conf
```

```apache
# SEI/SIP - manual secao 3 (Codigo-Fonte)
Alias "/sei" "/opt/sei/web"
Alias "/sip" "/opt/sip/web"
Alias "/infra_css" "/opt/infra/infra_css"
Alias "/infra_js" "/opt/infra/infra_js"

<Directory />
  AllowOverride None
  Require all denied
</Directory>

<Directory ~ "(/opt/sei/web|/opt/sip/web|/opt/infra/infra_css|/opt/infra/infra_js)" >
  AllowOverride None
  Options None
  Require all granted
</Directory>
```

Só as pastas `web`, `infra_css` e `infra_js` ficam acessíveis pelo navegador. `config` e `scripts` ficam protegidas.

```bash
sudo apachectl configtest
sudo systemctl restart httpd
curl -I http://localhost/infra_css/infra-global-esquema.css
curl -I http://localhost/infra_js/InfraUtil.js
```

Esperado: `Syntax OK` e `HTTP/1.1 200 OK` nos dois testes (Problema nº 2 do manual).

---

## Etapa 8 - Configurar o SIP

Criar o arquivo a partir do exemplo (o exemplo fica como backup, inclusive da chave de acesso original):

```bash
sudo cp -p /opt/sip/config/ConfiguracaoSip.exemplo.php /opt/sip/config/ConfiguracaoSip.php
```

Ver as linhas que precisam mudar (sem a linha `Senha`, para não expô-la):

```bash
sudo grep -n -E "URL|Producao|SiglaOrgao|PaginaLogin|SipWsdl|https|Servidor|Porta|Banco'|Usuario|Tipo" /opt/sip/config/ConfiguracaoSip.php
```

| Bloco | Chave | Valor |
| --- | --- | --- |
| Sip | URL | `http://SEU_ENDERECO/sip` |
| Sip | Producao | `false` durante a montagem (volta a `true` na Etapa 14) |
| SessaoSip | SiglaOrgaoSistema | `SUA_SIGLA` |
| SessaoSip | PaginaLogin | `http://SEU_ENDERECO/sip/login.php` |
| SessaoSip | SipWsdl | `http://SEU_ENDERECO/sip/controlador_ws.php?servico=sip` |
| SessaoSip | ChaveAcesso | manter a do arquivo |
| SessaoSip | https | `false` |
| BancoSip | Servidor / Porta / Banco | `localhost` / `3306` / `sip` |
| BancoSip | Usuario / Senha / Tipo | `sei_user` / `SENHA_SEI_USER` / `MySql` |
| CacheSip | Servidor / Porta | `localhost` / `11211` |

Não alterar: `Modulos`, `BancoAuditoriaSip` (comentado) e `InfraMail`.

Para editar, os comandos do vim abaixo trocam cada valor sem precisar procurar. **Os números de linha valem para a versão 4.0.12.15**: confira com o `grep` acima antes. Abrir o arquivo:

```bash
sudo vim /opt/sip/config/ConfiguracaoSip.php
```

No vim, com `Esc` antes de cada um, digitar o comando e `Enter`:

| Comando | O que troca |
| --- | --- |
| `:%s/\[Servidor PHP\]/SEU_ENDERECO/g` | `URL`, `PaginaLogin` e `SipWsdl` (linhas 20, 37 e 38) |
| `:21s/true/false/` | `Producao` |
| `:35s/ABC/SUA_SIGLA/` | `SiglaOrgaoSistema` |
| `:40s/true/false/` | `https` |
| `:44s/\[Servidor BD\]/localhost/` | servidor do banco |
| `:45s/''/'3306'/` | porta do banco |
| `:46s/''/'sip'/` | nome do banco |
| `:47s/''/'sei_user'/` | usuário do banco |
| `:48s/''/'SENHA_SEI_USER'/` | senha do banco |
| `:49s/''/'MySql'/` | tipo do banco |
| `:64s/\[Servidor Mencache\]/localhost/` | servidor do Memcached |

Depois, `:wq`. Não mexer nas linhas 54 a 59 (auditoria, comentadas) nem nas de e-mail (a partir da 69).

> Valores entre aspas simples e vírgula no fim de cada linha. `true` e `false` sem aspas. Não apagar a última `}` do arquivo. Se a senha tiver `/` ou `&`, o comando `:s` quebra: edite essa linha à mão.

Conferir:

```bash
sudo php -l /opt/sip/config/ConfiguracaoSip.php
sudo grep -n -E "URL|Producao|SiglaOrgao|PaginaLogin|SipWsdl|https|Servidor|Porta|Banco'|Usuario|Tipo" /opt/sip/config/ConfiguracaoSip.php
sudo ls -la /opt/sip/config
```

Esperado: `No syntax errors detected`, os valores da tabela, `-rw-r----- root apache` e nenhum arquivo `.swp`.

---

## Etapa 9 - Configurar o SEI

```bash
sudo cp -p /opt/sei/config/ConfiguracaoSEI.exemplo.php /opt/sei/config/ConfiguracaoSEI.php
sudo grep -n -E "URL|Producao|Repositorio|SiglaOrgao|PaginaLogin|SipWsdl|https|Servidor|Porta|Banco'|Usuario|Tipo|JODConverter|CoreProtocolos" /opt/sei/config/ConfiguracaoSEI.php
```

| Bloco | Chave | Valor |
| --- | --- | --- |
| SEI | URL | `http://SEU_ENDERECO/sei` |
| SEI | Producao | `false` durante a montagem (volta a `true` na Etapa 14) |
| SEI | RepositorioArquivos | `/var/sei/arquivos` |
| SessaoSEI | SiglaOrgaoSistema | `SUA_SIGLA` |
| SessaoSEI | PaginaLogin | `http://SEU_ENDERECO/sip/login.php` |
| SessaoSEI | SipWsdl | `http://SEU_ENDERECO/sip/controlador_ws.php?servico=sip` |
| SessaoSEI | ChaveAcesso | manter a do arquivo |
| SessaoSEI | https | `false` |
| BancoSEI | Servidor / Porta / Banco | `localhost` / `3306` / `sei` |
| BancoSEI | Usuario / Senha / Tipo | `sei_user` / `SENHA_SEI_USER` / `MySql` |
| CacheSEI | Servidor / Porta | `localhost` / `11211` |
| Solr | Servidor | `http://127.0.0.1:8983/solr` (**IP, não `localhost`**: ver [Etapa 11](#restringir-o-acesso-ao-solr)) |
| JODConverter | bloco inteiro | comentar com `//` (servidor opcional, não instalado) |

> `PaginaLogin` e `SipWsdl` apontam para o **/sip**: o login é feito no SIP. Cuidado para não inverter os dois.
>
> O `RepositorioArquivos` não usa `/dados` (valor do exemplo) porque essa pasta será usada pelos índices do Solr.

Comandos do vim (**números de linha da versão 4.0.12.15**, confira com o `grep` acima):

```bash
sudo vim /opt/sei/config/ConfiguracaoSEI.php
```

| Comando | O que troca |
| --- | --- |
| `:%s/\[Servidor PHP\]/SEU_ENDERECO/g` | `URL`, `PaginaLogin` e `SipWsdl` (linhas 19, 42 e 43) |
| `:20s/true/false/` | `Producao` |
| `:26s#/dados#/var/sei/arquivos#` | `RepositorioArquivos` (usa `#` porque o caminho já tem `/`) |
| `:40s/ABC/SUA_SIGLA/` | `SiglaOrgaoSistema` |
| `:45s/true/false/` | `https` |
| `:49s/\[servidor BD\]/localhost/` | servidor do banco |
| `:50s/''/'3306'/` | porta do banco |
| `:51s/''/'sei'/` | nome do banco |
| `:52s/''/'sei_user'/` | usuário do banco |
| `:53s/''/'SENHA_SEI_USER'/` | senha do banco |
| `:54s/''/'MySql'/` | tipo do banco |
| `:69s/\[Servidor memcache\]/localhost/` | servidor do Memcached |
| `:74s/\[Servidor Solr\]/127.0.0.1/` | servidor do Solr |
| `:83,85s#^#//#` | comenta o bloco do JODConverter |

Não mexer nas linhas 59 a 64 (auditoria, comentadas) nem nas de e-mail (a partir da 93).

Bloco do JODConverter comentado:

```php
//            'JODConverter' => array(
//                'Servidor' => 'http://[Servidor JodConverter]/converter/service'
//            ),
```

Conferir:

```bash
sudo php -l /opt/sei/config/ConfiguracaoSEI.php
sudo sed -n '81,87p' /opt/sei/config/ConfiguracaoSEI.php
sudo grep -n -E "URL|Producao|Repositorio|SiglaOrgao|PaginaLogin|SipWsdl|https|Servidor|Porta|Banco'|Usuario|Tipo" /opt/sei/config/ConfiguracaoSEI.php
sudo ls -la /opt/sei/config
```

Esperado: `No syntax errors detected`, as três linhas do JODConverter começando com `//`, os valores da tabela e **`-rw-r----- root apache`** no `ConfiguracaoSEI.php` (esse arquivo guarda a senha do banco: se aparecer `-rw-r--r--`, rodar `sudo chmod 0640 /opt/sei/config/ConfiguracaoSEI.php`).

Para conferir que a senha gravada nos arquivos é a do banco, sem digitá-la de novo, copie a senha mostrada por `sudo sed -n '53p' /opt/sei/config/ConfiguracaoSEI.php` e cole-a quando o comando abaixo pedir a senha:

```bash
mysql -u sei_user -p -e "SELECT 'senha ok' AS resultado;"
```

### Repositório de arquivos

```bash
sudo mkdir -p /var/sei/arquivos
sudo chown apache:apache /var/sei/arquivos
sudo chmod 750 /var/sei/arquivos
sudo ls -ld /var/sei/arquivos
```

Esperado: `drwxr-x--- apache apache`.

### Rótulos do SELinux para gravação

Com o SELinux em `Enforcing`, o Apache/PHP só consegue **gravar** em pastas com o tipo `httpd_sys_rw_content_t`. Ver os rótulos atuais:

```bash
sudo ls -ldZ /var/sei/arquivos /opt/sei/temp /opt/sip/temp
```

Esperado antes do ajuste: `var_t` no repositório de arquivos e `usr_t` nas duas `temp`.

Instalar o `semanage` (se já estiver instalado, aparece `Nothing to do.`) e registrar as regras, uma por vez:

```bash
sudo dnf install -y policycoreutils-python-utils
sudo semanage fcontext -a -t httpd_sys_rw_content_t "/var/sei/arquivos(/.*)?"
sudo semanage fcontext -a -t httpd_sys_rw_content_t "/opt/sei/temp(/.*)?"
sudo semanage fcontext -a -t httpd_sys_rw_content_t "/opt/sip/temp(/.*)?"
```

Aplicar às pastas que já existem e conferir:

```bash
sudo restorecon -Rv /var/sei/arquivos /opt/sei/temp /opt/sip/temp
sudo ls -ldZ /var/sei/arquivos /opt/sei/temp /opt/sip/temp
```

Esperado: linhas `Relabeled ...` e `httpd_sys_rw_content_t` nas **três** pastas.

Para listar só as regras que você criou (as que vêm do sistema não aparecem):

```bash
sudo semanage fcontext -l -C
```

Se uma regra foi criada com o caminho errado, removê-la com o mesmo texto e `-d`, por exemplo: `sudo semanage fcontext -d "/var/sei/temp(/.*)?"`.

---

## Etapa 10 - Acesso pelo navegador e primeiro login

### Como chegar ao SEI pelo navegador

Neste laboratório não há DNS para a VM e o firewall libera só o SSH, então o acesso é por **túnel SSH do MobaXterm** (Local port forwarding):

| Campo | Valor |
| --- | --- |
| Tipo | Local port forwarding |
| Porta local (no seu computador) | `80` |
| Remote server | `IP_PRIVADO_DA_VM` |
| Porta do remote server | `80` |
| SSH server | o mesmo endereço da sessão desta VM |
| Usuário / porta SSH | `opc` / `22` |

Salvar e iniciar o túnel (botão de play). Se o Windows já usar a porta 80 (por exemplo, o IIS), o MobaXterm avisa que não conseguiu abri-la.

Teste no navegador: `http://localhost` deve mostrar a "Apache 2 Test Page". O túnel precisa estar **ativo** sempre que for acessar (reinicie-o se fechar o MobaXterm).

> O túnel entra pela porta 22 e chega ao Apache dentro da VM, por isso **não passa pelo `firewalld`**. Abrir `http`/`https` no firewall (`sudo firewall-cmd --permanent --add-service=http`, `--add-service=https` e `sudo firewall-cmd --reload`) só serve para quem for acessar por IP, e ainda depende da regra de entrada da rede da nuvem. Esse caminho **não foi validado** neste laboratório: pelo IP público o navegador mostrou `ERR_CONNECTION_RESET`.

### Primeiro login

Como o endereço é `localhost`, o teste `getent hosts` da versão AWS não se aplica. Testar o SIP pela VM:

```bash
curl -I http://localhost/sip/
```

Esperado: `HTTP/1.1 302 Found` com `Location:` contendo `sigla_orgao_sistema=SUA_SIGLA`.

Em outra aba do terminal, acompanhar os erros em tempo real (Ctrl+C para sair):

```bash
sudo tail -f /var/log/httpd/error_log
```

No navegador (usuário `teste`, senha `teste`):

- `http://localhost/sip` → menu do SIP com o nome do órgão no topo
- `http://localhost/sei` → login do SIP e depois **Controle de Processos** do SEI

<!-- IMAGEM: imagens/oracle/sip-menu.png -->

<!-- IMAGEM: imagens/oracle/sei-controle-processos.png -->

---

## Etapa 11 - Solr

### Java 8 e usuário

```bash
sudo dnf install -y java-1.8.0-openjdk-headless
java -version
sudo useradd solr
id solr
```

Esperado: `openjdk version "1.8.0_..."` e o usuário `solr`.

### Download

O `/tmp` precisa de pelo menos 2 GB livres:

```bash
df -h /tmp
cd /tmp
wget https://archive.apache.org/dist/lucene/solr/8.2.0/solr-8.2.0.tgz
wget https://archive.apache.org/dist/lucene/solr/8.2.0/solr-8.2.0.tgz.sha512
sha512sum -c solr-8.2.0.tgz.sha512
```

Esperado: `solr-8.2.0.tgz: OK` (arquivo íntegro).

### Arquivos do SEI para o Solr

```bash
sudo cp -r /opt/sei/config/solr/. /tmp/
ls -l /tmp
```

Esperado: `log4j.properties`, `sei-cores-8.2.0`, `sei-solr-8.2.0.sh`, `solr.service` e `solr-8.2.0.tgz`.

> O `/.` copia o conteúdo da pasta. Com `solr/*` o comando falharia, porque o `*` é expandido pelo `opc`, que não tem acesso a `/opt/sei/config`.

### Converter os arquivos para o formato Linux

O script e o serviço vêm com quebras de linha do Windows (CRLF) e falham com `$'\r': command not found`:

```bash
sudo dnf install -y dos2unix
sudo dos2unix /tmp/sei-solr-8.2.0.sh /tmp/solr.service
sudo file /tmp/sei-solr-8.2.0.sh /tmp/solr.service
```

Esperado: `POSIX shell script, ASCII text executable` e `ASCII text`, sem `with CRLF line terminators`.

### Instalar (executar uma única vez)

Ler o script antes de executar:

```bash
sudo cat /tmp/sei-solr-8.2.0.sh
sudo bash /tmp/sei-solr-8.2.0.sh
```

O script confere os arquivos de que precisa, descompacta o Solr em `/opt/solr`, cria `/dados` com os três índices do SEI, entrega tudo ao usuário `solr` e instala o serviço. Esperado: linhas `mkdir: created directory` e nenhuma linha com erro. Ele usa `mkdir /dados`, que **falha se a pasta já existir**: não rode duas vezes sem limpar o que foi criado.

```bash
sudo tree -d /dados
sudo ls -ld /dados /opt/solr
```

Esperado: `sei-bases-conhecimento`, `sei-protocolos` e `sei-publicacoes`, cada um com `conf` e `conteudo` (21 diretórios no total), e dono `solr solr`.

### Memória

O manual usa 6 GB para um servidor dedicado de 8 GB. Numa VM compartilhada com os outros serviços, usar cerca de 1/4 da RAM (`free -h`). Com 7,5 GB, 2 GB:

```bash
grep -n "SOLR_JAVA_MEM" /opt/solr/bin/solr.in.sh
sudo vim +NUMERO_DA_LINHA /opt/solr/bin/solr.in.sh
```

Tirar o `#` do início e deixar a linha assim:

```
SOLR_JAVA_MEM="-Xms512m -Xmx2g"
```

No vim: `Esc`, `0` (início da linha), `x` (apaga o `#`) e `:wq`. Conferir com o `grep` de novo: a linha **não pode** começar com `#`, senão a configuração é ignorada.

### Ligar o serviço

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now solr
systemctl status solr
```

Esperado: `active (running)` e o processo `java ... -Xms512m -Xmx2g`.

Conferir os índices (o Solr leva de 10 a 20 segundos para responder):

```bash
curl -s "http://localhost:8983/solr/admin/cores?action=STATUS" | grep '"name"'
```

Esperado: `sei-bases-conhecimento`, `sei-protocolos` e `sei-publicacoes`.

### Restringir o acesso ao Solr

O Solr não tem senha. Aceitar conexões apenas da própria máquina (`127.0.0.1`), já que o único cliente é o SEI:

```bash
sudo cp -p /opt/solr/server/etc/jetty.xml /opt/solr/server/etc/jetty.xml.original
sudo grep -n "Contexts" /opt/solr/server/etc/jetty.xml
```

A primeira linha encontrada (`<New id="Contexts" ...`) fica dentro de um item de 3 linhas. Ver as linhas ao redor (no laboratório, a do `Contexts` era a 121):

```bash
sudo sed -n '118,124p' /opt/solr/server/etc/jetty.xml
```

Esperado: um `<Item>` (linha 120), a linha do `Contexts` (121) e o `</Item>` (122), seguidos de outro `<Item>` com `InstrumentedHandler` (que **não** deve ser alterado). Os itens ficam dentro de `<Array type="org.eclipse.jetty.server.Handler">`:

```xml
                <Item>
                  <New id="Contexts" class="org.eclipse.jetty.server.handler.ContextHandlerCollection"/>
                </Item>
```

**Substituir** essas 3 linhas (não acrescentar ao lado) por:

```xml
                <Item>
                  <New class="org.eclipse.jetty.server.handler.IPAccessHandler">
                    <Call name="addWhite">
                      <Arg>127.0.0.1</Arg>
                    </Call>
                    <Set name="handler">
                      <New id="Contexts" class="org.eclipse.jetty.server.handler.ContextHandlerCollection"/>
                    </Set>
                  </New>
                </Item>
```

No vim: `sudo vim +120 /opt/solr/server/etc/jetty.xml`, `:set paste`, confirmar que o cursor está no `<Item>`, `3dd` para apagar as 3 linhas, `O` (maiúsculo) para abrir uma linha acima, colar, `Esc`, `:wq`.

```bash
xmllint --noout /opt/solr/server/etc/jetty.xml
sudo systemctl restart solr
```

Esperado: `xmllint` sem saída (XML válido). Esperar uns 15 segundos e testar:

```bash
curl -I http://127.0.0.1:8983/solr/
curl -I http://IP_PRIVADO_DA_VM:8983/solr/
curl -4 -I http://localhost:8983/solr/
curl -6 -I http://localhost:8983/solr/
```

Esperado: `200 OK`, **`403 Forbidden`**, `200 OK` e **`500 Server Error`**. O 403 prova que a restrição funciona.

> **IPv6:** no Oracle Linux 8 o nome `localhost` pode ser resolvido como `::1` (IPv6), que o filtro de IPs do Solr não cobre: a resposta é `500`. Por isso o `Servidor` do Solr no `ConfiguracaoSEI.php` usa **`127.0.0.1`** e não `localhost`. Sem isso o SEI pode falhar ao falar com o Solr.

Conferir a configuração do SEI e a sintaxe:

```bash
sudo grep -n "8983" /opt/sei/config/ConfiguracaoSEI.php
sudo php -l /opt/sei/config/ConfiguracaoSEI.php
```

Esperado: `'Servidor' => 'http://127.0.0.1:8983/solr',` e `No syntax errors detected`.

### Indexar

```bash
sudo /usr/bin/php -c /etc/php.ini /opt/sei/scripts/indexacao_protocolos_completa.php
sudo /usr/bin/php -c /etc/php.ini /opt/sei/scripts/indexacao_publicacoes.php
sudo /usr/bin/php -c /etc/php.ini /opt/sei/scripts/indexacao_bases_conhecimento.php
```

Esperado: `Operacao Finalizada.` (0 itens na base de referência, que não tem processos).

Acompanhar a quantidade de documentos indexados:

```bash
curl -s "http://127.0.0.1:8983/solr/admin/cores?action=STATUS&core=sei-protocolos" | grep numDocs
```

Esperado: `"numDocs":0` agora. Depois dos [testes como usuário](#testes-como-usuário), o número sobe.

> Os comandos de limpeza de índices do fim da seção 21 do manual **apagam** os índices. Só servem para reindexar no futuro.

---

## Etapa 12 - Agendamentos

O SEI e o SIP têm tarefas automáticas cadastradas em Infra → Agendamentos. O cron executa, a cada minuto, um script que verifica quais estão na hora de rodar.

### Parâmetro obrigatório no SIP

A base de referência do SIP não tem o parâmetro `SIP_EMAIL_ADMINISTRADOR`, e sem ele o script de agendamento do SIP falha. Conferir:

```bash
mysql -u root -p sip -e "SELECT nome, valor FROM infra_parametro WHERE nome LIKE 'SIP_EMAIL%';"
mysql -u root -p sei -e "SELECT nome, valor FROM infra_parametro WHERE nome LIKE 'SEI_EMAIL%';"
```

Esperado: no SEI, `SEI_EMAIL_ADMINISTRADOR` e `SEI_EMAIL_SISTEMA`; no SIP, só `SIP_EMAIL_SISTEMA`. Criar o que falta no SIP, em **Infra → Parâmetros → Novo**:

- Nome: `SIP_EMAIL_ADMINISTRADOR`
- Valor: um e-mail (pode ser fictício, o laboratório não envia e-mails)

### Agendar no cron

```bash
sudo vim /etc/cron.d/sei-agendamentos
```

```
# Agendamentos do SEI e do SIP - executa a cada minuto (manual secao 11)
* * * * * root /usr/bin/php -c /etc/php.ini /opt/sei/scripts/AgendamentoTarefaSEI.php 2>&1 >> /root/infra_agendamento_sei.log
* * * * * root /usr/bin/php -c /etc/php.ini /opt/sip/scripts/AgendamentoTarefaSip.php 2>&1 >> /root/infra_agendamento_sip.log
```

Cada linha deve ficar inteira, numa linha só.

```bash
cat /etc/cron.d/sei-agendamentos
ls -l /etc/cron.d/sei-agendamentos
systemctl is-active crond
systemctl is-enabled crond
```

Testar os scripts manualmente (sem saída = sem erro). Atenção aos nomes: `AgendamentoTarefaSEI.php` fica em `/opt/sei` e `AgendamentoTarefaSip.php` (com `Sip`, não `SIP`) em `/opt/sip`:

```bash
sudo /usr/bin/php -c /etc/php.ini /opt/sei/scripts/AgendamentoTarefaSEI.php
sudo /usr/bin/php -c /etc/php.ini /opt/sip/scripts/AgendamentoTarefaSip.php
```

> Se um agendamento não rodar, execute o script manualmente: o erro aparece na tela. Os logs em `/root/infra_agendamento_*.log` não recebem as mensagens de erro.

Ver se o cron está executando (o log mostra o **comando**, não o nome do arquivo `sei-agendamentos`, por isso o filtro é pelo nome do script):

```bash
sudo grep AgendamentoTarefa /var/log/cron | tail -5
```

Esperado: linhas `(root) CMD (/usr/bin/php ... AgendamentoTarefaSEI.php ...)` e `...AgendamentoTarefaSip.php...` a cada minuto. O horário do log é GMT (3 horas à frente de Brasília).

### Conferir pelo sistema

- **Infra → Agendamentos** (SEI e SIP): a última execução das tarefas de periodicidade "Minuto" deve ser de hoje.
- O `testarAgendamento` grava um registro em **Infra → Log** a cada 5 minutos. No SEI ele vem desativado: reativar para testar e, depois de conferir, desativar nos dois sistemas.

> O `testarAgendamento` também tenta **enviar um e-mail** aos administradores. Como a VM não tem servidor de e-mail (`InfraMail` com `Tipo` = 1, que usa o `sendmail` do sistema), o log do SIP registra `Erro executando agendamentos. Erro enviando correspondência eletrônica.` Isso é esperado no laboratório e não indica problema nos agendamentos.

<!-- IMAGEM: imagens/oracle/sip-agendamentos.png -->

<!-- IMAGEM: imagens/oracle/sei-infra-log.png -->

---

## Etapa 13 - HTTPS

```bash
sudo dnf install -y mod_ssl
sudo systemctl restart httpd
sudo ss -tlnp | grep httpd
curl -kI https://localhost/sip/
```

Esperado: Apache nas portas 80 e 443 e `HTTP/1.1 302 Found`. O `mod_ssl` gera um certificado **autoassinado**; o `-k` faz o curl aceitar. O `Location:` da resposta continua com `http://`, porque o `https` ainda está `false` nos arquivos de configuração.

> O teste com `Test-NetConnection` (PowerShell) da versão AWS não se aplica aqui: o acesso é pelo túnel, e não por IP público. Para testar pelo navegador seria preciso um segundo túnel (porta local 443 para a porta 443 da VM).

### Ativar o HTTPS nos sistemas (seção 16 do manual)

Só ativar se os usuários conseguirem abrir `https://` no navegador. Com isso o sistema passa a forçar HTTPS.

1. `'https' => true` no `ConfiguracaoSip.php` e no `ConfiguracaoSEI.php` (conferir com `php -l`).
2. SIP → Sistemas → Listar → SEI → Página Inicial: `https://SEU_ENDERECO/sei/inicializar.php`.
3. Manter o Web Service e o `SipWsdl` em `http://`: com certificado autoassinado, o PHP recusa a conexão interna e o login quebra.

> Neste laboratório o `https` ficou em `false`, com certificado autoassinado. Em produção, usar um certificado de autoridade reconhecida.

---

## Etapa 14 - Finalização e validação

### Modo de produção

Trocar `'Producao' => false` por `true` nos dois arquivos de configuração (no laboratório, a linha 21 do SIP e a 20 do SEI):

```bash
sudo vim +21 /opt/sip/config/ConfiguracaoSip.php
sudo vim +20 /opt/sei/config/ConfiguracaoSEI.php
```

No vim: `Esc`, `:21s/false/true/` (SIP) ou `:20s/false/true/` (SEI), `Enter` e `:wq`. Conferir:

```bash
sudo php -l /opt/sip/config/ConfiguracaoSip.php
sudo php -l /opt/sei/config/ConfiguracaoSEI.php
sudo grep -n "Producao" /opt/sip/config/ConfiguracaoSip.php /opt/sei/config/ConfiguracaoSEI.php
```

Com `true`, o sistema mostra o aviso de chave de acesso padrão. Para removê-lo, gerar novas chaves em SIP → Sistemas → Listar → Gerar Chave de Acesso (um sistema por vez, atualizando a `ChaveAcesso` no arquivo correspondente). Não exigido neste laboratório.

### Checklist

| Verificação | Comando | Esperado |
| --- | --- | --- |
| Serviços ligados | `systemctl is-active httpd php-fpm mysqld memcached solr crond` | 6× `active` |
| Serviços no boot | `systemctl is-enabled httpd php-fpm mysqld memcached solr crond` | 6× `enabled` |
| Portas | `sudo ss -tlnp` | 22, 80, 443, 3306, 11211 (local), 8983 e as extras abaixo |
| Banco | `mysql -u sei_user -p -e "SELECT sigla FROM sip.orgao; SELECT sigla FROM sei.orgao;"` | `SUA_SIGLA` nas duas |
| Memcached | `printf "stats\nquit\n" \| nc 127.0.0.1 11211 \| head -5` | linhas `STAT` |
| Solr | `curl -s "http://127.0.0.1:8983/solr/admin/cores?action=STATUS" \| grep '"name"'` | 3 índices |
| Pastas | `sudo ls -ld /opt/sei /opt/sei/temp /opt/sip /opt/sip/temp /opt/infra /var/sei/arquivos /opt/solr /dados` | donos e permissões das etapas 7, 9 e 11 |
| Arquivos do sistema | `sudo find /opt/sei /opt/sip /opt/infra -type f ! -perm 0640 \| wc -l` | `0` |
| Configs do sistema | `sudo ls -l /opt/sip/config/ConfiguracaoSip.php /opt/sei/config/ConfiguracaoSEI.php` | `-rw-r----- root apache` |
| Rótulos SELinux | `sudo ls -ldZ /var/sei/arquivos /opt/sei/temp /opt/sip/temp` | `httpd_sys_rw_content_t` nas três |
| Booleans SELinux | `getsebool httpd_can_network_connect httpd_can_network_memcache httpd_execmem httpd_can_connect_ldap httpd_use_nfs httpd_can_network_connect_db` | 6× `on` |
| Configs criadas | `ls -l /etc/httpd/conf.d/sei.conf /etc/php.d/99-sei.ini /etc/php.d/40-memcache.ini /etc/php.d/30-igbinary.ini /etc/my.cnf.d/99-sei.cnf /etc/cron.d/sei-limpeza /etc/cron.d/sei-agendamentos` | `-rw-r--r-- root root` |
| Cron | `sudo grep AgendamentoTarefa /var/log/cron \| tail -5` | execuções a cada minuto |
| Navegador | SIP e SEI com `teste`/`teste` | menu do SIP e Controle de Processos |
| Infra → Log | SEI e SIP | sem erros sem causa conhecida |

Portas extras que aparecem no `ss` e não são erro: **33060** (protocolo X do MySQL 8), **18983**, **7983** e **44131** (processo java do Solr), **111** (`rpcbind`) e **4330** e **44321** (monitoramento que já vinha na VM). A 3306 e a 8983 escutam em todas as interfaces; o acesso externo é barrado pelo `firewalld` (só `ssh` liberado) e, no Solr, também pelo filtro de IPs.

---

## Testes como usuário

Executados no SEI com o usuário `teste`:

| Teste | Como | Resultado |
| --- | --- | --- |
| Anexar PDF | Incluir Documento → Externo → anexar | ✔ gravado em `/var/sei/arquivos/AAAA/MM/DD/` (dono `apache`) |
| Documento no editor | Incluir Documento → Memorando → escrever → Salvar | ✔ |
| Assinar | Assinar → cargo → senha | ✔ |
| Pesquisar conteúdo | Pesquisa → Documentos → Texto para Pesquisa | ✔ (só depois de assinado) |
| Indexação no Solr | `numDocs` do índice `sei-protocolos` | ✔ passou de 0 para 3 |

Conferir o repositório de arquivos e o Solr:

```bash
sudo ls -lR /var/sei/arquivos | head -20
curl -s "http://127.0.0.1:8983/solr/admin/cores?action=STATUS&core=sei-protocolos" | grep numDocs
```

Não repetidos nesta execução (os resultados da versão AWS valem como referência): criar processo, gerar PDF do processo (esperado falhar sem o `wkhtmltopdf`), concluir e reabrir processo e os testes do SIP (registro de acessos, novo usuário, permissões).

> O editor abre em pop-up: liberar pop-ups do site no navegador.
>
> Documentos criados no editor só são indexados pelo Solr **depois de assinados**.

<!-- IMAGEM: imagens/oracle/sei-documento-assinado.png -->

<!-- IMAGEM: imagens/oracle/sei-pesquisa.png -->

---

## Problemas e soluções

| Problema | Causa | Solução |
| --- | --- | --- |
| Comandos colados e `–P` no manual | Formatação do documento | Um comando por linha e `-P` com hífen |
| `Waiting for process with pid NNNN to finish.` no `dnf` | Outro `dnf` (cache automático) em execução | Esperar terminar; não usar `kill` |
| `mkdir: cannot create directory '/sei-pacote': Permission denied` | Faltou o `~` no caminho | Usar `~/sei-pacote` |
| `Permission denied` ao extrair na pasta pessoal | Pasta criada com `sudo` (dono `root`) | `sudo chown -R opc:opc ~/sei-pacote` |
| `/var/log/mysqld.log` não existe | MySQL do AppStream guarda o log em `/var/log/mysql/` e não gera senha temporária | Seguir direto para `mysql_secure_installation` |
| `ERROR 1045 ... Access denied` (root ou `sei_user`) | Senha digitada diferente da definida | Repetir com atenção ou redefinir com `ALTER USER` |
| `Character set 'latini1'` | Erro de digitação na configuração | `latin1` |
| `Parse error ... unexpected ':'` | `:` digitado no modo de inserção do vim | Apagar o `:`; sempre `Esc` antes de `:wq` |
| `PHP Parse error ... unexpected end of file` → erro 500 | Última `}` do arquivo apagada | Restaurar a `}`; conferir com `php -l` |
| Login falha com "Erro acessando arquivo WSDL" | `PaginaLogin` e `SipWsdl` invertidos | Conferir os valores da Etapa 9 |
| `E45: 'readonly' option is set` / `.swp` | vim pausado com Ctrl+Z | `fg` e sair com `:q!`; desfazer é `u` |
| Comando `:NNs/...` do vim não alterou o arquivo | Comando não digitado ou sem `Esc` antes | Conferir sempre com `grep` depois do `:wq` |
| Pastas do sistema com `dr-xrws---` | `2570` aplicado sem o `/temp` no caminho | Refazer o `2750` e depois o `2570` só na `temp` |
| Arquivos do sistema com `-rw-r--r--` (ex.: `ConfiguracaoSEI.php`) | `find -type f` do `chmod 0640` não aplicado | Repetir e conferir com `find ... ! -perm 0640 \| wc -l` |
| Rótulo do SELinux não muda nas `temp` | Regra do `semanage` criada com o caminho errado | `semanage fcontext -l -C`, remover com `-d` e criar de novo |
| Apache sem permissão para gravar em `temp` ou `/var/sei/arquivos` | Rótulo `usr_t`/`var_t` com o SELinux `Enforcing` | Rótulo `httpd_sys_rw_content_t` (Etapa 9) |
| `$'\r': command not found` | Script com CRLF (Windows) | `dos2unix` |
| Solr não inicia após editar memória | `Xmx` apagado | `-Xmx2g` |
| Solr ignora a memória configurada | `#` ainda no início da linha `SOLR_JAVA_MEM` | Tirar o `#` |
| `curl http://localhost:8983/solr/` responde `500` | `localhost` resolve para IPv6, fora do filtro de IPs | Usar `127.0.0.1` no `ConfiguracaoSEI.php` |
| Agendamentos do SIP não rodam | Falta `SIP_EMAIL_ADMINISTRADOR` | Criar o parâmetro |
| `Could not open input file: .../AgendamentoTarefaSIP.php` | Nome com `SIP` em maiúsculas ou pasta do outro sistema | `AgendamentoTarefaSip.php` em `/opt/sip/scripts` |
| `grep sei-agendamentos /var/log/cron` não mostra nada | O log guarda o comando, não o nome do arquivo | `grep AgendamentoTarefa /var/log/cron` |
| Log do SIP: "Erro enviando correspondência eletrônica" | Não há servidor de e-mail na VM | Esperado no laboratório; desativar o `testarAgendamento` |
| Pesquisa por documento não encontra | Rascunho não é indexado | Assinar o documento |
| `ERR_CONNECTION_RESET` ao acessar pelo IP público | Firewall/rede da nuvem não repassam a porta 80 | Usar o túnel SSH do MobaXterm |
| PDF do processo não é gerado | wkhtmltopdf não instalado | Instalar o wkhtmltopdf 0.12.6 |
| Aviso de chave de acesso padrão | `Producao => true` com a chave da base | Gerar novas chaves no SIP |

Comandos de diagnóstico:

```bash
sudo tail -n 20 /var/log/httpd/error_log
sudo php -l ARQUIVO.php
systemctl status SERVICO
sudo journalctl -u solr -n 30
sudo ss -tlnp
sudo ausearch -m avc -ts recent
```

> O `ausearch` lista as negativas recentes do SELinux. Se o sistema falhar sem erro claro e o `getenforce` for `Enforcing`, é o primeiro lugar para olhar.

---

## Adaptações em relação ao manual

| Manual | Neste laboratório | Motivo |
| --- | --- | --- |
| Comandos para CentOS | `dnf`, módulos do `dnf` e `semanage` | Oracle Linux 8 |
| Vários servidores | Uma VM | Laboratório |
| PHP 7.3.12 | PHP 7.3.20 (`dnf module enable php:7.3`) | Versão do repositório |
| memcache 4.0.4 | memcache 4.0.5.2 (PECL) | 4.0.4 indisponível |
| igbinary por pacote | igbinary compilada (PECL) | Sem pacote no repositório |
| sodium | Não instalada | Sem pacote; só a Federação a usa |
| Memcached 1.4.25 | 1.5.22 | Repositório padrão |
| MySQL 5.7 | MySQL 8.0.x (módulo `mysql:8.0`) | O manual aceita o 8.0 com `mysql_native_password` |
| Ajustes no php.ini | `/etc/php.d/99-sei.ini` | Organização |
| Ajustes no `my.cnf` | `/etc/my.cnf.d/99-sei.cnf` | `my.cnf` só inclui a pasta |
| SELinux "se estiver ativo" | `Enforcing` com 6 booleans e rótulos de gravação | Padrão do Oracle Linux |
| `RepositorioArquivos` `/dados` | `/var/sei/arquivos` | `/dados` é do Solr |
| JODConverter | Comentado | Opcional |
| Solr com 6 GB | 2 GB | VM de 7,5 GB compartilhada |
| Lista de IPs do Solr | só `127.0.0.1` | SEI e Solr na mesma máquina |
| Endereço do Solr com `localhost` | `127.0.0.1` | `localhost` resolve para IPv6 |
| Endereço do sistema (DNS) | `localhost` por túnel SSH | Sem DNS e firewall só com `ssh` |
| Módulos | Ignorados | Orientação do laboratório |
| `https => true` | `false` | Certificado autoassinado |

---

## Pontos de melhoria

**Segurança**

- Integrar o SIP ao LDAP/AD (seção 7 do manual)
- Gerar novas chaves de acesso do SEI e do SIP
- Certificado de autoridade reconhecida e `https => true`
- MySQL só local: `bind-address = 127.0.0.1` no `/etc/my.cnf.d/99-sei.cnf` e avaliar desativar o protocolo X (porta 33060)
- Desligar a porta 18983 do Solr e o `rpcbind` (porta 111)
- Esconder versões nos cabeçalhos (`ServerTokens Prod`, `expose_php = Off`)
- Manter o `firewalld` só com o necessário (`ssh` e, se houver acesso por IP, `http`/`https`)

**Funcionalidades**

- wkhtmltopdf 0.12.6 para gerar PDF do processo
- Extensão uploadprogress (`/opt/sei/config/uploadprogress`)
- Extensão sodium (SEI Federação)
- Servidor de e-mail (por exemplo, `sendmail` ou um relay SMTP no `InfraMail`) para os agendamentos de teste e as notificações

**Sustentação**

- PHP 7.3 e Solr 8.2.0 são versões antigas: revisar periodicamente
- Backup das bases e de `/var/sei/arquivos` (seção 13 do manual)
- Persistir o túnel de acesso ou prever um DNS para a VM

---

## Referências

- Manual oficial: `INSTALACAO 4.0.12.15.md` (seções 2, 3, 4, 5, 6, 11, 16, 21 e 22)
- Versão para Amazon Linux 2: [README.md](README.md)
- Diferenças entre as duas versões: [diferencas/aws-vs-oracle-linux.md](diferencas/aws-vs-oracle-linux.md)
- Arquivo de versões do Solr: https://archive.apache.org/dist/lucene/solr/8.2.0/
- PECL memcache: https://pecl.php.net/package/memcache
- PECL igbinary: https://pecl.php.net/package/igbinary

---

Autora: Alice Vivas Nava — [@alicevnava](https://github.com/alicevnava)
