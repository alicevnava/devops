# Trainee

Repositório com os estudos, exercícios e projetos práticos desenvolvidos
durante o programa de trainee em infraestrutura (Linux / DevOps / IA
infra) da Positivo.

## Sobre

Este repositório reúne o material produzido ao longo do trainee: exercícios
práticos de laboratório, anotações de estudo e scripts de automação criados
para reforçar os conceitos trabalhados no programa.

Cada laboratório tem uma pasta própria, com um `README.md` escrito para que
qualquer pessoa consiga **replicar o ambiente do zero** seguindo apenas a
documentação.

## Laboratórios

| Laboratório | Descrição
| --- | --- |
| [SEI/SIP 4.0](lab-sei/) | Instalação do SEI e do SIP 4.0.12.15 em Amazon Linux 2: Apache, PHP 7.3, MySQL 5.7, Memcached, Solr, agendamentos e HTTPS 
| [Aplicação PHP](exerciophp/) | Publicação de uma aplicação PHP em máquina virtual 
| [Crontab](lab-agendamento/) | Agendamento de tarefas no Linux com cron 
| [Troubleshooting](lab-troubleshooting/) | Diagnóstico e correção de problemas em ambiente Linux 
| [AWS com Docker](lab-aws-docker/) | Laboratório de containers Docker na AWS 

## Guias

| Guia | Descrição |
| --- | --- |
| [Notion para o GitHub](guia-git/) | Passo a passo para publicar uma documentação do Notion neste repositório com Git |

## Exercícios

Desafios práticos da trilha de estudos, organizados por fase, em [`exercicios/`](exercicios/).

| Fase | Exercícios |
| --- | --- |
| [Fase 1 — Linux sólido](exercicios/fase-1-linux/) | [Usuários, grupos e sudo](exercicios/fase-1-linux/desafio-01-usuarios-grupos-sudo/) · [Pasta compartilhada (setgid, umask e ACL)](exercicios/fase-1-linux/desafio-02-pasta-compartilhada/) · [SELinux: o site que não abre](exercicios/fase-1-linux/desafio-03-selinux-apache/) · [Processos e sinais: o servidor lento](exercicios/fase-1-linux/desafio-04-processos-sinais/) · [systemd e journalctl: o serviço que não sobe](exercicios/fase-1-linux/desafio-05-systemd-journalctl/) · [Pacotes com dnf: o servidor sem internet](exercicios/fase-1-linux/desafio-06-pacotes-dnf/) · [Discos, LVM e fstab: o espaço que acabou](exercicios/fase-1-linux/desafio-07-discos-lvm-fstab/) · [Rede no servidor: o IP que não para quieto](exercicios/fase-1-linux/desafio-08-rede/) · [SSH com chave: chega de senha](exercicios/fase-1-linux/desafio-09-ssh-chave/) · [cron, timers e tar: o backup que ninguém fazia](exercicios/fase-1-linux/desafio-10-backup-cron-timer/) · [Boot e recuperação da senha do root](exercicios/fase-1-linux/desafio-11-boot-senha-root/) |
| [Fase 2 — Redes e segurança](exercicios/fase-2-redes/) | [O caminho de uma requisição: cada erro conta uma história](exercicios/fase-2-redes/desafio-01-caminho-requisicao/) · [Proxy reverso: o Apache atrás do Nginx](exercicios/fase-2-redes/desafio-02-proxy-reverso-nginx/) · [HTTPS com uma CA própria](exercicios/fase-2-redes/desafio-03-https/) · [Balanceamento de carga com Nginx](exercicios/fase-2-redes/desafio-04-balanceamento/) · [Bastion SSH: um único ponto de entrada](exercicios/fase-2-redes/desafio-05-bastion-ssh/) |
| [Fase 3 — Git, Bash e Python](exercicios/fase-3-git-bash-python/) | [Git na prática](exercicios/fase-3-git-bash-python/desafio-01-git/) · [Bash I: o verificador de serviços](exercicios/fase-3-git-bash-python/desafio-02-bash-verifica-servicos/) · [Texto no terminal: o log do Nginx](exercicios/fase-3-git-bash-python/desafio-03-texto-log-nginx/) · [Bash II: o backup completo](exercicios/fase-3-git-bash-python/desafio-04-bash-backup/) · [Python: o backup reescrito](exercicios/fase-3-git-bash-python/desafio-05-python-backup/) · [Python com API, JSON e YAML](exercicios/fase-3-git-bash-python/desafio-06-python-api-json-yaml/) |

## Certificações-alvo

Trilha de certificações sendo trabalhada durante o trainee, na seguinte ordem:

1. EXIN DevOps Professional
2. EXIN (BCS) Artificial Intelligence Foundation
3. RHCSA (Red Hat Certified System Administrator)

## Autora

Alice Vivas Nava — [@alicevnava](https://github.com/alicevnava)
