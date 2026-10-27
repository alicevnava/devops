# Desafio 4 — Processos e Sinais: o Servidor Lento

Quarto desafio da Fase 1 (Linux sólido) da trilha de estudos: encontrar o processo que está deixando o servidor lento, baixar a prioridade dele e encerrá-lo sem prejudicar o trabalho de outras pessoas.

**Método:** observar antes de mudar, mudar uma coisa por vez e conferir depois de cada passo.

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
| **Processo** | todo programa em execução |
| **PID** | o número de identificação de cada processo |
| **Sinal** | um aviso enviado a um processo, como "termine" ou "interrompa" |
| **Prioridade (nice, coluna NI)** | decide quem usa a CPU primeiro quando ela está disputada. Vai de `-20` (mais prioridade) a `19` (menos prioridade); o padrão é `0` |

### Sinais mais usados

| Sinal | Número | O que faz |
|---|---|---|
| **SIGTERM** | 15 | pede que o processo termine. Ele **recebe o pedido** e pode se preparar: salvar o que estava fazendo, fechar arquivos. Também pode ignorar o pedido. É o padrão do `kill` |
| **SIGKILL** | 9 | o kernel remove o processo na hora. O programa **nem fica sabendo**, não pode ignorar e não tem chance de salvar nada |
| **SIGINT** | 2 | interrompe o processo em primeiro plano. É o que o **Ctrl+C** envia |

**Por que essa ordem:** primeiro o SIGTERM; se o processo não terminar depois de alguns segundos, aí sim o SIGKILL. Usar o `kill -9` de cara pode corromper arquivos ou deixar dados pela metade, por exemplo num banco de dados no meio de uma gravação.

---

## Preparação: criar o problema

Nesta etapa, quem faz o lab faz o papel de quem causou o incidente:

```bash
su - bruno
nohup yes > /dev/null &
nohup sleep 3000 &
exit
```

- `yes` repete a letra `y` sem parar. É um jeito simples de ocupar a CPU.
- `> /dev/null` joga a saída fora: o `/dev/null` descarta tudo o que recebe.
- `sleep 3000` só espera 3000 segundos. No cenário, ele faz o papel de um relatório importante do Bruno, que **não pode** ser interrompido.
- `&` roda o comando em segundo plano, liberando o terminal.
- `nohup` mantém o processo rodando mesmo depois do `exit`.

**Resultado esperado:** cada comando mostra um número entre colchetes e o PID, como `[1] 230954`.

> ⚠️ Cada comando precisa do seu próprio `&`. O `&` manda para o segundo plano **só o comando que vem antes dele**: em `nohup yes > /dev/null & nohup sleep 3000`, o `sleep` fica em primeiro plano e prende o terminal.

---

## Enunciado

Os usuários reclamam que o servidor ficou lento. É preciso descobrir o culpado e resolver, sem prejudicar o trabalho de ninguém.

### Objetivos

1. Descobrir qual processo está usando mais CPU, de qual usuário ele é e qual o PID dele.
2. Antes de encerrar, **baixar a prioridade** desse processo ao mínimo. Confirmar que a prioridade mudou.
3. Encerrar **só esse processo**, primeiro do jeito "educado". O relatório do Bruno (`sleep`) tem que continuar rodando.
4. Explicar a diferença entre os sinais **SIGTERM** e **SIGKILL**, e por que se usa um antes do outro.

### Resultado esperado

- Antes de encerrar, o processo aparece com a coluna **NI** valendo `19`.
- Depois de encerrar, o processo some e o uso de CPU cai.
- A lista de processos do `bruno` ainda mostra o `sleep 3000`.

---

## Passo a passo

Todos os comandos abaixo foram executados com o usuário administrador.

### 1. Encontrar o culpado

**Ao vivo, com o `top`:**

```bash
top
```

- Mostra os processos em tempo real. `P` (maiúsculo) ordena por CPU e `q` sai.
- Colunas mais úteis: `PID`, `USER`, `NI` e `%CPU`.

**Como uma "foto", com o `ps`:**

```bash
ps -eo pid,user,%cpu,command --sort=-%cpu | head -n 6
```

- `-e` inclui todos os processos do sistema, de todos os usuários.
- `-o pid,user,%cpu,command` escolhe as colunas.
- `--sort=-%cpu` ordena pela CPU, do maior para o menor (o `-` deixa em ordem decrescente).
- `| head -n 6` mostra só as 6 primeiras linhas: o cabeçalho e os 5 processos que mais usam CPU.

**Resultado obtido:**

```
    PID USER     %CPU COMMAND
 230954 bruno    99.5 yes
  39998 alice_e+  0.1 bash -c while true; do sleep 1;head -v -n 8 /proc/meminfo; ...
  39992 alice_e+  0.0 sshd-session: alice_estudo@pts/0
      1 root      0.0 /usr/lib/systemd/systemd --system --deserialize=69
 186352 apache    0.0 /usr/sbin/httpd -DFOREGROUND
```

O culpado é o `yes`, do usuário `bruno`, PID `230954`.

> ⚠️ Os PIDs mudam a cada execução. Nos comandos abaixo, troque `<PID_DO_YES>` e `<PID_DO_SLEEP>` pelos números que aparecerem no **seu** `ps`; os valores das saídas são só exemplos.

> ℹ️ O `bash -c while true...` é do MobaXterm: ele roda esse laço para mostrar a barra de monitoramento de CPU, memória e disco no rodapé da janela.

| | `top` | `ps` |
|---|---|---|
| Como mostra | ao vivo | uma "foto" do momento |
| `%CPU` | uso **agora** | média desde que o processo começou |
| Bom para | investigar um problema acontecendo | scripts e documentação |

### 2. Baixar a prioridade

```bash
sudo renice -n 19 -p <PID_DO_YES>
```

- `renice` muda a prioridade de um processo que já está rodando.
- `-n 19` define a menor prioridade possível.
- `-p <PID_DO_YES>` indica o PID do processo (no exemplo, `230954`).
- O `sudo` é necessário porque um usuário comum não pode mudar a prioridade de processos de outro usuário.

**Resultado obtido:**

```
230954 (process ID) old priority 0, new priority 19
```

Para conferir:

```bash
ps -u bruno -o pid,ni,%cpu,command
```

- `-u bruno` mostra só os processos do usuário `bruno`.

**Resultado obtido:**

```
    PID  NI %CPU COMMAND
 221533   0  0.0 sleep 3000
 230954  19 99.5 yes
```

> ℹ️ Mesmo com NI `19`, o `yes` continuou usando 99,5% da CPU. A prioridade **não limita** o uso da CPU: ela só decide quem passa na frente quando há disputa. Como nenhum outro processo queria CPU naquele momento, o `yes` continuou usando tudo. Se outro programa precisasse, o `yes` cederia a vez.

### 3. Encerrar só o culpado

```bash
sudo kill <PID_DO_YES>
```

- `kill` envia um sinal a um processo. Sem número, envia o **SIGTERM** (15), o pedido "educado".
- O `sudo` é necessário porque só o dono do processo (ou o root) pode enviar sinais a ele.

Se o processo ignorasse o SIGTERM e continuasse aparecendo, o próximo passo seria `sudo kill -9 <PID_DO_YES>` (SIGKILL).

### 4. Limpeza

Ao final, encerrar também o relatório do Bruno, que só existia para o cenário:

```bash
sudo kill <PID_DO_SLEEP>
```

---

## Testes

```
$ ps -u bruno -o pid,ni,%cpu,command
    PID  NI %CPU COMMAND
 221533   0  0.0 sleep 3000
```

O `yes` sumiu e o `sleep 3000` continuou rodando.

---

## Erros que aconteceram e como foram resolvidos

| Sintoma | Causa | Correção |
|---|---|---|
| O terminal ficou preso depois de iniciar os processos | O `sleep 3000` foi escrito sem o `&`, na mesma linha do `yes`, e rodou em primeiro plano | **Ctrl+C** para interromper e rodar de novo `nohup sleep 3000 &` |
| `renice` e `kill` sem `sudo` falharam | Um usuário comum só pode mexer nos próprios processos | Usar `sudo` |
| `renice: bad process ID value: PID` | O texto `PID` foi digitado literalmente, em vez do número | Usar o número do processo: `sudo renice -n 19 -p <PID_DO_YES>` |

---

## Resumo

- `top` mostra os processos ao vivo; `ps` tira uma "foto" e pode ser filtrado e ordenado.
- `renice` muda a prioridade de um processo em execução. NI maior significa **menos** prioridade.
- A prioridade só faz diferença quando há disputa pela CPU.
- `kill` envia sinais: primeiro o SIGTERM (padrão), e o SIGKILL (`-9`) só se o processo não terminar.
- Só o dono do processo ou o root pode mudar a prioridade dele ou enviar sinais.
