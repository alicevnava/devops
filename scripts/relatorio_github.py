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
