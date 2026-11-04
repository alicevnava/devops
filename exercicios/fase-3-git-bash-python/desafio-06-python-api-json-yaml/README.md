# Desafio 3.6 — Python com API, JSON e YAML

Sexto e último desafio da Fase 3 (Git, Bash e Python) da trilha de estudos: um script que lê **quais repositórios** analisar numa configuração em **YAML**, consulta a **API do GitHub**, mostra um relatório e salva o resultado em **JSON**, tratando erros sem perder o que deu certo.

**Script final:** [`scripts/relatorio_github.py`](../../../scripts/relatorio_github.py) · **Configuração:** [`scripts/relatorio-github.yaml`](../../../scripts/relatorio-github.yaml)

**Método:** primeiro ver a API pelo `curl`, depois explorar JSON e YAML no modo interativo do Python (`>>>`), e só então escrever o script.

---

## Ambiente

| Item | Valor |
|---|---|
| **Servidor** | `servidor1` (Rocky Linux 10.2), Python 3.12, com acesso à internet pela `eth0` |
| **Bibliotecas** | `json`, `urllib`, `os`, `sys` (vêm com o Python) e `yaml` (pacote `python3-pyyaml`, já instalado: o `dnf` depende dele) |
| **API** | `https://api.github.com`, sem autenticação (60 pedidos por hora por IP) |

---

## Conceitos

| Termo | Significa |
|---|---|
| **API web** | um endereço que devolve **dados** para programas, em vez de uma página para pessoas |
| **JSON** | formato de dados: `{"chave": valor}`, listas `[...]`, textos entre aspas, números, `true`/`false`, `null` |
| **YAML** | formato de configuração para pessoas: `chave: valor`, listas com `-`, recuo com espaços (nunca TAB). É o formato do Ansible, do Kubernetes e do GitHub Actions |
| **Dicionário / lista** | o que JSON e YAML viram dentro do Python (`dict` e `list`) |
| **Token** | uma "senha" para programas; aumenta o limite da API e dá acesso a repositórios privados |
| **Variável de ambiente** | um valor que existe só na sessão do terminal e é herdado pelos programas que ela roda |

---

## Enunciado

Toda semana, um resumo dos repositórios da equipe no GitHub: o que tem lá, quando foi atualizado, quantos pull requests foram aceitos.

### Objetivos

1. Explorar a API com o `curl` e entender o JSON.
2. Ler JSON no Python.
3. Criar a configuração em YAML e lê-la no Python.
4. Consultar, para cada repositório, os dados e quantos PRs foram aceitos.
5. Tratar erros: um repositório que não existe não derruba o script; ele registra, segue e sai com 1 no fim.
6. Salvar o relatório em JSON.
7. Entregar por pull request.

**Bônus:** ler um token de uma variável de ambiente, nunca de um arquivo do repositório.

---

## Passo a passo

### 1. A API pelo `curl`

```
$ curl -s https://api.github.com/repos/alicevnava/devops
  "name": "devops",
  "description": "Laboratórios de infraestrutura Linux e DevOps documentados passo a passo",
  "language": "Shell",
  "updated_at": "2026-11-04T16:44:53Z",
  "html_url": "https://github.com/alicevnava/devops",
  ...
```

- `"language"`: o GitHub detecta a linguagem principal pelos arquivos.
- `"updated_at"`: formato ISO 8601; o `Z` é UTC (16:44 UTC = 13:44 em Brasília).

```
$ curl -s "https://api.github.com/repos/alicevnava/devops/pulls?state=closed" | grep '"merged_at"'
    "merged_at": "2026-11-04T16:44:47Z",
    "merged_at": "2026-11-04T16:41:37Z",
    ...
    "merged_at": "2026-11-03T17:10:16Z",
```

| Parte | O que faz |
|---|---|
| `/pulls?state=closed` | PRs fechados (por padrão, a API mostra só os abertos) |
| aspas no endereço | protegem o `?` do shell |

13 linhas, todas com data: os PRs #1 a #13 foram aceitos. Um PR fechado sem merge teria `"merged_at": null`. As branches apagadas antes do merge não aparecem porque o PR nem chegou a ser criado.

### 2. JSON no Python

```
$ python3
>>> import json
>>> import urllib.request
>>> resposta = urllib.request.urlopen("https://api.github.com/repos/alicevnava/devops")
>>> dados = json.loads(resposta.read())
>>> type(dados)
<class 'dict'>
>>> dados["name"]
'devops'
>>> dados["stargazers_count"]
0
>>> dados["nao_existe"]
KeyError: 'nao_existe'
>>> dados.get("nao_existe", "sem valor")
'sem valor'
>>> exit()
```

| Trecho | O que faz |
|---|---|
| `urllib.request.urlopen` | o `curl` do Python (vem com ele) |
| `json.loads` | texto JSON → dicionário |
| `dados["chave"]` | o valor; erro se a chave não existir |
| `dados.get("chave", padrão)` | o valor, ou o padrão (ou `None`, o `null` do Python) |

O `0` das estrelas vem sem aspas: é um número.

### 3. Configuração em YAML

```yaml
# Configuração do relatorio_github.py
usuario: alicevnava
repositorios:
  - devops
  - repo-que-nao-existe
saida: /tmp/relatorio-github.json
```

O `repo-que-nao-existe` estava lá de propósito, para testar o objetivo 5. A saída vai para o `/tmp`, para o relatório não ir para o repositório num `git add`.

```
>>> import yaml
>>> with open("scripts/relatorio-github.yaml") as arquivo:
...     config = yaml.safe_load(arquivo)
...
>>> config
{'usuario': 'alicevnava', 'repositorios': ['devops', 'repo-que-nao-existe']}
>>> type(config["repositorios"])
<class 'list'>
```

- `yaml.safe_load` só aceita dados simples e nunca executa nada que venha no arquivo: usar sempre o `safe_`.
- YAML e JSON viram a mesma coisa no Python: dicionários e listas.

### 4. O script

```python
#!/usr/bin/env python3
"""Relatório dos repositórios do GitHub listados num arquivo YAML.

Uso: relatorio_github.py <arquivo de configuração>
Se a variável de ambiente GITHUB_TOKEN existir, ela é usada na autenticação.
"""

import json
import os
import sys
import urllib.error
import urllib.request

import yaml

API = "https://api.github.com"


def consultar(caminho):
    cabecalhos = {"Accept": "application/vnd.github+json", "User-Agent": "relatorio-github"}
    token = os.environ.get("GITHUB_TOKEN")
    if token:
        cabecalhos["Authorization"] = f"Bearer {token}"
    pedido = urllib.request.Request(API + caminho, headers=cabecalhos)
    with urllib.request.urlopen(pedido, timeout=10) as resposta:
        return json.loads(resposta.read())


def resumir(usuario, nome):
    repo = consultar(f"/repos/{usuario}/{nome}")
    pulls = consultar(f"/repos/{usuario}/{nome}/pulls?state=closed&per_page=100")
    aceitos = 0
    for pr in pulls:
        if pr["merged_at"]:
            aceitos += 1
    return {
        "nome": repo["name"],
        "descricao": repo.get("description"),
        "linguagem": repo.get("language"),
        "atualizado_em": repo["updated_at"],
        "prs_aceitos": aceitos,
        "url": repo["html_url"],
    }


def main():
    if len(sys.argv) != 2:
        print(f"Uso: {sys.argv[0]} <arquivo de configuração>")
        sys.exit(1)

    with open(sys.argv[1]) as arquivo:
        config = yaml.safe_load(arquivo)

    usuario = config["usuario"]
    resultados = []
    erros = 0

    for nome in config["repositorios"]:
        try:
            resumo = resumir(usuario, nome)
        except urllib.error.HTTPError as erro:
            print(f"ERRO: {usuario}/{nome}: {erro.code} {erro.reason}")
            erros += 1
            continue
        resultados.append(resumo)
        print(f"{resumo['nome']}: {resumo['linguagem']}, "
              f"atualizado em {resumo['atualizado_em']}, "
              f"{resumo['prs_aceitos']} PRs aceitos")

    with open(config["saida"], "w") as saida:
        json.dump(resultados, saida, indent=2, ensure_ascii=False)
        saida.write("\n")
    print(f"Relatório salvo em {config['saida']} ({len(resultados)} repositórios)")

    if erros > 0:
        sys.exit(1)


if __name__ == "__main__":
    main()
```

| Parte | O que faz |
|---|---|
| `consultar` | uma função para os dois pedidos à API. `User-Agent` é obrigatório no GitHub; `Accept` pede o formato atual; `timeout=10` desiste em 10 s |
| `resumir` | dados do repositório + PRs fechados (`per_page=100`), e devolve um dicionário só com o que interessa |
| `if pr["merged_at"]:` | `None` conta como falso; uma data, como verdadeiro |
| `sys.argv` | `sys.argv[0]` = `$0`, `sys.argv[1]` = `$1`; `len(sys.argv) != 2` = `[ "$#" -ne 1 ]` |
| `except urllib.error.HTTPError` + `continue` | um erro da API (404, 403...) é registrado e o laço segue para o próximo |
| `resultados.append` | acrescenta no fim da lista |
| `json.dump(..., indent=2, ensure_ascii=False)` | grava legível e com acentos (sem o `ensure_ascii=False`, `ó` vira `ó`) |
| `saida.write("\n")` | quebra de linha no fim do arquivo (sem ela, o `]` fica grudado no prompt no `cat`) |
| `if erros > 0: sys.exit(1)` | salva o que deu certo, mas avisa pelo código de saída |

### 5. Bônus: token pela variável de ambiente

```
$ curl -s https://api.github.com/rate_limit | grep -A4 '"core"'
    "core": {
      "limit": 60,
      "remaining": 39,
      "reset": 1793813619,
      "used": 21
```

- Sem autenticação: 60 pedidos por hora **por IP**. Cada execução gasta 2 por repositório. `date -d @1793813619` mostra quando o limite zera.
- Com token: 5.000 por hora e acesso a repositórios privados.
- `os.environ.get("GITHUB_TOKEN")`: se a variável existir, o script manda `Authorization: Bearer <token>`; se não, funciona igual, com o limite menor.

**Por que nunca num arquivo do repositório:** o que vai para o GitHub fica no histórico para sempre (apagar depois não tira dos commits antigos), e o GitHub revoga tokens encontrados em repositórios públicos.

**Como usar** (não testado com token real nesta rodada; o script funcionou sem ele):

```bash
read -s GITHUB_TOKEN
export GITHUB_TOKEN
./scripts/relatorio_github.py scripts/relatorio-github.yaml
```

`read -s` recebe o token sem mostrar na tela e sem ir para o `history` (ao contrário de `export GITHUB_TOKEN=...` digitado direto). A variável some ao sair da sessão. Para criar um token: GitHub → Settings → Developer settings → Personal access tokens → Fine-grained tokens, com validade curta e só leitura.

---

## Testes

**Com o repositório inexistente:**

```
$ ./scripts/relatorio_github.py scripts/relatorio-github.yaml
devops: Shell, atualizado em 2026-11-04T16:44:53Z, 13 PRs aceitos
ERRO: alicevnava/repo-que-nao-existe: 404 Not Found
Relatório salvo em /tmp/relatorio-github.json (1 repositórios)
$ echo $?
1
```

O erro não derrubou o script, o resultado do `devops` foi salvo, e o código 1 avisa que algo falhou.

**Configuração final, com repositórios reais:**

```yaml
# Configuração do relatorio_github.py
usuario: alicevnava
repositorios:
  - devops
  - site-pessoal
  - Pomodoro_React
  - cafeteria
saida: /tmp/relatorio-github.json
```

Os nomes vieram de `curl -s https://api.github.com/users/alicevnava/repos | grep '"name"'`. Nessa lista apareceram também linhas `"name": "MIT License"`, com mais recuo: é a chave `name` da **licença**, um objeto dentro do repositório. O `grep` só procura texto; o Python entende a estrutura (`dados["license"]["name"]`).

```
$ ./scripts/relatorio_github.py scripts/relatorio-github.yaml
devops: Python, atualizado em 2026-11-04T17:22:51Z, 14 PRs aceitos
site-pessoal: CSS, atualizado em 2025-02-06T20:00:37Z, 0 PRs aceitos
Pomodoro_React: JavaScript, atualizado em 2024-11-17T14:49:00Z, 0 PRs aceitos
cafeteria: TypeScript, atualizado em 2025-04-14T19:05:53Z, 0 PRs aceitos
Relatório salvo em /tmp/relatorio-github.json (4 repositórios)
$ echo $?
0
$ cat /tmp/relatorio-github.json
[
  {
    "nome": "devops",
    "descricao": "Laboratórios de infraestrutura Linux e DevOps documentados passo a passo",
    "linguagem": "Python",
    "atualizado_em": "2026-11-04T17:22:51Z",
    "prs_aceitos": 14,
    "url": "https://github.com/alicevnava/devops"
  },
  ...
  {
    "nome": "cafeteria",
    "descricao": null,
    "linguagem": "TypeScript",
    "atualizado_em": "2025-04-14T19:05:53Z",
    "prs_aceitos": 0,
    "url": "https://github.com/alicevnava/cafeteria"
  }
]
```

- O `devops` passou de `Shell` para `Python`: com o `relatorio_github.py`, o código Python passou o Bash. E o PR #14 entrou na conta.
- `"descricao": null`: o `cafeteria` não tem descrição; o `null` da API virou `None` no Python e `null` de novo no JSON, sem quebrar nada.

**Entrega:** pull request #14.

```
*   c0bf920 (HEAD -> main, origin/main, origin/HEAD) Merge pull request #14 from alicevnava/script-relatorio-github
|\
| * c761095 Adiciona o script relatorio_github.py e a configuração em YAML
|/
```

---

## Erros que aconteceram e como foram resolvidos

| Sintoma | Causa | Correção |
|---|---|---|
| `SyntaxError: invalid syntax` no `>>>` | Duas linhas coladas numa só; o `^^^^^` aponta onde o Python se perdeu | Uma expressão por linha |
| `]` do JSON grudado no prompt | O `json.dump` não escreve quebra de linha no fim | `saida.write("\n")` |
| `403 Forbidden` (num teste feito de outra máquina) | O limite de 60 pedidos/hora do IP acabou | Esperar o `reset` do `rate_limit`, ou usar um token. O script tratou o 403 como o 404: registrou e seguiu |

---

## Resumo

- API web = endereço que devolve dados (JSON). `curl` para olhar, `urllib.request` no Python.
- `json.loads` (texto → dicionário/lista) e `json.dump(indent=2, ensure_ascii=False)` (o contrário, legível).
- YAML para configuração; `yaml.safe_load`, sempre o `safe_`.
- `dict["chave"]` falha se não existir; `dict.get("chave", padrão)` não.
- `try`/`except HTTPError` + `continue`: um erro não derruba o resto; o código de saída avisa.
- `grep` em JSON pega texto, não estrutura.
- Segredos (tokens) em variáveis de ambiente (`os.environ.get`), nunca no repositório; `read -s` para não deixar no `history`.
