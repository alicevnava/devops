# Desafio 5 — systemd e journalctl: o Serviço que Não Sobe

Quinto desafio da Fase 1 (Linux sólido) da trilha de estudos: criar um serviço próprio no systemd, descobrir pelo journal por que ele não sobe, deixá-lo ativo no boot, fazê-lo voltar sozinho quando cair e guardar o journal entre reinicializações.

**Método:** quando algo falhar, primeiro `systemctl status`, depois `journalctl`, e só então mudar alguma coisa.

---

## Ambiente

| Item | Valor |
|---|---|
| **Sistema** | Rocky Linux 10.2 (Minimal Install), compatível com o RHEL 10 |
| **Virtualização** | Hyper-V, VM de Geração 2, 2 GB de RAM, 2 vCPUs, disco de 20 GB |
| **Acesso** | SSH pelo MobaXterm, com um usuário administrador criado na instalação |

---

## Conceitos

| Termo | Significa |
|---|---|
| **Serviço** | um processo que o systemd inicia, vigia e, se configurado, reinicia quando cai |
| **Unidade** (*unit*) | o arquivo que descreve o serviço, com extensão `.service` |
| **Journal** | onde o systemd guarda os registros do sistema e dos serviços; lido com o `journalctl` |
| **Target** | um "modo de operação" do sistema. O `multi-user.target` é o modo normal de um servidor, sem interface gráfica |

Arquivos de unidade:

| Local | Quem coloca |
|---|---|
| `/usr/lib/systemd/system/` | os pacotes instalados (por exemplo, o `httpd.service`) |
| `/etc/systemd/system/` | o administrador do servidor |

---

## Enunciado

A equipe precisa de um programa que registre a data e a hora a cada 10 segundos num arquivo de log, para verificar se o servidor ficou fora do ar em algum momento. O programa precisa iniciar sozinho com o servidor e voltar automaticamente se cair.

### Objetivos

1. Criar o serviço **`relogio.service`**, que executa o `relogio.sh`.
2. Iniciar o serviço e fazê-lo funcionar. Se ele não subir, descobrir o motivo **pelo journal** antes de mudar qualquer coisa.
3. Deixar o serviço ativo no boot.
4. Se o processo do serviço for morto com `kill -9`, o systemd deve reiniciá-lo sozinho.
5. Mostrar, com o `journalctl`, só os registros desse serviço desde hoje.

### Resultado esperado

- `systemctl status relogio` mostra `active (running)` e `enabled`.
- `tail /var/log/relogio.log` mostra uma linha nova a cada 10 segundos.
- Depois de um `sudo kill -9` no processo principal, o `status` mostra `active (running)` com um **Main PID diferente**.
- Depois de reiniciar a VM, o serviço já está rodando sem ser iniciado manualmente.

---

## Passo a passo

### 1. Criar o programa

```bash
sudo vi /usr/local/bin/relogio.sh
```

```bash
#!/bin/bash
while true
do
    date >> /var/log/relogio.log
    sleep 10
done
```

- `#!/bin/bash` indica que o arquivo deve ser executado pelo bash.
- `while true` ... `done` repete os comandos de dentro para sempre.
- `date >> /var/log/relogio.log` acrescenta a data e a hora no final do arquivo de log.
- `sleep 10` espera 10 segundos antes de repetir.
- `/usr/local/bin` é o lugar padrão para programas instalados pelo administrador.

### 2. Criar o arquivo de unidade

Para ver um modelo, o arquivo de unidade do Apache:

```bash
systemctl cat httpd
```

Criar o do `relogio`:

```bash
sudo vi /etc/systemd/system/relogio.service
```

```ini
[Unit]
Description=Relógio de verificação do servidor

[Service]
ExecStart=/usr/local/bin/relogio.sh
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

| Seção | Opção | O que faz |
|---|---|---|
| `[Unit]` | `Description` | texto curto que aparece no `status` (sem aspas) |
| `[Service]` | `ExecStart` | o caminho **completo** do programa que o serviço executa |
| | `Restart=on-failure` | reinicia quando o processo cai por erro ou é morto por um sinal, como o `kill -9`. Uma parada normal, como no desligamento, não reinicia |
| `[Install]` | `WantedBy=multi-user.target` | em qual modo de operação o serviço sobe no boot |

```bash
sudo chmod 644 /etc/systemd/system/relogio.service
```

- Arquivos de configuração do sistema ficam com `644`: só o root edita, os outros só leem.

### 3. Iniciar e investigar a falha

```bash
sudo systemctl start relogio
systemctl status relogio
```

O serviço não subiu. Para ver o motivo:

```bash
journalctl -u relogio -e
```

- `-u relogio` mostra só os registros desse serviço.
- `-e` vai direto para o final, onde estão os mais recentes. `q` sai.

**Resultado obtido:**

```
relogio.service: Failed at step EXEC spawning /usr/local/bin/relogio.sh: Permission denied
```

| Trecho | Significa |
|---|---|
| `Failed at step EXEC` | falhou na etapa de **executar** o programa |
| `spawning /usr/local/bin/relogio.sh` | ao tentar iniciar o `relogio.sh` |
| `Permission denied` | por falta de permissão |

Um "Permission denied" pode vir das permissões comuns ou do SELinux. Para investigar os dois de uma vez:

```
$ ls -lZ /usr/local/bin/relogio.sh
-rw-r--r--. 1 root root unconfined_u:object_r:bin_t:s0 77 out 22 13:51 /usr/local/bin/relogio.sh
```

- O rótulo `bin_t` é o normal para programas, então o SELinux não é a causa.
- Ninguém tem o `x`: arquivos novos nunca nascem com permissão de execução (partem de `666` antes da umask).

### 4. Corrigir a permissão e iniciar de novo

```bash
sudo chmod 755 /usr/local/bin/relogio.sh
```

- `755` = dono `rwx`, grupo `r-x`, outros `r-x`. É o padrão para programas: todos executam, só o dono edita.

```bash
sudo systemctl start relogio
```

### 5. Deixar ativo no boot

```bash
sudo systemctl enable --now relogio
```

**Resultado obtido:**

```
Created symlink '/etc/systemd/system/multi-user.target.wants/relogio.service' → '/etc/systemd/system/relogio.service'.
```

O `enable` cria um link na pasta `multi-user.target.wants`. É assim que o systemd sabe que deve iniciar o serviço nesse modo de operação.

### 6. Deixar o journal permanente

Depois de um reboot, o `journalctl -u relogio --since today` mostrava só os registros da inicialização atual. No Rocky, o journal só é gravado em disco se a pasta `/var/log/journal` existir; sem ela, os registros ficam em `/run/log/journal`, que fica na memória e é apagada a cada reinicialização.

```bash
sudo mkdir /var/log/journal
sudo systemctl restart systemd-journald
```

- Com a pasta existindo, o journal passa a gravar em disco.
- `systemd-journald` é o serviço que cuida do journal; reiniciá-lo faz a mudança valer agora.

**Resultado obtido:**

```
$ ls -ld /var/log/journal
drwxr-sr-x+ 3 root systemd-journal 46 out 22 14:32 /var/log/journal
$ ls /var/log/journal
907d47c8e5254e52bb1c1919f13d368c
```

- O `s` no grupo é o **setgid**: tudo criado ali herda o grupo `systemd-journal`.
- O `+` indica **ACL**, que dá leitura a grupos como o `wheel`.
- A subpasta tem o nome do identificador único da máquina (*machine-id*).

> ⚠️ A gravação em disco só começa depois de a pasta existir. Os registros das inicializações anteriores não são recuperados.

---

## Testes

### Teste 1: serviço rodando e ativo no boot

```
$ systemctl status relogio
● relogio.service - Relógio de verificação do servidor
     Loaded: loaded (/etc/systemd/system/relogio.service; enabled; preset: disabled)
     Active: active (running) since Thu 2026-10-22 14:30:12 -03; 8s ago
   Main PID: 793 (relogio.sh)
     CGroup: /system.slice/relogio.service
             ├─ 793 /bin/bash /usr/local/bin/relogio.sh
             └─5181 sleep 10
```

Essa saída é de logo depois de um reboot: o serviço subiu sozinho. O Main PID baixo (`793`) mostra que ele foi um dos primeiros processos iniciados no boot.

### Teste 2: o log está sendo escrito

```
$ tail /var/log/relogio.log
qui 22 out 2026 14:29:34 -03
qui 22 out 2026 14:29:44 -03
qui 22 out 2026 14:29:47 -03
qui 22 out 2026 14:29:57 -03
qui 22 out 2026 14:30:12 -03
qui 22 out 2026 14:30:20 -03
```

O intervalo normal é de 10 segundos. Os intervalos diferentes mostram o que aconteceu com o servidor:

- `14:29:44` → `14:29:47`: o processo foi morto e o systemd o reiniciou imediatamente.
- `14:29:57` → `14:30:12`: a VM reiniciando.

### Teste 3: o systemd reinicia o serviço depois de um `kill -9`, e o journal guarda tudo entre reinicializações

```bash
systemctl status relogio      # anotar o Main PID
sudo kill -9 <MAIN_PID>
sudo reboot
```

Depois do reboot:

```
$ journalctl --list-boots
IDX BOOT ID                          FIRST ENTRY                 LAST ENTRY
 -1 11b71f8d070544d39b0263be3f0eadc8 Thu 2026-10-22 14:32:56 -03 Thu 2026-10-22 14:36:25 -03
  0 e21675e5f76b4d5abaf1fe70631acebe Thu 2026-10-22 14:36:25 -03 Thu 2026-10-22 14:36:34 -03

$ journalctl -u relogio -b -1
out 22 14:33:03 localhost systemd[1]: Started relogio.service - Relógio de verificação do servidor.
out 22 14:36:15 localhost.localdomain systemd[1]: relogio.service: Main process exited, code=killed, status=9/KILL
out 22 14:36:15 localhost.localdomain systemd[1]: relogio.service: Failed with result 'signal'.
out 22 14:36:15 localhost.localdomain systemd[1]: relogio.service: Scheduled restart job, restart counter is at 1.
out 22 14:36:15 localhost.localdomain systemd[1]: Started relogio.service - Relógio de verificação do servidor.
out 22 14:36:24 localhost.localdomain systemd[1]: Stopping relogio.service - Relógio de verificação do servidor...
out 22 14:36:24 localhost.localdomain systemd[1]: relogio.service: Deactivated successfully.
out 22 14:36:24 localhost.localdomain systemd[1]: Stopped relogio.service - Relógio de verificação do servidor.
```

- `--list-boots` lista as inicializações guardadas; `-b -1` mostra só a inicialização anterior à atual.

| Linha | O que aconteceu |
|---|---|
| `code=killed, status=9/KILL` | o processo foi morto pelo `kill -9` |
| `Failed with result 'signal'` | o systemd entendeu como falha, porque o processo morreu por um sinal |
| `Scheduled restart job, restart counter is at 1` | o `Restart=on-failure` entrou em ação |
| `Started relogio.service` | o serviço voltou no mesmo segundo |
| `Stopping` → `Deactivated successfully` → `Stopped` | o reboot: o systemd pediu a parada com **SIGTERM**. Como foi uma parada normal, não houve reinício |

---

## Erros que aconteceram e como foram resolvidos

| Sintoma | Causa | Correção |
|---|---|---|
| `cat relogio.sh` não achou o arquivo | Sem caminho, o Linux procura na pasta atual | Usar o caminho completo: `cat /usr/local/bin/relogio.sh` |
| O arquivo de unidade continuava vazio | O `vi` foi aberto sem `sudo` e não conseguiu salvar numa pasta do root | `sudo vi /etc/systemd/system/relogio.service` |
| `ExecStart=/etc/systemd/system/` | O `ExecStart` apontava para a pasta do arquivo de unidade, e não para o programa | `ExecStart=/usr/local/bin/relogio.sh` |
| `WantedBy=mlti-user.target` | Erro de digitação. O systemd não reclama, mas o serviço não sobe no boot, porque esse modo não existe | `WantedBy=multi-user.target` |
| `Description` com aspas curvas (`“ ”`) | O texto vai sem aspas no arquivo de unidade; as aspas curvas costumam vir de copiar e colar | Remover as aspas |
| `Failed at step EXEC ... Permission denied` | O script foi criado sem permissão de execução | `sudo chmod 755 /usr/local/bin/relogio.sh` |
| `journalctl --since today` mostrou o sistema inteiro | Faltou filtrar pelo serviço | `journalctl -u relogio --since today` |
| Os registros de antes do reboot sumiram | O journal estava só na memória | Criar `/var/log/journal` e reiniciar o `systemd-journald` |

---

## Resumo

- Um serviço é descrito num arquivo `.service`, com as seções `[Unit]`, `[Service]` e `[Install]`.
- `systemctl start` inicia agora; `systemctl enable` deixa ativo no boot; `enable --now` faz os dois.
- `Restart=on-failure` faz o systemd reiniciar o serviço quando ele cai ou é morto por um sinal.
- Quando um serviço falha: `systemctl status`, depois `journalctl -u <serviço>`, e só então mudar algo.
- "Permission denied" pode ser permissão comum ou SELinux: `ls -lZ` investiga os dois.
- O journal só sobrevive ao reboot se a pasta `/var/log/journal` existir.
