# Desafio 6 — Pacotes com dnf: o Servidor sem Internet

Sexto desafio da Fase 1 (Linux sólido) da trilha de estudos: investigar pacotes instalados, instalar e remover com segurança, desfazer transações pelo histórico e configurar um repositório local a partir da ISO do Rocky.

**Método:** observar antes de mudar, mudar uma coisa por vez e conferir depois de cada passo.

---

## Ambiente

| Item | Valor |
|---|---|
| **Sistema** | Rocky Linux 10.2 (Minimal Install), compatível com o RHEL 10 |
| **Virtualização** | Hyper-V, VM de Geração 2, 2 GB de RAM, 2 vCPUs, disco de 20 GB |
| **Acesso** | SSH pelo MobaXterm, com um usuário administrador criado na instalação |
| **ISO** | Rocky Linux 10.2 Minimal, conectada à VM como unidade de DVD |

---

## Conceitos

| Termo | Significa |
|---|---|
| **Pacote** | um arquivo `.rpm` com um programa, seus arquivos e a lista de dependências |
| **Repositório** | um local com muitos pacotes e um índice deles (a pasta `repodata`) |
| **`dnf`** | baixa pacotes dos repositórios, resolve as dependências e instala |
| **`rpm`** | a ferramenta mais básica: consulta os pacotes **já instalados** |
| **Arquivo `.repo`** | a configuração de um repositório, na pasta `/etc/yum.repos.d/` |

---

## Enunciado

O servidor vai ser movido para uma rede isolada, sem internet. Antes da mudança, é preciso entender o que está instalado, praticar a instalação e a remoção de pacotes com segurança e preparar um **repositório local**, a partir da ISO do Rocky, para continuar instalando pacotes sem internet.

### Objetivos

**Parte 1 — Investigar**

1. Descobrir a qual pacote pertence o arquivo `/etc/httpd/conf/httpd.conf`.
2. Listar só os **arquivos de configuração** desse pacote.
3. Ver a versão instalada do Apache e de qual repositório ele veio.

**Parte 2 — Instalar, remover e desfazer**

4. Instalar o pacote `tree` e usá-lo para ver a estrutura da pasta `/etc/httpd`.
5. Remover o `tree`.
6. Usar o histórico do `dnf` para **desfazer** a remoção, sem digitar de novo o comando de instalação.

**Parte 3 — Repositório local**

7. Conectar a ISO do Rocky à VM e montá-la em `/mnt`.
8. Criar um arquivo `.repo` que use a ISO como repositório.
9. Instalar um pacote **usando só o repositório local**, e provar que ele veio de lá.

---

## Parte 1 — Investigar

### Versão e origem do Apache

```
$ dnf info httpd
Pacotes instalados
Nome         : httpd
Versão       : 2.4.63
Lançamento   : 13.el10_2.6
Arquitetura  : x86_64
Tamanho      : 56 k
Repositório  : @System
A partir do  : appstream
Resumo       : Apache HTTP Server
```

| Campo | Significa |
|---|---|
| `Versão: 2.4.63` | a versão do Apache |
| `Lançamento: 13.el10_2.6` | a revisão do pacote feita pela distribuição; `el10` indica Enterprise Linux 10 |
| `Repositório: @System` | o pacote **já está instalado** |
| `A partir do: appstream` | o repositório de onde ele foi baixado |

### A qual pacote pertence um arquivo

O `dnf info` precisa do nome do pacote. Para o caminho contrário, partindo de um arquivo, usa-se o `rpm`:

```
$ rpm -qf /etc/httpd/conf/httpd.conf
httpd-core-2.4.63-13.el10_2.6.x86_64
```

- `-q` (de *query*) consulta os pacotes instalados; `f` (de *file*) pergunta sobre um arquivo.

O `httpd.conf` é do pacote **`httpd-core`**, e não do `httpd`. A pista estava no `dnf info`: o pacote `httpd` tem só 56 k, pouco demais para um servidor web.

### Arquivos de configuração e lista completa

```
$ rpm -qc httpd-core
/etc/httpd/conf.d/autoindex.conf
/etc/httpd/conf.d/userdir.conf
/etc/httpd/conf.d/welcome.conf
/etc/httpd/conf.modules.d/00-base.conf
...
/etc/httpd/conf/httpd.conf
/etc/httpd/conf/magic
/etc/logrotate.d/httpd
/etc/sysconfig/htcacheclean
```

- `c` (de *config*) lista só os arquivos de configuração. Não é preciso digitar a versão: o nome curto basta.

```
$ rpm -ql httpd
/etc/httpd/conf.modules.d/00-brotli.conf
/etc/httpd/conf.modules.d/00-systemd.conf
/usr/lib/systemd/system/httpd.service
/usr/lib/systemd/system/httpd.socket
/usr/lib64/httpd/modules/mod_systemd.so
/usr/share/man/man8/httpd.8.gz
...
```

- `l` (de *list*) lista todos os arquivos do pacote.

| Pacote | O que tem |
|---|---|
| `httpd-core` | o servidor em si e os arquivos de configuração |
| `httpd` | a ligação com o systemd (`httpd.service`, `mod_systemd`) e os manuais |

Ao instalar o `httpd`, o `dnf` instalou o `httpd-core` junto, porque o primeiro **depende** do segundo.

---

## Parte 2 — Instalar, remover e desfazer

### Instalar e usar o `tree`

```bash
sudo dnf install tree
```

```
$ tree /etc/httpd
/etc/httpd
├── conf
│   ├── httpd.conf
│   └── magic
├── conf.d
│   ├── autoindex.conf
│   ├── README
│   ├── userdir.conf
│   └── welcome.conf
├── conf.modules.d
│   ├── 00-base.conf
│   ...
├── logs -> ../../var/log/httpd
├── modules -> ../../usr/lib64/httpd/modules
├── run -> /run/httpd
└── state -> ../../var/lib/httpd

8 directories, 18 files
```

- `tree` mostra a estrutura de pastas em forma de árvore. As setas (`->`) indicam links para outros lugares.

### Remover

```bash
sudo dnf remove tree
```

### Desfazer pelo histórico

```
$ dnf history
ID     | Linha de comando | Data e hora      | Ação(ões) | Alterado
     6 | remove tree      | 22-10-2026 16:25 | Removed   |    1
     5 | install tree     | 22-10-2026 16:23 | Install   |    1
     4 | install httpd    | 22-10-2026 11:05 | Install   |   12
     3 | update           | 22-10-2026 11:02 | I, U      |  112
     2 | install acl      | 21-10-2026 16:08 | I, U      |    2
```

- Cada transação tem um **ID**. A transação 4 alterou 12 pacotes: o `httpd` e as dependências instaladas junto.

```bash
dnf history info <ID_DA_REMOCAO>
sudo dnf history undo <ID_DA_REMOCAO>
```

- `history info` mostra o que uma transação fez; vale conferir antes de desfazer.
- `history undo <ID_DA_REMOCAO>` faz o **contrário** da transação indicada (no exemplo, a `6`). Como ela removeu o `tree`, o contrário é instalar de novo.
- Troque `<ID_DA_REMOCAO>` pelo ID da linha `remove tree` no **seu** `dnf history`: os números dependem do histórico de cada máquina.

**Resultado esperado** (a saída deste passo não foi registrada): o `dnf` mostra `Instalando: tree` e termina com `Concluído!`. Depois, o `tree /etc/httpd` volta a funcionar, e o `dnf history` mostra uma transação nova no topo.

---

## Parte 3 — Repositório local

### 1. Conectar e montar a ISO

No Hyper-V: **Configurações da VM → Controlador SCSI → Unidade de DVD**, escolhendo o arquivo da ISO.

```
$ lsblk
NAME         MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sda            8:0    0   20G  0 disk
...
sr0           11:0    1 1024M  0 rom
sr1           11:1    1  1,9G  0 rom
```

- `sr0` com `1024M` é uma unidade de DVD **vazia**; `sr1` com `1,9G` é a ISO. Troque `<UNIDADE_DA_ISO>` pela unidade que, no **seu** `lsblk`, tem o tamanho da ISO (no exemplo, `sr1`).

```bash
sudo mount /dev/<UNIDADE_DA_ISO> /mnt
```

- `mount` liga o conteúdo de um disco a uma pasta. O aviso `mounted read-only` é normal: uma ISO é só leitura.

### 2. Encontrar o repositório dentro da ISO

```
$ find /mnt -maxdepth 2 -name repodata
/mnt/Minimal/repodata
```

- `find` procura arquivos e pastas; `-maxdepth 2` limita a busca a dois níveis; `-name repodata` procura pelo nome.
- A pasta acima da `repodata` é o repositório. A ISO **Minimal** tem um só, `/mnt/Minimal`; a ISO completa tem dois, `BaseOS` e `AppStream`.

### 3. Encontrar a chave GPG

```
$ ls /etc/pki/rpm-gpg/
RPM-GPG-KEY-Rocky-10  RPM-GPG-KEY-Rocky-10-Testing
```

- Os pacotes são assinados, e o `dnf` confere a assinatura com essas chaves. A `-Testing` é para pacotes em fase de teste; para a ISO, usa-se a `RPM-GPG-KEY-Rocky-10`.

### 4. Criar o arquivo `.repo`

```bash
sudo vi /etc/yum.repos.d/local.repo
```

```ini
[local-minimal]
name=Rocky 10 Minimal (ISO local)
baseurl=file:///mnt/Minimal
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-Rocky-10
```

| Linha | Significa |
|---|---|
| `[local-minimal]` | o identificador do repositório, usado nos comandos |
| `name` | o nome que aparece nas listas |
| `baseurl` | a pasta do repositório (a que tem a `repodata`) |
| `enabled=1` | repositório ligado |
| `gpgcheck=1` | conferir a assinatura dos pacotes |
| `gpgkey` | o caminho **completo** do arquivo da chave |

> ℹ️ `file://` é o protocolo, e o caminho que vem depois já começa com `/`. Por isso o endereço fica com **três barras**.

```
$ dnf repolist
id do repo        nome do repo
appstream         Rocky Linux 10 - AppStream
baseos            Rocky Linux 10 - BaseOS
extras            Rocky Linux 10 - Extras
local-minimal     Rocky 10 Minimal (ISO local)
```

### 5. Instalar só pelo repositório local

Para ver os pacotes do repositório que ainda não estão instalados:

```bash
dnf --repo local-minimal list --available
```

```bash
sudo dnf --repo local-minimal install cockpit
```

- `--repo local-minimal` faz o `dnf` usar **só** esse repositório.

```
$ dnf info cockpit
Pacotes instalados
Nome         : cockpit
Versão       : 356
Repositório  : @System
A partir do  : local-minimal
```

O pacote veio do repositório local. ✅

---

## O efeito colateral: pacotes rebaixados

O histórico da instalação mostrou um problema:

```
$ dnf history info last
Linha de comando  : --repo local-minimal install cockpit.x86_64
Pacotes alterados:
    Desatualizar   curl-8.12.1-4.el10.x86_64                 @local-minimal
    Desatualizados curl-8.12.1-4.el10_2.7.x86_64             @@System
    Desatualizar   libcurl-8.12.1-4.el10.x86_64              @local-minimal
    Desatualizados libcurl-8.12.1-4.el10_2.7.x86_64          @@System
    Desatualizar   openssl-libs-1:3.5.5-2.el10_2.x86_64      @local-minimal
    Desatualizados openssl-libs-1:3.5.8-2.el10_2.x86_64      @@System
    Instalar       cockpit-356-1.el10.rocky.0.1.x86_64       @local-minimal
    ...
```

O `dnf` **voltou** o `curl`, o `libcurl` e o `openssl-libs` para versões mais antigas, porque:

1. A ISO é uma "foto" dos pacotes do dia em que foi gerada. Ela não recebe atualizações.
2. O `cockpit` da ISO precisava das bibliotecas da mesma época.
3. Com o `--repo local-minimal`, o `dnf` só podia usar o que estava na ISO, então rebaixou o que já estava instalado.

O `openssl` é a biblioteca de criptografia do sistema: rebaixá-la pode trazer de volta falhas de segurança já corrigidas.

> ⚠️ **Lição:** num servidor sem internet, a ISO serve para instalar, mas não para manter o servidor atualizado. Redes isoladas costumam usar um espelho interno dos repositórios, atualizado periodicamente. E vale sempre ler a lista do `dnf` antes de responder `s`.

### Correção: desfazer a transação

```bash
dnf history info <ID_DA_INSTALACAO>
sudo dnf history undo <ID_DA_INSTALACAO>
```

- Troque `<ID_DA_INSTALACAO>` pelo ID da instalação feita com `--repo local-minimal` no seu `dnf history` (no exemplo, `8`).

```
Atualizando:
 curl              8.12.1-4.el10_2.7     baseos
 libcurl           8.12.1-4.el10_2.7     baseos
 openssl-libs      1:3.5.8-2.el10_2      baseos
Removendo:
 cockpit           356-1.el10.rocky.0.1  @local-minimal
Removendo pacotes dependentes:
 cockpit-bridge, cockpit-system, cockpit-ws, cockpit-ws-selinux, openssl, python3-..., sos
...
Removed '/etc/systemd/system/sockets.target.wants/cockpit.socket'.
```

O `undo` devolveu as versões novas, vindas da internet, e removeu o `cockpit` e as 14 dependências. Também desativou o `cockpit.socket`, que o pacote tinha ativado no boot ao ser instalado.

### Desligar o repositório local e desmontar a ISO

Com o repositório ligado e a ISO desmontada, o `dnf` daria erro em todo comando. Por isso, primeiro desligar o repositório (trocar `enabled=1` por `enabled=0` no `local.repo`) e depois:

```bash
sudo umount /mnt
```

- `umount` desliga o disco da pasta, o contrário do `mount`.

---

## Testes finais

```
$ rpm -q curl openssl-libs
curl-8.12.1-4.el10_2.7.x86_64
openssl-libs-3.5.8-2.el10_2.x86_64

$ dnf repolist
id do repo        nome do repo
appstream         Rocky Linux 10 - AppStream
baseos            Rocky Linux 10 - BaseOS
extras            Rocky Linux 10 - Extras
```

As bibliotecas estão nas versões atualizadas e o repositório local está desligado.

---

## Erros que aconteceram e como foram resolvidos

| Sintoma | Causa | Correção |
|---|---|---|
| `ls /mnt/BaseOS` não achou a pasta | A ISO **Minimal** tem um repositório só, com outro nome | Procurar a `repodata` com `find /mnt -maxdepth 2 -name repodata` |
| O `.repo` ficou com o nome da chave no `baseurl` e as duas chaves no `gpgkey` | Confusão entre o que vai em cada linha | `baseurl` = pasta do repositório; `gpgkey` = caminho completo de **uma** chave |
| A instalação pelo repositório local rebaixou o `curl` e o `openssl-libs` | A ISO tem versões antigas, e o `--repo` impediu o uso dos repositórios atualizados | `sudo dnf history undo <ID_DA_INSTALACAO>` (no exemplo, `8`) |

---

## Resumo

- `dnf info` mostra versão e origem de um pacote; `rpm -qf` descobre o pacote de um arquivo; `rpm -qc` e `rpm -ql` listam os arquivos.
- Um programa pode estar dividido em vários pacotes, ligados por dependências.
- `dnf history` guarda todas as transações; `history info` mostra os detalhes e `history undo` desfaz.
- Um repositório é uma pasta com `repodata`, configurado num arquivo `.repo` em `/etc/yum.repos.d/`.
- `--repo` restringe o `dnf` a um repositório, mas pode forçar versões antigas. Ler a lista antes de confirmar.
