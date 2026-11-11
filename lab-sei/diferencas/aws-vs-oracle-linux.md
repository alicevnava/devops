# SEI/SIP 4.0: Amazon Linux 2 (AWS) x Oracle Linux 8

Comparação entre os dois laboratórios de instalação do SEI/SIP 4.0.12.15 em uma única máquina:

- [README.md](../README.md): Amazon Linux 2 em uma instância EC2 (AWS)
- [README-oracle-linux.md](../README-oracle-linux.md): Oracle Linux 8.10 em uma VM (Oracle Cloud)

O objetivo deste arquivo é mostrar **o que mudou, por quê, e o que ficou igual**, para quem for adaptar o mesmo laboratório a outra distribuição.

## Sumário

- [Resumo em uma tabela](#resumo-em-uma-tabela)
- [Versões dos componentes](#versões-dos-componentes)
- [Diferenças por etapa](#diferenças-por-etapa)
- [O que existe só no Oracle Linux](#o-que-existe-só-no-oracle-linux)
- [O que existia só na AWS](#o-que-existia-só-na-aws)
- [O que ficou igual](#o-que-ficou-igual)
- [Limitações dos dois laboratórios](#limitações-dos-dois-laboratórios)
- [Lições para quem for adaptar](#lições-para-quem-for-adaptar)

---

## Resumo em uma tabela

| Aspecto | AWS (Amazon Linux 2) | Oracle Linux 8.10 |
| --- | --- | --- |
| Família | Derivada do RHEL 7 / CentOS 7 | Derivada do RHEL 8 |
| Gerenciador de pacotes | `yum` e `amazon-linux-extras` | `dnf` e módulos (`dnf module`) |
| Usuário de acesso | `ec2-user` | `opc` |
| SELinux | `Disabled` | `Enforcing` |
| Firewall do sistema | não usado (Security Group da AWS) | `firewalld` ativo, só `ssh` liberado |
| Acesso pelo navegador | DNS público da EC2 | túnel SSH do MobaXterm, endereço `localhost` |
| PHP 7.3 | `amazon-linux-extras install php7.3` | `dnf module enable php:7.3` |
| Banco | MySQL 5.7 (repositório externo EL7) | MySQL 8.0 (módulo do próprio sistema) |
| Recursos da máquina | 3,8 GB de RAM | 7,5 GiB de RAM, 2 CPUs |
| Solr (heap) | 1 GB | 2 GB |

## Versões dos componentes

| Componente | Manual | AWS | Oracle Linux |
| --- | --- | --- | --- |
| Apache | 2.4.6 | 2.4.x | 2.4.37 |
| PHP | 7.3.12 | 7.3.33 | 7.3.20 |
| Extensão memcache | 4.0.4 | 4.0.5.2 (PECL) | 4.0.5.2 (PECL) |
| Extensão igbinary | exigida | pacote `php-pecl-igbinary` | compilada (PECL) |
| Extensão sodium | exigida | pacote `php-sodium` | **não instalada** |
| Memcached | 1.4.25 | 1.4.15 | 1.5.22 |
| MySQL | 5.7 | 5.7.44 | 8.0.x |
| Java | 1.8 | 1.8.0 | 1.8.0_504 |
| Solr | 8.2.0 | 8.2.0 | 8.2.0 |

---

## Diferenças por etapa

### Etapa 1 - Preparação

| Item | AWS | Oracle Linux | Motivo |
| --- | --- | --- | --- |
| Atualizar | `sudo yum update -y` | `sudo dnf update -y` | Gerenciador de pacotes |
| Editor | pacote `vim` | pacote `vim-enhanced` | Nome do pacote no RHEL 8 |
| SELinux | `getenforce` → `Disabled`, nada a fazer | `Enforcing`: **6 `setsebool -P` obrigatórios** | Padrão do Oracle Linux |
| Espera do `dnf` | não ocorre | `Waiting for process with pid ...` quando há outro `dnf` | Atualização automática de cache |

### Etapa 2 - Pacote do SEI

Igual. A única atenção extra no Oracle Linux foi o uso do `sudo` e do `~`: comandos de extração na pasta pessoal **sem** `sudo`, e a cópia para `/opt` **com** `sudo`.

### Etapa 3 - Apache

| Item | AWS | Oracle Linux |
| --- | --- | --- |
| Instalação | `yum install -y httpd` | `dnf install -y httpd` |
| Página inicial | 403 ou 200 | 403 ("Apache 2 Test Page") |

### Etapa 4 - PHP 7.3 e extensões

| Item | AWS | Oracle Linux | Motivo |
| --- | --- | --- | --- |
| Instalar o PHP | `amazon-linux-extras install php7.3` | `dnf module enable php:7.3` e `dnf install php-cli php-fpm` | Mecanismos diferentes de versões |
| Extensões já presentes | muitas, vêm com o `php7.3` | poucas (PHP "básico") | Pacotes separados no RHEL 8 |
| mysqli | já presente | `php-mysqlnd` | Não vem por padrão |
| zip | já presente | `php-pecl-zip` | Nome do pacote |
| bcmath, xml, soap, intl, ldap | `php-bcmath php-xml php-soap php-intl php-ldap` | os mesmos, mais `php-json`, `php-mbstring`, `php-gd`, `php-pecl-zip` | Não vêm por padrão |
| igbinary | `yum install php-pecl-igbinary` | `pecl install igbinary` + `30-igbinary.ini` | Sem pacote no repositório |
| sodium | `yum install php-sodium` | não instalada (só a Federação a usa) | Sem pacote nem `libsodium` |
| memcache | `pecl install memcache-4.0.5.2` | igual | — |
| php-fpm | `systemctl enable/restart php-fpm` | igual, **mais** `restart httpd` | php-fpm instalado depois do Apache |
| Ajustes do PHP | `/etc/php.d/99-sei.ini` | igual | — |

### Etapa 5 - Memcached

| Item | AWS | Oracle Linux |
| --- | --- | --- |
| `OPTIONS` | se vier vazio, `sed` para `-l 127.0.0.1` | já vem `-l 127.0.0.1,::1`: **nada a alterar** |
| Versão | 1.4.15 | 1.5.22 |

### Etapa 6 - Banco de dados

| Item | AWS | Oracle Linux | Motivo |
| --- | --- | --- | --- |
| Origem do MySQL | repositório externo `mysql57-community` (EL7) | módulo `mysql:8.0` do `dnf` | O repositório EL7 não é adequado ao RHEL 8 |
| Chave GPG | `rpm --import ...RPM-GPG-KEY-mysql-2022` | não necessária | Pacote assinado pelo próprio sistema |
| Senha temporária | `grep 'temporary password' /var/log/mysqld.log` | **não existe** (o log é `/var/log/mysql/mysqld.log`) | MySQL do AppStream |
| `mysql_secure_installation` | pergunta "Change the password for root?" | pede direto a nova senha; pergunta do *validate password* | Root sem senha inicial |
| Charset | acrescentar no fim do `/etc/my.cnf` | arquivo próprio `/etc/my.cnf.d/99-sei.cnf` | `my.cnf` só inclui a pasta `my.cnf.d` |
| Plugin de autenticação | não se aplica (5.7) | já vem `mysql_native_password` | Problema nº 32 do manual já resolvido |
| Contagem de tabelas | 39 (SIP) e 267 (SEI) | 39 e 267 | Mesmas |
| Restaurar dumps e `UPDATE` | igual | igual (com `localhost` no endereço) | — |

### Etapa 7 - Permissões e publicação no Apache

| Item | AWS | Oracle Linux |
| --- | --- | --- |
| `chown`, `chmod`, `sei.conf`, cron de limpeza | iguais | iguais |
| Conferência dos arquivos | só visual (`ls -l`) | **contagem** com `find ... ! -perm 0640 \| wc -l` |

A contagem foi acrescentada porque, no Oracle Linux, um comando de permissões não aplicado deixou milhares de arquivos legíveis por qualquer usuário sem nenhum aviso.

### Etapas 8 e 9 - Configuração do SIP e do SEI

| Item | AWS | Oracle Linux |
| --- | --- | --- |
| `SEU_ENDERECO` | DNS público da EC2 | `localhost` |
| Edição | à mão no vim | comandos `:NNs/.../.../` do vim, com números de linha da 4.0.12.15 |
| Solr no `ConfiguracaoSEI.php` | `http://localhost:8983/solr` | `http://127.0.0.1:8983/solr` |
| Pasta de arquivos | `chown`, `chmod` | igual, **mais rótulos do SELinux** |
| Rótulos de gravação | não existem | `semanage fcontext` + `restorecon` em `/var/sei/arquivos`, `/opt/sei/temp` e `/opt/sip/temp` |

### Etapa 10 - Primeiro login

| Item | AWS | Oracle Linux |
| --- | --- | --- |
| Acesso | `http://DNS_DA_EC2/sip` | túnel SSH (MobaXterm): `http://localhost/sip` |
| Porta no firewall | Security Group (22, 80, 443) | nada a abrir: o túnel entra pela 22 |
| `getent hosts SEU_ENDERECO` | IP privado (10.x) | não se aplica; o nome da VM resolve só para um IPv6 local (`fe80::`) |

### Etapa 11 - Solr

| Item | AWS | Oracle Linux | Motivo |
| --- | --- | --- | --- |
| Java 8 | `yum install java-1.8.0-openjdk-headless` | `dnf install ...` | — |
| Heap | `-Xms512m -Xmx1g` (3,8 GB de RAM) | `-Xms512m -Xmx2g` (7,5 GiB de RAM) | ~1/4 da RAM |
| Teste do filtro de IPs | `127.0.0.1`: 200; IP privado: 403; `localhost`: 200 | `127.0.0.1`: 200; IP privado: 403; `localhost` por IPv6: **500** | `localhost` resolve para `::1` |
| Endereço no SEI | `localhost` | `127.0.0.1` | Evita o IPv6 |
| Restante (download, `dos2unix`, script, indexação) | igual | igual | — |

### Etapa 12 - Agendamentos

| Item | AWS | Oracle Linux |
| --- | --- | --- |
| Parâmetro `SIP_EMAIL_ADMINISTRADOR` | precisa criar | precisa criar |
| Cron | `/etc/cron.d/sei-agendamentos` | igual |
| Conferir o cron | não detalhado | `grep AgendamentoTarefa /var/log/cron` |
| `testarAgendamento` | grava registro no log | grava o registro, mas o log do SIP mostra "Erro enviando correspondência eletrônica" (VM sem servidor de e-mail) |

### Etapa 13 - HTTPS

| Item | AWS | Oracle Linux |
| --- | --- | --- |
| `mod_ssl` | `yum install -y mod_ssl` | `dnf install -y mod_ssl` |
| Teste da porta 443 | `Test-NetConnection` (PowerShell) | não se aplica (sem IP público); teste pelo `curl -kI https://localhost/sip/` |
| `https` nos sistemas | `false` (rede bloqueia certificado autoassinado) | `false` (certificado autoassinado) |

### Etapa 14 - Finalização

Igual, com itens a mais no checklist do Oracle Linux: contagem de arquivos fora de `0640`, rótulos do SELinux, booleans do SELinux e execução do cron. Também há portas extras no `ss` (33060 do MySQL 8, entre outras).

---

## O que existe só no Oracle Linux

| Item | Para que serve |
| --- | --- |
| 6 booleans do SELinux (`setsebool -P`) | Permitem que o Apache/PHP abra conexões, use o Memcached, o banco, LDAP e NFS |
| Rótulo `httpd_sys_rw_content_t` | Permite ao Apache gravar nas `temp` e em `/var/sei/arquivos` |
| `policycoreutils-python-utils` | Traz o `semanage` |
| `dnf module enable` (PHP e MySQL) | Escolhe a versão antes de instalar |
| Túnel SSH do MobaXterm | Acesso pelo navegador sem DNS nem portas liberadas no firewall |
| `127.0.0.1` no endereço do Solr | Evita a resolução de `localhost` por IPv6 |
| Arquivo `99-sei.cnf` | Configuração do MySQL em `/etc/my.cnf.d/` |
| `30-igbinary.ini` | Ativa a extensão compilada |

## O que existia só na AWS

| Item | Motivo de não existir no Oracle Linux |
| --- | --- |
| `amazon-linux-extras` | Ferramenta exclusiva do Amazon Linux |
| Repositório externo do MySQL 5.7 e chave GPG | O MySQL vem do repositório do sistema |
| Senha temporária do MySQL | O MySQL do AppStream começa sem senha |
| `sed` no `/etc/sysconfig/memcached` | A opção `-l` já vem configurada |
| Pacotes `php-pecl-igbinary` e `php-sodium` | Não existem no repositório |
| Security Group (portas 22, 80, 443) | Conceito da AWS; aqui o controle é o `firewalld` e o túnel |
| DNS público e `Test-NetConnection` | Não há DNS para a VM nem IP público utilizável |

## O que ficou igual

- A **estrutura de pastas** (`/opt/sei`, `/opt/sip`, `/opt/infra`, `/var/sei/arquivos`, `/opt/solr`, `/dados`)
- **Permissões** `2750` / `0640` / `2570`, o grupo `apache` e a limpeza noturna da `temp`
- O **`sei.conf`** do Apache e o `99-sei.ini` do PHP
- A restauração das **bases** (39 e 267 tabelas), os `UPDATE` de órgão e URLs, e o usuário `sei_user` sem permissão de DDL
- A **configuração** do SIP e do SEI (mesmas chaves, mesma lógica de login por `/sip`)
- O **Solr 8.2.0**: download, hash, script, filtro de IPs no `jetty.xml` e indexação
- Os **agendamentos** pelo cron, a mesma correção do parâmetro `SIP_EMAIL_ADMINISTRADOR` e o `mod_ssl` com certificado autoassinado
- O **resultado funcional**: login, anexar PDF, memorando, assinatura e pesquisa por conteúdo

## Limitações dos dois laboratórios

| Limitação | Efeito |
| --- | --- |
| Sem `wkhtmltopdf` | Não gera o PDF do processo |
| Sem `uploadprogress` | Sem barra de progresso no upload |
| Sem JODConverter | Documentos do OpenOffice não entram no PDF do processo |
| `https => false` | Sem HTTPS nos sistemas (só o Apache responde na 443) |
| Chaves de acesso padrão | Aviso de segurança com `Producao => true` |
| Sem servidor de e-mail | Nenhuma notificação por e-mail |
| Sem `sodium` (só no Oracle Linux) | SEI Federação indisponível |

---

## Lições para quem for adaptar

1. **Comece pelo SELinux.** Ele passa despercebido quando está desativado. Com `Enforcing`, os sintomas (erro ao gravar, ao conectar, página em branco) não apontam para a causa: consulte `getenforce` e `ausearch -m avc` antes de procurar em outro lugar.
2. **Confira cada comando de permissão.** Depois de `chmod` em massa, conte com `find ... ! -perm 0640 | wc -l` em vez de olhar só alguns arquivos. Um caminho incompleto (`/opt/sei` em vez de `/opt/sei/temp`) muda a permissão de todo o sistema.
3. **Descubra os nomes dos pacotes no repositório** (`dnf list available "php-*"`) antes de copiar a lista da outra distribuição.
4. **Fixe a versão pelo módulo** (`dnf module enable`) antes de instalar, para o `dnf` não escolher a versão padrão.
5. **Evite `localhost` quando houver filtro de IP.** O nome pode resolver para IPv6, e a restrição do Solr só cobre o `127.0.0.1`.
6. **Confira com `grep` depois de cada edição.** Um comando de substituição do vim que não foi aplicado deixa o arquivo como estava e o erro só aparece mais tarde.
7. **Registre o que o ambiente impõe** (sem DNS, firewall fechado, túnel): o endereço do sistema define as URLs gravadas no banco e nos arquivos de configuração.
8. **Leia o log pelo que ele escreve.** O log do cron registra o comando executado, não o nome do arquivo de agendamento.
