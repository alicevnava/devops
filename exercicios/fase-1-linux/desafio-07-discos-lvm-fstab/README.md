# Desafio 7 — Discos, LVM e fstab: o Espaço que Acabou

Sétimo desafio da Fase 1 (Linux sólido) da trilha de estudos: adicionar um disco ao servidor, organizar o espaço com LVM, montar um volume de forma permanente, aumentá-lo sem desligar nada e criar uma swap adicional.

**Método:** testar cada mudança antes de reiniciar. Um erro no `/etc/fstab` pode impedir o servidor de iniciar.

---

## Ambiente

| Item | Valor |
|---|---|
| **Sistema** | Rocky Linux 10.2 (Minimal Install), compatível com o RHEL 10 |
| **Virtualização** | Hyper-V, VM de Geração 2, 2 GB de RAM, 2 vCPUs |
| **Discos** | `sda` de 20 GB (sistema) e `sdb` de 5 GB (adicionado neste desafio) |
| **Acesso** | SSH pelo MobaXterm, com um usuário administrador criado na instalação |

---

## Conceitos

O **LVM** cria uma camada flexível entre o disco e os sistemas de arquivos. Em vez de partições de tamanho fixo, o espaço é reunido num "reservatório", de onde saem volumes que podem crescer depois, sem desligar o servidor.

```
Disco (sdb)
 └── Partição (sdb1)
      └── PV: volume físico ─ a partição preparada para o LVM
           └── VG: grupo de volumes ─ o "reservatório" de espaço
                └── LV: volume lógico ─ o pedaço que se usa
                     └── Sistema de arquivos (XFS) ─ montado numa pasta
```

| Termo | Significa |
|---|---|
| **PV** (*physical volume*) | um disco ou partição preparado para o LVM |
| **VG** (*volume group*) | um grupo de PVs; o espaço total disponível. Pode receber novos discos depois |
| **LV** (*logical volume*) | um volume tirado do VG, onde fica o sistema de arquivos ou a swap |
| **`/etc/fstab`** | o arquivo que diz o que montar automaticamente no boot |
| **UUID** | identificador único de um sistema de arquivos. Ao contrário de nomes como `sdb`, não muda se outros discos forem adicionados |
| **Swap** | espaço em disco usado como extensão da memória quando a RAM fica cheia |

---

## Enunciado

O projeto "site" cresceu e vai precisar de um espaço próprio para dados, separado do sistema e com folga para aumentar no futuro. O servidor também está com pouca memória e precisa de mais swap.

### Objetivos

1. No disco novo, criar uma partição de **3 GB** do tipo LVM. O resto do disco fica livre para o futuro.
2. Com essa partição, criar o grupo de volumes **`vgdados`**.
3. Criar o volume lógico **`lvsite`** com **1 GB**, formatar com **XFS** e montar em **`/dados/site`**.
4. Fazer a montagem ser **permanente**, usando o **UUID** do volume no `/etc/fstab`.
5. Aumentar o `lvsite` para **1,5 GB** com ele montado, e fazer o sistema de arquivos acompanhar o novo tamanho.
6. Criar um volume lógico **`lvswap`** de **512 MB** no mesmo `vgdados` e usá-lo como **swap** adicional, também de forma permanente.

### Resultado esperado

- `lsblk` mostra a árvore `sdb` → `sdb1` → `vgdados-lvsite` e `vgdados-lvswap`.
- `df -h /dados/site` mostra perto de 1,5 GB.
- `swapon --show` mostra as duas swaps.
- Depois de `sudo reboot`, tudo continua montado e ativo.

---

## Preparação: adicionar um disco à VM

No Hyper-V, com a VM ligada: **Configurações → Controlador SCSI → Disco Rígido → Adicionar → Novo**, com **VHDX**, **Expansão dinâmica**, nome `dados.vhdx` e **5 GB**.

```
$ lsblk
NAME         MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sda            8:0    0   20G  0 disk
├─sda1         8:1    0  600M  0 part /boot/efi
├─sda2         8:2    0    2G  0 part /boot
└─sda3         8:3    0 17,4G  0 part
  ├─rlm-root 253:0    0 15,4G  0 lvm  /
  └─rlm-swap 253:1    0    2G  0 lvm  [SWAP]
sdb            8:16   0    5G  0 disk
```

O disco novo é o `sdb`, com 5 GB e sem partições. O sistema da VM já usa LVM: grupo `rlm`, com os volumes `root` e `swap`.

---

## Passo a passo

### 1. Criar a partição

> ⚠️ Conferir duas vezes o nome do disco. Gravar uma tabela de partições no `sda` por engano apaga o sistema.

```bash
sudo fdisk /dev/sdb
```

O `fdisk` é interativo. Nada é gravado até o comando `w`; para sair sem salvar, `q`.

| Comando | O que faz | Respostas |
|---|---|---|
| `g` | cria uma tabela de partições **GPT** vazia | — |
| `n` | cria uma partição nova | número: **Enter** (1); primeiro setor: **Enter**; último setor: **`+3G`** |
| `t` | muda o tipo da partição | `lvm` (ou `L` para ver a lista e escolher **Linux LVM**) |
| `p` | mostra como vai ficar, para conferir | — |
| `w` | grava no disco e sai | — |

```
$ lsblk
...
sdb            8:16   0    5G  0 disk
└─sdb1         8:17   0    3G  0 part
```

### 2. Criar o PV e o VG

```bash
sudo pvcreate /dev/sdb1
sudo vgcreate vgdados /dev/sdb1
```

- `pvcreate` prepara a partição como volume físico.
- `vgcreate vgdados /dev/sdb1` cria o grupo `vgdados` com esse volume físico.

Para conferir: `sudo pvs` e `sudo vgs`, que listam os volumes físicos e os grupos de forma resumida.

### 3. Criar o LV, formatar e montar

```bash
sudo lvcreate -L 1G -n lvsite vgdados
```

- `-L 1G` define o tamanho; `-n lvsite` define o nome; `vgdados` é o grupo de onde sai o espaço.

```bash
sudo mkfs.xfs /dev/vgdados/lvsite
```

- Cria um sistema de arquivos XFS, o padrão do Rocky e do Red Hat. O caminho do volume é `/dev/` + grupo + volume.

```bash
sudo mkdir -p /dados/site
sudo mount /dev/vgdados/lvsite /dados/site
```

- `mkdir -p` cria também a pasta `/dados`, que ainda não existia.
- Essa montagem é temporária: some no próximo reboot.

```
$ lsblk
...
sdb                  8:16   0    5G  0 disk
└─sdb1               8:17   0    3G  0 part
  └─vgdados-lvsite 253:2    0    1G  0 lvm  /dados/site
```

### 4. Tornar a montagem permanente

```bash
sudo blkid /dev/vgdados/lvsite
```

- Mostra o UUID e o tipo do sistema de arquivos.

Cada linha do `/etc/fstab` tem seis campos:

| Campo | Significa | Neste caso |
|---|---|---|
| 1º | o que montar | `UUID=` + o UUID, sem aspas |
| 2º | onde montar | `/dados/site` |
| 3º | tipo do sistema de arquivos | `xfs` |
| 4º | opções de montagem | `defaults` |
| 5º | backup pelo antigo `dump` | `0` |
| 6º | ordem de verificação no boot | `0` (o XFS não usa) |

```bash
sudo vi /etc/fstab
```

Para não digitar o UUID à mão, no vi:

1. `G` vai para a última linha.
2. `:r !blkid -s UUID -o value /dev/vgdados/lvsite` insere, numa linha nova, só o valor do UUID.
3. `I` escreve no início da linha (`UUID=`); `A` escreve no final (o resto da linha).

Linha acrescentada:

```
UUID=89e4896e-f7ba-4774-b8c9-140f545b492e /dados/site xfs defaults 0 0
```

**Testar antes de qualquer reboot:**

```bash
sudo umount /dados/site
sudo systemctl daemon-reload
sudo mount -a
sudo findmnt --verify
df -h /dados/site
```

- `umount` desmonta, para provar que é a linha do `fstab` que monta o volume.
- `daemon-reload` faz o systemd ler o `fstab` de novo.
- `mount -a` monta tudo o que está no `fstab`. Se uma linha estiver errada, o erro aparece agora, e não no boot.
- `findmnt --verify` confere a sintaxe de todas as linhas.

### 5. Aumentar o volume com ele montado

```bash
sudo lvextend -r -L 1.5G /dev/vgdados/lvsite
```

- `lvextend` aumenta um volume lógico.
- `-r` aumenta também o sistema de arquivos. Sem ele, o volume cresceria, mas o XFS continuaria com 1 GB.
- `-L 1.5G` define o tamanho **final**. Com `+`, o valor seria **somado** ao tamanho atual (`-L +500M` daria o mesmo resultado).

### 6. Criar a swap adicional

```bash
sudo lvcreate -L 512M -n lvswap vgdados
sudo mkswap /dev/vgdados/lvswap
```

- `mkswap` prepara o volume para ser usado como swap e mostra o UUID dela.

Linha acrescentada ao `/etc/fstab` (com o mesmo truque do vi):

```
UUID=90f05007-ed0e-4c18-8391-309436397485 none swap defaults 0 0
```

- `none`: a swap não é montada em nenhuma pasta. `swap`: o tipo.

```bash
sudo systemctl daemon-reload
sudo swapon -a
sudo findmnt --verify
swapon --show
```

- `swapon -a` ativa todas as swaps do `fstab` que ainda não estão ativas.

---

## Testes (depois de `sudo reboot`)

```
$ lsblk
NAME               MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sda                  8:0    0   20G  0 disk
├─sda1               8:1    0  600M  0 part /boot/efi
├─sda2               8:2    0    2G  0 part /boot
└─sda3               8:3    0 17,4G  0 part
  ├─rlm-root       253:0    0 15,4G  0 lvm  /
  └─rlm-swap       253:1    0    2G  0 lvm  [SWAP]
sdb                  8:16   0    5G  0 disk
└─sdb1               8:17   0    3G  0 part
  ├─vgdados-lvsite 253:2    0  1,5G  0 lvm  /dados/site
  └─vgdados-lvswap 253:3    0  512M  0 lvm  [SWAP]

$ df -h /dados/site
Sist. Arq.                  Tam. Usado Disp. Uso% Montado em
/dev/mapper/vgdados-lvsite  1,5G   61M  1,4G   5% /dados/site

$ swapon --show
NAME      TYPE      SIZE USED PRIO
/dev/dm-1 partition   2G   0B   -2
/dev/dm-3 partition 512M   0B   -3
```

- O volume voltou montado e as duas swaps voltaram ativas, sem nenhum comando depois do boot.
- `/dev/dm-1` e `/dev/dm-3` são os nomes internos dos volumes LVM; o número bate com a coluna `MAJ:MIN` do `lsblk` (`253:1` e `253:3`).
- `PRIO`: a swap com prioridade maior (`-2`) é usada primeiro.
- Os `61M` usados num volume vazio são o espaço que o XFS reserva para os registros internos dele.
- Ainda há espaço livre: cerca de 1 GB no `vgdados` (`sudo vgs`) e 2 GB sem partição no `sdb`.

---

## Erros que aconteceram e como foram resolvidos

| Sintoma | Causa | Correção |
|---|---|---|
| `lvcreate -L 1GB lvsite vgdados` | Faltou o `-n` antes do nome; sem ele, `lvsite` seria lido como nome do grupo | `sudo lvcreate -L 1G -n lvsite vgdados` |
| `No command with matching syntax recognised` | O `lvcreate` recebeu só o grupo, sem tamanho e nome | `sudo lvcreate -L 512M -n lvswap vgdados` |
| Linha do `fstab` com o UUID colado no ponto de montagem | Faltou o espaço entre os campos | Separar os seis campos com espaços |
| `lvextend -L +1.5G /dev/lgsite/vgsite` | O `+` somaria 1,5 GB (total de 2,5 GB); o caminho estava invertido; faltava o `-r` | `sudo lvextend -r -L 1.5G /dev/vgdados/lvsite` |
| Linha da swap com `nome` no 2º campo | Erro de digitação | `none` |

---

## Resumo

- LVM em camadas: disco → partição → PV (`pvcreate`) → VG (`vgcreate`) → LV (`lvcreate`) → sistema de arquivos (`mkfs.xfs`) ou swap (`mkswap`).
- `pvs`, `vgs` e `lvs` mostram cada camada; `lsblk` mostra a árvore inteira.
- No `fstab`, usar o UUID (`blkid`), que não muda quando outros discos são adicionados.
- Antes de reiniciar, sempre testar: `daemon-reload`, `mount -a` (ou `swapon -a`) e `findmnt --verify`.
- `lvextend -r` aumenta o volume e o sistema de arquivos juntos, com o volume montado.
