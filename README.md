# Programa de Treinamento — Trainee

Bem-vindo(a) ao programa de treinamento! Este repositório reúne o conteúdo básico/intermediário que você vai precisar para começar a atuar como analista, seguindo a trilha inspirada nos [roadmaps de DevOps](https://roadmap.sh/devops).

O foco aqui não é decorar comandos — é entender **como as coisas funcionam por baixo**, para que você consiga diagnosticar problemas com autonomia, e não só seguir receitas prontas.

---

## Como está organizado

| Pasta | Conteúdo |
|---|---|
| [Linux/](Linux/README.md) | Sistema operacional, permissões, processos, systemd, shell, logs — a base sobre a qual tudo mais roda |
| [Redes/](Redes/README.md) | IP, DNS, HTTP/HTTPS, TCP/UDP, firewalls, load balancers — como a informação trafega entre sistemas |
| [Devops/](Devops/README.md) | Git, CI/CD, Docker, Kubernetes, IaC, cloud, observabilidade — como tudo isso se junta na prática |

---

## Ordem recomendada de estudo

A trilha foi pensada em camadas — cada uma é pré-requisito da próxima:

```
1. Linux   → entender o sistema onde tudo roda (arquivos, permissões, processos)
2. Redes   → entender como sistemas se comunicam entre si
3. Devops  → juntar as duas bases para automatizar build, deploy e operação
```

Não pule direto para Devops sem passar pelas duas primeiras — boa parte dos conceitos de Docker, Kubernetes e CI/CD só fazem sentido quando você já entende processos Linux e portas/protocolos de rede.

---

## Como estudar cada módulo

1. Leia o README da pasta.
2. Não passe direto pelos comandos — execute-os. Suba uma VM ou container e mexa de verdade.
3. Faça os exercícios da seção "Para praticar" de cada README.
4. Se travar em algo, tente primeiro diagnosticar sozinho usando os comandos ensinados (isso é literalmente o trabalho do dia a dia) antes de pedir ajuda.
5. Ferramentas evoluem, mas os conceitos (permissões, camadas de rede, imutabilidade, pipelines) são estáveis — priorize entender o conceito, a ferramenta específica você pega rápido depois.

---

## Pré-requisitos

- Acesso a um terminal (Linux, WSL no Windows, ou uma VM/container).
- Git instalado.
- Curiosidade para testar e quebrar coisas em ambiente de treinamento — é o lugar certo para errar.

## Dúvidas ou sugestões

Se algo no material estiver confuso, desatualizado ou puder ser melhorado, fale com quem estiver conduzindo o treinamento — este conteúdo é vivo e deve evoluir com o feedback de quem está aprendendo.
