# Laboratório SEI/SIP 4.0 em Amazon Linux 2

Instalação completa do **SEI** (Sistema Eletrônico de Informações) e do **SIP** (Sistema de Permissões) versão **4.0.12.15** em uma única instância EC2, seguindo o manual oficial `INSTALACAO 4.0.12.15.md`, com as adaptações necessárias para o Amazon Linux 2.

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
- [Etapa 6 - Banco de dados (MySQL 5.7)](#etapa-6---banco-de-dados-mysql-57)
- [Etapa 7 - Permissões e publicação no Apache](#etapa-7---permissões-e-publicação-no-apache)
- [Etapa 8 - Configurar o SIP](#etapa-8---configurar-o-sip)
- [Etapa 9 - Configurar o SEI](#etapa-9---configurar-o-sei)
- [Etapa 10 - Primeiro login](#etapa-10---primeiro-login)
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

Tudo roda na mesma EC2. No manual (pensado para produção) cada serviço fica em um servidor separado.

| Serviço | Função | Porta | Configuração |
| --- | --- | --- | --- |
| Apache 2.4 | Servidor web: recebe o navegador e entrega as páginas | 80 / 443 | `/etc/httpd/conf.d/sei.conf` |
| PHP 7.3 (php-fpm) | Executa o código do SEI, do SIP e do InfraPHP | — | `/etc/php.d/99-sei.ini` |
| SIP | Login, usuários, perfis, unidades e permissões | — | `/opt/sip/config/ConfiguracaoSip.php` |
| SEI | Processos e documentos | — | `/opt/sei/config/ConfiguracaoSEI.php` |
| MySQL 5.7 | Bases `sei` e `sip` | 3306 | `/etc/my.cnf` |
| Memcached | Cache de sessões e permissões | 11211 (só local) | `/etc/sysconfig/memcached` |
| Solr 8.2.0 (Java 8) | Indexação e pesquisa | 8983 (só 127.0.0.1) | `/opt/solr`, `/dados` |
| Cron | Agendamentos e limpeza | — | `/etc/cron.d/sei-*` |
| Repositório de arquivos | Documentos anexados | — | `/var/sei/arquivos` |

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
- Arquivos e permissões conforme o manual
- Agendamentos rodando e HTTPS ativo no servidor

---

## Pré-requisitos

| Item | Exigência |
| --- | --- |
| Sistema operacional | Amazon Linux 2 (`cat /etc/os-release`) |
| Recursos | Mínimo 4 GB de RAM, 2 CPUs e 20 GB de disco (2 GB livres em `/tmp`) |
| Acesso | SSH com o usuário `ec2-user` e permissão de `sudo` |
| Rede (Security Group) | Portas **22** (SSH), **80** (HTTP) e **443** (HTTPS) liberadas para quem vai acessar |
| Internet | Necessária para os repositórios da Amazon, do MySQL e do download do Solr |
| Pacote do SEI | `/opt/sei-lab/sei-4.0.12.15.zip` |
| Manual | `/opt/sei-lab/INSTALACAO 4.0.12.15.md` |

Downloads externos usados (autorizados pelo responsável do laboratório):

| O quê | Origem |
| --- | --- |
| Repositório do MySQL 5.7 | `https://dev.mysql.com/get/mysql57-community-release-el7-11.noarch.rpm` |
| Chave GPG do MySQL | `https://repo.mysql.com/RPM-GPG-KEY-mysql-2022` |
| Extensão memcache 4.0.5.2 | PECL (`pecl install`) |
| Solr 8.2.0 | `https://archive.apache.org/dist/lucene/solr/8.2.0/solr-8.2.0.tgz` |

---

## Variáveis do ambiente

Nos comandos abaixo, **troque os marcadores** pelos valores do seu ambiente.

| Marcador | Significado | Exemplo |
| --- | --- | --- |
| `SEU_ENDERECO` | DNS público da EC2 (use sempre o mesmo, nunca misture com o IP) | `ec2-x-x-x-x.compute-1.amazonaws.com` |
| `SUA_SIGLA` | Sigla do órgão (maiúsculas, sem espaço e sem acento) | `TRAINEE05` |
| `SUA_DESCRICAO` | Nome do órgão (sem acento) | `Laboratorio Trainee 05` |
| `SENHA_SEI_USER` | Senha do usuário de banco do sistema | escolha uma senha forte |

> Use o **DNS público** e não o IP: dentro da AWS ele aponta para o IP privado da própria máquina, então o SEI e o SIP conseguem chamar um ao outro.

Dicas gerais:

- Rode **um comando por vez** e confira a saída antes de seguir.
- No vim: `i` edita, `Esc` sai da edição, `:wq` salva e sai, `:q!` sai sem salvar, `u` desfaz. **Nunca use Ctrl+Z** (pausa o vim).
- Antes de colar um bloco no vim, digite `:set paste`.
- Depois de editar qualquer `.php`, confira com `sudo php -l ARQUIVO`.

---

## Etapa 1 - Preparação

Conferir o sistema (deve ser Amazon Linux 2, que usa `yum`):

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
sudo yum update -y
```

Instalar utilitários (descompactar, editar, testar URLs e portas, ver árvore de pastas):

```bash
sudo yum install -y unzip tar vim curl wget tree nmap-ncat
```

Ver o modo do SELinux:

```bash
getenforce
```

Esperado neste laboratório: `Disabled`. Se estiver `Enforcing`, aplicar os `setsebool` da seção 2 do manual (um comando por linha, com `-P` digitado com hífen).

Ler o manual (sumário pelos títulos):

```bash
cd /opt/sei-lab
grep -n '^#' "INSTALACAO 4.0.12.15.md"
less "INSTALACAO 4.0.12.15.md"
```

---

## Etapa 2 - Pacote do SEI

Ver o conteúdo do pacote sem extrair:

```bash
unzip -l /opt/sei-lab/sei-4.0.12.15.zip
```

Esperado: `NOTA_VERSAO.md`, `sei-Fontes-4.0.12.15.zip` e os dumps `sei-bd-mysql`, `sei-bd-oracle` e `sei-bd-sqlserver`.

Extrair em uma pasta de trabalho:

```bash
mkdir -p ~/sei-pacote
unzip -q /opt/sei-lab/sei-4.0.12.15.zip -d ~/sei-pacote
```

Extrair só os fontes e o dump do MySQL:

```bash
unzip -q ~/sei-pacote/sei-Fontes-4.0.12.15.zip -d ~/sei-pacote/fontes
unzip -q ~/sei-pacote/sei-bd-mysql-4.0.12.15.zip -d ~/sei-pacote/bd
ls ~/sei-pacote/fontes ~/sei-pacote/bd
```

Esperado: `infra sei sip` e os arquivos `sei_4.0.x.1_BD_Ref_Exec.sql` e `sip_4.0.x.1_BD_Ref_Exec.sql`.

Copiar para `/opt`:

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

---

## Etapa 3 - Apache

```bash
sudo yum install -y httpd
sudo systemctl enable --now httpd
systemctl status httpd
```

Esperado: `enabled` e `active (running)`.

Testar:

```bash
curl -I http://localhost
```

Esperado: `HTTP/1.1 403 Forbidden` ou `200 OK` (página padrão do Apache). Não pode aparecer `Connection refused`.

---

## Etapa 4 - PHP 7.3 e extensões

### Instalar o PHP 7.3

O manual exige PHP 7.3. No Amazon Linux 2 ele vem pelo `amazon-linux-extras` (o tópico não aparece na lista por estar sem suporte, mas instala normalmente):

```bash
sudo amazon-linux-extras install php7.3
php -v
```

Esperado: `PHP 7.3.33 (cli)`.

### Extensões

| Grupo | Extensões | Uso no SEI |
| --- | --- | --- |
| Banco de dados | mysqli | Conversar com o MySQL |
| Comunicação | soap, curl, openssl, json, dom, libxml, SimpleXML | SEI ↔ SIP por web service (SOAP/XML) |
| Texto | mbstring, iconv, intl, gettext, pcre, ctype, filter | Acentos, datas e validação |
| Arquivos | gd, exif, fileinfo, zip, bz2, zlib, Phar | Imagens, tipos de arquivo, compactação |
| Cálculo | date, calendar, bcmath | Prazos e cálculos |
| Segurança | sodium, hash | Criptografia e hash dos documentos |
| Cache | memcache, igbinary | Ponte entre o PHP e o Memcached |
| Login corporativo | ldap | Integração com AD/LDAP |
| Upload | uploadprogress | Barra de progresso (opcional) |

Ver as extensões já carregadas:

```bash
php -m
```

Instalar as que faltam:

```bash
sudo yum install -y php-bcmath php-xml php-soap php-intl php-ldap php-sodium
sudo yum install -y php-pecl-igbinary
```

> Não instalar o `php-pecl-memcache` do yum: ele vem do repositório `amzn2-core`, versão 3.0.8, feita para PHP 5.4. Também não confundir com `memcached` (com "d"): o SEI usa **memcache**.

### Compilar a extensão memcache

Ferramentas de compilação:

```bash
sudo yum install -y php-devel php-pear gcc make zlib-devel
pecl version
```

Esperado: `PHP Version: 7.3.33`.

Compilar (responder **Enter** às perguntas). A versão 4.0.4 do manual não está mais disponível no PECL; a 4.0.5.2 é da mesma família e compatível com PHP 7:

```bash
sudo pecl install memcache-4.0.5.2
```

Esperado: `install ok: channel://pecl.php.net/memcache-4.0.5.2`.

Ativar a extensão:

```bash
echo "extension=memcache.so" | sudo tee /etc/php.d/40-memcache.ini
php -m
```

Esperado: `memcache` na lista.

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

O Apache executa o PHP pelo **php-fpm**. Habilitar no boot e reiniciar para ler as extensões e o `99-sei.ini`:

```bash
sudo systemctl enable php-fpm
sudo systemctl restart php-fpm
systemctl status php-fpm
```

Esperado: `enabled` e `active (running)`.

Testar o PHP pelo Apache (página temporária):

```bash
echo "<?php phpinfo();" | sudo tee /var/www/html/teste.php
curl -s http://localhost/teste.php | grep short_open_tag
curl -s http://localhost/teste.php | grep "memcache support"
sudo rm /var/www/html/teste.php
```

Esperado: `short_open_tag ... On` e `memcache support ... enabled`. A página é apagada no final porque expõe detalhes do servidor.

---

## Etapa 5 - Memcached

```bash
sudo yum install -y memcached
cat /etc/sysconfig/memcached
```

Conferir que a linha `OPTIONS` tem `-l 127.0.0.1` (só acesso local). Se estiver vazia:

```bash
sudo sed -i 's/^OPTIONS=.*/OPTIONS="-l 127.0.0.1"/' /etc/sysconfig/memcached
```

Ligar e testar:

```bash
sudo systemctl enable --now memcached
printf "stats\nquit\n" | nc 127.0.0.1 11211 | head -5
```

Esperado: linhas começando com `STAT` (pid, uptime, version...).

---

## Etapa 6 - Banco de dados (MySQL 5.7)

### Instalar

O repositório da Amazon só tem MariaDB 5.5. Adicionar o repositório oficial do MySQL:

```bash
sudo yum install -y https://dev.mysql.com/get/mysql57-community-release-el7-11.noarch.rpm
yum repolist | grep -i mysql
```

Esperado: a linha `mysql57-community`.

Importar a chave de assinatura atual e instalar:

```bash
sudo rpm --import https://repo.mysql.com/RPM-GPG-KEY-mysql-2022
sudo yum install -y mysql-community-server
mysql --version
```

Esperado: `Distrib 5.7.44`.

Ligar:

```bash
sudo systemctl enable --now mysqld
systemctl status mysqld
```

### Senha do root do banco

Na primeira inicialização o MySQL gera uma senha temporária:

```bash
sudo grep 'temporary password' /var/log/mysqld.log
```

> A senha é **tudo depois de** `root@localhost: `, inclusive pontuação no final (por exemplo, uma vírgula). Copie arrastando o mouse, sem duplo clique.

Definir a senha definitiva e proteger o banco:

```bash
sudo mysql_secure_installation
```

| Pergunta | Resposta |
| --- | --- |
| Enter password for user root | senha temporária |
| New password | senha forte (maiúscula, minúscula, número e símbolo) |
| Change the password for root? | n |
| Remove anonymous users? | y |
| Disallow root login remotely? | y |
| Remove test database and access to it? | y |
| Reload privilege tables now? | y |

Esperado: `All done!`.

### Charset latin1

```bash
sudo cp /etc/my.cnf /etc/my.cnf.original
sudo vim /etc/my.cnf
```

Acrescentar no **final** do arquivo (a seção `[mysqld]` é a última, então as três primeiras linhas ficam dentro dela):

```ini
# Ajustes do SEI - charset latin1 (Problema 10 do manual)
character-set-server = latin1
collation-server = latin1_swedish_ci
max_allowed_packet = 64M

[client]
default-character-set = latin1
```

Reiniciar e conferir:

```bash
sudo systemctl restart mysqld
mysql -u root -p -e "SHOW VARIABLES LIKE 'character_set%';"
```

Esperado: `client`, `connection`, `database`, `results` e `server` como `latin1`.

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
mysql -u root -p -e "SHOW TABLES FROM sip;"
mysql -u root -p -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='sei';"
```

Esperado: 39 tabelas no SIP e 267 no SEI.

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

Base do SEI (a sigla **deve** ser a mesma):

```bash
mysql -u root -p sei
```

```sql
UPDATE orgao SET sigla='SUA_SIGLA', descricao='SUA_DESCRICAO' WHERE id_orgao=0;
SELECT id_orgao, sigla, descricao FROM orgao;
EXIT;
```

Testar o usuário do sistema:

```bash
mysql -u sei_user -p -e "SELECT sigla FROM sip.orgao; SELECT sigla FROM sei.orgao;"
```

Esperado: `SUA_SIGLA` nas duas consultas.

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

Conferir (precisa de `sudo`, porque os "outros" não têm acesso):

```bash
sudo ls -ld /opt/sei /opt/sei/temp /opt/sip /opt/sip/temp /opt/infra
```

Esperado: `drwxr-s--- root apache` e, nas pastas `temp`, `dr-xrws--- root apache`.

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
sudo vim /opt/sip/config/ConfiguracaoSip.php
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

> Valores entre aspas simples e vírgula no fim de cada linha. `true` e `false` sem aspas. Não apagar a última `}` do arquivo.

Conferir:

```bash
sudo php -l /opt/sip/config/ConfiguracaoSip.php
sudo grep -n -E "URL|Producao|SiglaOrgao|PaginaLogin|SipWsdl|https|Servidor|Porta|Banco'|Usuario|Tipo" /opt/sip/config/ConfiguracaoSip.php
sudo ls -la /opt/sip/config
```

Esperado: `No syntax errors detected`, os valores da tabela e nenhum arquivo `.swp`.

---

## Etapa 9 - Configurar o SEI

```bash
sudo cp -p /opt/sei/config/ConfiguracaoSEI.exemplo.php /opt/sei/config/ConfiguracaoSEI.php
sudo vim /opt/sei/config/ConfiguracaoSEI.php
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
| Solr | Servidor | `http://localhost:8983/solr` |
| JODConverter | bloco inteiro | comentar com `//` (servidor opcional, não instalado) |

> `PaginaLogin` e `SipWsdl` apontam para o **/sip**: o login é feito no SIP. Cuidado para não inverter os dois.
>
> O `RepositorioArquivos` não usa `/dados` (valor do exemplo) porque essa pasta será usada pelos índices do Solr.

Bloco do JODConverter comentado:

```php
            //'JODConverter' => array(
            //    'Servidor' => 'http://[Servidor JodConverter]/converter/service'
            //),
```

Conferir:

```bash
sudo php -l /opt/sei/config/ConfiguracaoSEI.php
sudo grep -n -E "URL|Producao|Repositorio|SiglaOrgao|PaginaLogin|SipWsdl|https|Servidor|Porta|Banco'|Usuario|Tipo|JODConverter" /opt/sei/config/ConfiguracaoSEI.php
```

### Repositório de arquivos

```bash
sudo mkdir -p /var/sei/arquivos
sudo chown apache:apache /var/sei/arquivos
sudo chmod 750 /var/sei/arquivos
sudo ls -ld /var/sei/arquivos
```

Esperado: `drwxr-x--- apache apache`.

---

## Etapa 10 - Primeiro login

Conferir que o endereço aponta para a própria máquina e que o SIP responde:

```bash
getent hosts SEU_ENDERECO
curl -I http://SEU_ENDERECO/sip/
```

Esperado: um IP privado (10.x ou 172.x) e `HTTP/1.1 302 Found` com `Location:` contendo `sigla_orgao_sistema=SUA_SIGLA`.

Em outra aba do terminal, acompanhar os erros em tempo real (Ctrl+C para sair):

```bash
sudo tail -f /var/log/httpd/error_log
```

No navegador (usuário `teste`, senha `teste`):

- `http://SEU_ENDERECO/sip` → menu do SIP com o nome do órgão no topo
- `http://SEU_ENDERECO/sei` → login do SIP e depois **Controle de Processos** do SEI

<!-- IMAGEM: imagens/sip-menu.png -->
<!-- IMAGEM: imagens/sei-controle-processos.png -->

---

## Etapa 11 - Solr

### Java 8 e usuário

```bash
sudo yum install -y java-1.8.0-openjdk-headless
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

> O `/.` copia o conteúdo da pasta. Com `solr/*` o comando falharia, porque o `*` é expandido pelo `ec2-user`, que não tem acesso a `/opt/sei/config`.

### Converter os arquivos para o formato Linux

O script e o serviço vêm com quebras de linha do Windows (CRLF) e falham com `$'\r': command not found`:

```bash
sudo yum install -y dos2unix
sudo dos2unix /tmp/sei-solr-8.2.0.sh /tmp/solr.service
sudo file /tmp/sei-solr-8.2.0.sh /tmp/solr.service
```

Esperado: `ASCII text`, sem `with CRLF line terminators`.

### Instalar (executar uma única vez)

Ler o script antes de executar:

```bash
sudo cat /tmp/sei-solr-8.2.0.sh
sudo bash /tmp/sei-solr-8.2.0.sh
```

O script descompacta o Solr em `/opt/solr`, cria `/dados` com os três índices do SEI, entrega tudo ao usuário `solr` e instala o serviço. Esperado: linhas `mkdir: created directory` e nenhuma linha com erro.

```bash
sudo tree -d /dados
sudo ls -ld /dados /opt/solr
```

Esperado: `sei-bases-conhecimento`, `sei-protocolos` e `sei-publicacoes`, cada um com `conf` e `conteudo`, e dono `solr solr`.

### Memória

O manual usa 6 GB para um servidor dedicado de 8 GB. Numa EC2 compartilhada com os outros serviços, usar cerca de 1/4 da RAM (`free -h`):

```bash
grep -n "SOLR_JAVA_MEM" /opt/solr/bin/solr.in.sh
sudo vim +NUMERO_DA_LINHA /opt/solr/bin/solr.in.sh
```

Tirar o `#` do início e deixar a linha assim (exemplo para 4 GB de RAM):

```
SOLR_JAVA_MEM="-Xms512m -Xmx1g"
```

### Ligar o serviço

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now solr
systemctl status solr
```

Esperado: `active (running)` e o processo `java ... -Xms512m -Xmx1g`.

Conferir os índices:

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

O arquivo já tem este item (3 linhas) dentro de `<Array type="org.eclipse.jetty.server.Handler">`:

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

No vim: abrir na linha do `<Item>` do Contexts, `:set paste`, `3dd` para apagar as 3 linhas, `O` (maiúsculo) para abrir uma linha acima, colar, `Esc`, `:wq`. Os itens `InstrumentedHandler` e `RequestLog` ficam como estão.

```bash
xmllint --noout /opt/solr/server/etc/jetty.xml
sudo systemctl restart solr
```

Esperado: `xmllint` sem saída (XML válido).

Testar:

```bash
curl -I http://127.0.0.1:8983/solr/
curl -I http://IP_PRIVADO_DA_EC2:8983/solr/
curl -I http://localhost:8983/solr/
```

Esperado: `200 OK`, **`403 Forbidden`** e `200 OK`. O 403 prova que a restrição funciona.

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

> Os comandos de limpeza de índices do fim da seção 21 do manual **apagam** os índices. Só servem para reindexar no futuro.

---

## Etapa 12 - Agendamentos

O SEI e o SIP têm tarefas automáticas cadastradas em Infra → Agendamentos. O cron executa, a cada minuto, um script que verifica quais estão na hora de rodar.

### Parâmetro obrigatório no SIP

A base de referência do SIP não tem o parâmetro `SIP_EMAIL_ADMINISTRADOR`, e sem ele o script de agendamento do SIP falha (`Parâmetro SIP_EMAIL_ADMINISTRADOR não encontrado`).

Conferir:

```bash
mysql -u root -p sip -e "SELECT nome, valor FROM infra_parametro WHERE nome LIKE 'SIP_EMAIL%';"
mysql -u root -p sei -e "SELECT nome, valor FROM infra_parametro WHERE nome LIKE 'SEI_EMAIL%';"
```

Se faltar, criar no SIP em **Infra → Parâmetros → Novo**:

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

Testar os scripts manualmente (sem saída = sem erro):

```bash
sudo /usr/bin/php -c /etc/php.ini /opt/sei/scripts/AgendamentoTarefaSEI.php
sudo /usr/bin/php -c /etc/php.ini /opt/sip/scripts/AgendamentoTarefaSip.php
```

> Se um agendamento não rodar, execute o script manualmente: o erro aparece na tela. Os logs em `/root/infra_agendamento_*.log` não recebem as mensagens de erro.

### Conferir pelo sistema

- **Infra → Agendamentos** (SEI e SIP): a última execução das tarefas de periodicidade "Minuto" deve ser de hoje.
- O `testarAgendamento` grava um registro em **Infra → Log** a cada 5 minutos. No SEI ele vem desativado: reativar para testar e, depois de conferir, desativar nos dois sistemas.

<!-- IMAGEM: imagens/sip-agendamentos.png -->
<!-- IMAGEM: imagens/sei-infra-log.png -->

---

## Etapa 13 - HTTPS

```bash
sudo yum install -y mod_ssl
sudo systemctl restart httpd
sudo ss -tlnp | grep httpd
curl -kI https://localhost/sip/
```

Esperado: Apache nas portas 80 e 443 e `HTTP/1.1 302 Found`. O `mod_ssl` gera um certificado **autoassinado**; o `-k` faz o curl aceitá-lo.

Testar a porta a partir do computador do usuário (PowerShell):

```powershell
Test-NetConnection SEU_ENDERECO -Port 443
```

Esperado: `TcpTestSucceeded : True`.

No navegador, `https://SEU_ENDERECO/sip` mostra um aviso de certificado não confiável (esperado com certificado autoassinado): Avançado → Continuar.

### Ativar o HTTPS nos sistemas (seção 16 do manual)

Só ativar se os usuários conseguirem abrir `https://` no navegador. Com isso o sistema passa a forçar HTTPS.

1. `'https' => true` no `ConfiguracaoSip.php` e no `ConfiguracaoSEI.php` (conferir com `php -l`).
2. SIP → Sistemas → Listar → SEI → Página Inicial: `https://SEU_ENDERECO/sei/inicializar.php`.
3. Manter o Web Service e o `SipWsdl` em `http://`: com certificado autoassinado, o PHP recusa a conexão interna e o login quebra.

> Neste laboratório o `https` ficou em `false`: a rede corporativa bloqueia certificados autoassinados (pela rede móvel a tela de login abriu normalmente por https://). Em produção, usar um certificado de autoridade reconhecida.

---

## Etapa 14 - Finalização e validação

### Modo de produção

Trocar `'Producao' => false` por `true` nos dois arquivos de configuração:

```bash
sudo vim /opt/sip/config/ConfiguracaoSip.php
sudo vim /opt/sei/config/ConfiguracaoSEI.php
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
| Portas | `sudo ss -tlnp` | 80, 443, 3306, 11211 (127.0.0.1), 8983, 22 |
| Banco | `mysql -u sei_user -p -e "SELECT sigla FROM sip.orgao; SELECT sigla FROM sei.orgao;"` | `SUA_SIGLA` nas duas |
| Memcached | `printf "stats\nquit\n" \| nc 127.0.0.1 11211 \| head -5` | linhas `STAT` |
| Solr | `curl -s "http://127.0.0.1:8983/solr/admin/cores?action=STATUS" \| grep '"name"'` | 3 índices |
| Pastas | `sudo ls -ld /opt/sei /opt/sei/temp /opt/sip /opt/sip/temp /opt/infra /var/sei/arquivos /opt/solr /dados` | donos e permissões das etapas 7, 9 e 11 |
| Configs do sistema | `sudo ls -l /opt/sip/config/ConfiguracaoSip.php /opt/sei/config/ConfiguracaoSEI.php` | `-rw-r----- root apache` |
| Configs criadas | `ls -l /etc/httpd/conf.d/sei.conf /etc/php.d/99-sei.ini /etc/php.d/40-memcache.ini /etc/cron.d/sei-limpeza /etc/cron.d/sei-agendamentos` | `-rw-r--r-- root root` |
| Navegador | SIP e SEI com `teste`/`teste` | menu do SIP e Controle de Processos |
| Infra → Log | SEI e SIP | sem erros sem causa conhecida |

---

## Testes como usuário

### SEI

| Teste | Como | Resultado |
| --- | --- | --- |
| Criar processo | Iniciar Processo → tipo → Especificação → Público → Salvar | ✔ |
| Pesquisar processo | Pesquisa → marcar Processos → Especificação | ✔ abre o processo |
| Anexar PDF | Incluir Documento → Externo → anexar | ✔ gravado em `/var/sei/arquivos/AAAA/MM/DD/` |
| Documento no editor | Incluir Documento → Memorando → escrever → Salvar | ✔ |
| Assinar | Assinar → cargo → senha | ✔ |
| Pesquisar conteúdo | Pesquisa → Documentos → Texto para Pesquisa | ✔ (só depois de assinado) |
| Gerar PDF do processo | Gerar Arquivo PDF do Processo | ✘ falta o wkhtmltopdf (Problema nº 14) |
| Concluir e reabrir | Concluir Processo / Reabrir Processo | ✔ |

> O editor abre em pop-up: liberar pop-ups do site no navegador.
>
> Documentos criados no editor só são indexados pelo Solr **depois de assinados**.

<!-- IMAGEM: imagens/sei-documento-assinado.png -->
<!-- IMAGEM: imagens/sei-pesquisa.png -->
<!-- IMAGEM: imagens/sei-erro-pdf.png -->

### SIP

| Teste | Como | Resultado |
| --- | --- | --- |
| Registro de acessos | Acessos → Pesquisar | ✔ usuário, sistema, data, IP e navegador |
| Novo usuário | Usuários → Novo | ✔ |
| Permissão | Permissões → Atribuir: SEI / TESTE / perfil | ✔ |
| Login com o novo usuário | login = **sigla**, senha = **sigla** | ✔ |
| Recurso sem permissão | tela fora do perfil | ✔ "Acesso negado a este recurso nesta unidade" |

> Sem LDAP/AD configurado, o SIP aceita a própria sigla como senha.
>
> O login é a **Sigla** do cadastro, não o Nome.

<!-- IMAGEM: imagens/sip-acessos.png -->

---

## Problemas e soluções

| Problema | Causa | Solução |
| --- | --- | --- |
| Comandos colados e `–P` no manual | Formatação do documento | Um comando por linha e `-P` com hífen |
| `dnf: command not found` | Amazon Linux 2 | `yum` e `amazon-linux-extras` |
| `pecl install memcache-4.0.4` falha | Versão indisponível | `memcache-4.0.5.2` |
| Senha temporária do MySQL recusada | Pontuação final faz parte da senha | Copiar a senha inteira |
| `Character set 'latini1'` | Erro de digitação no `my.cnf` | `latin1` |
| `Parse error ... unexpected ':'` | `:` digitado no modo de inserção do vim | Apagar o `:`; sempre `Esc` antes de `:wq` |
| `PHP Parse error ... unexpected end of file` → erro 500 | Última `}` do arquivo apagada | Restaurar a `}`; conferir com `php -l` |
| Login falha com "Erro acessando arquivo WSDL" | `PaginaLogin` e `SipWsdl` invertidos | Conferir os valores da Etapa 9 |
| `E45: 'readonly' option is set` / `.swp` | vim pausado com Ctrl+Z | `fg` e sair com `:q!`; desfazer é `u` |
| `$'\r': command not found` | Script com CRLF (Windows) | `dos2unix` |
| Solr não inicia após editar memória | `Xmx` apagado | `-Xmx1g` |
| Agendamentos do SIP não rodam | Falta `SIP_EMAIL_ADMINISTRADOR` | Criar o parâmetro |
| Pesquisa por documento não encontra | Rascunho não é indexado | Assinar o documento |
| HTTPS bloqueado no navegador | Rede bloqueia certificado autoassinado | Testar por outra rede; manter `https => false` |
| PDF do processo não é gerado | wkhtmltopdf não instalado | Instalar o wkhtmltopdf 0.12.6 |
| Aviso de chave de acesso padrão | `Producao => true` com a chave da base | Gerar novas chaves no SIP |

Comandos de diagnóstico:

```bash
sudo tail -n 20 /var/log/httpd/error_log
sudo php -l ARQUIVO.php
systemctl status SERVICO
sudo journalctl -u solr -n 30
sudo ss -tlnp
```

> Linhas no `error_log` com IPs externos procurando arquivos como `xor.php` ou `wp-css.php` são robôs varrendo a internet. Não têm relação com o SEI.

---

## Adaptações em relação ao manual

| Manual | Neste laboratório | Motivo |
| --- | --- | --- |
| Comandos para CentOS | `yum` e `amazon-linux-extras` | Amazon Linux 2 |
| Vários servidores | Uma EC2 | Laboratório |
| PHP 7.3.12 | PHP 7.3.33 | Versão disponível |
| memcache 4.0.4 | memcache 4.0.5.2 (PECL) | 4.0.4 indisponível |
| Memcached 1.4.25 | 1.4.15 | Repositório padrão |
| MySQL 5.7 | MySQL 5.7.44 (repositório oficial) | Repositório padrão só tem MariaDB 5.5 |
| Ajustes no php.ini | `/etc/php.d/99-sei.ini` | Organização |
| SELinux | Não aplicado | Desativado na EC2 |
| `RepositorioArquivos` `/dados` | `/var/sei/arquivos` | `/dados` é do Solr |
| JODConverter | Comentado | Opcional |
| Solr com 6 GB | 1 GB | EC2 com 3,8 GB compartilhados |
| Lista de IPs do Solr | só `127.0.0.1` | SEI e Solr na mesma máquina |
| Módulos | Ignorados | Orientação do laboratório |
| `https => true` | `false` | Rede corporativa bloqueia certificado autoassinado |

---

## Pontos de melhoria

**Segurança**

- Integrar o SIP ao LDAP/AD (seção 7 do manual)
- Gerar novas chaves de acesso do SEI e do SIP
- Certificado de autoridade reconhecida e `https => true`
- MySQL só local: `bind-address = 127.0.0.1` no `/etc/my.cnf`
- Desligar a porta 18983 do Solr e o `rpcbind` (porta 111)
- Esconder versões nos cabeçalhos (`ServerTokens Prod`, `expose_php = Off`)

**Funcionalidades**

- wkhtmltopdf 0.12.6 para gerar PDF do processo
- Extensão uploadprogress (`/opt/sei/config/uploadprogress`)

**Sustentação**

- Amazon Linux 2, PHP 7.3 e MySQL 5.7 estão sem suporte
- Backup das bases e de `/var/sei/arquivos` (seção 13 do manual)
- Swap ou mais memória

---

## Referências

- Manual oficial: `INSTALACAO 4.0.12.15.md` (seções 2, 3, 4, 5, 6, 11, 16, 21 e 22)
- MySQL Yum Repository: https://dev.mysql.com/downloads/repo/yum/
- Arquivo de versões do Solr: https://archive.apache.org/dist/lucene/solr/8.2.0/
- PECL memcache: https://pecl.php.net/package/memcache

---

Autora: Alice Vivas Nava — [@alicevnava](https://github.com/alicevnava)
