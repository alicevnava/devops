# DevOps — Trilha de Treinamento

Conteúdo básico/intermediário para quem está começando. DevOps não é uma ferramenta, é uma cultura/prática que une desenvolvimento e operações para entregar software com mais velocidade e confiabilidade. Este README cobre os pilares principais — pré-requisitos [Linux](../Linux/README.md) e [Redes](../Redes/README.md) ajudam bastante aqui.

---

## 1. O que é DevOps, de fato

- Quebrar o muro entre "quem escreve código" e "quem opera em produção".
- Automatizar tudo que é repetitivo: build, teste, deploy, provisionamento de infraestrutura.
- Medir, monitorar e aprender com falhas rápido (feedback loop curto).
- Ideia central: **"you build it, you run it"** — quem desenvolve também é responsável por rodar em produção.

---

## 2. Controle de versão (Git)

Base de tudo. Sem Git bem usado, nenhuma automação de CI/CD funciona direito.

```bash
git clone <repo>
git checkout -b feature/minha-feature
git add .
git commit -m "mensagem clara do que mudou"
git push origin feature/minha-feature
```

Conceitos importantes:
- **Branching strategy**: Git Flow, Trunk-Based Development, GitHub Flow — como o time organiza branches e releases.
- **Pull/Merge Request**: revisão de código antes de integrar.
- **Conflitos de merge**: acontecem quando duas mudanças colidem na mesma linha/arquivo — resolvidos manualmente.
- **.gitignore**: evita subir arquivos que não deveriam ir pro repositório (segredos, binários, node_modules).

---

## 3. CI/CD (Integração e Entrega/Deploy Contínuos)

- **CI (Continuous Integration)**: toda mudança de código é automaticamente construída e testada. Objetivo: pegar erro cedo.
- **CD (Continuous Delivery/Deployment)**: o código aprovado é automaticamente entregue (delivery = pronto para deploy manual; deployment = vai direto pra produção).

Pipeline típico:
```
commit → build → testes automatizados → análise de qualidade/segurança → deploy (staging) → testes de aceitação → deploy (produção)
```

Ferramentas comuns: **GitLab CI/CD**, **GitHub Actions**, **Jenkins**, **Azure DevOps**, **CircleCI**.

Exemplo simples de pipeline (GitLab CI, `.gitlab-ci.yml`):
```yaml
stages:
  - build
  - test
  - deploy

build:
  stage: build
  script:
    - echo "Compilando aplicação"

test:
  stage: test
  script:
    - echo "Rodando testes"

deploy:
  stage: deploy
  script:
    - echo "Fazendo deploy"
  only:
    - main
```

---

## 4. Containers (Docker)

Empacotam a aplicação com tudo que ela precisa (dependências, runtime) para rodar igual em qualquer lugar — resolve o clássico "na minha máquina funciona".

Conceitos:
- **Imagem**: template imutável (build a partir de um `Dockerfile`).
- **Container**: instância em execução de uma imagem.
- **Dockerfile**: receita de como construir a imagem.
- **Registry** (Docker Hub, ECR, GitLab Registry): onde imagens são armazenadas e distribuídas.
- **Volume**: persistência de dados fora do ciclo de vida do container.

```dockerfile
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
CMD ["node", "server.js"]
```

```bash
docker build -t minha-app:1.0 .
docker run -d -p 8080:8080 --name minha-app minha-app:1.0
docker ps                    # containers rodando
docker logs -f minha-app     # logs em tempo real
docker exec -it minha-app sh # acessar o terminal do container
```

**Docker Compose** — orquestra múltiplos containers localmente (ex: app + banco de dados):
```yaml
services:
  app:
    build: .
    ports:
      - "8080:8080"
  db:
    image: postgres:16
    environment:
      POSTGRES_PASSWORD: senha
```

---

## 5. Orquestração de containers (Kubernetes)

Quando você tem muitos containers em produção, precisa de algo que gerencie escala, falhas e atualizações — isso é o Kubernetes (k8s).

Conceitos-chave:
- **Pod**: menor unidade, um ou mais containers que compartilham rede/storage.
- **Deployment**: garante N réplicas de um Pod rodando, gerencia atualizações (rolling update).
- **Service**: expõe um conjunto de Pods com um endereço estável (interno ou externo).
- **Ingress**: roteia tráfego HTTP/HTTPS externo para Services, geralmente por domínio/path.
- **ConfigMap / Secret**: configuração e dados sensíveis desacoplados da imagem.
- **Namespace**: isolamento lógico dentro do cluster.

```bash
kubectl get pods
kubectl get deployments
kubectl apply -f deployment.yaml
kubectl logs -f <pod>
kubectl describe pod <pod>     # detalhes/eventos, ótimo para debug
kubectl exec -it <pod> -- sh
```

---

## 6. Infraestrutura como Código (IaC)

Definir infraestrutura (servidores, redes, bancos) em arquivos versionados, em vez de clicar manualmente em consoles.

- **Terraform**: declara infraestrutura de forma agnóstica de provedor (AWS, Azure, GCP).
  ```hcl
  resource "aws_instance" "servidor" {
    ami           = "ami-123456"
    instance_type = "t3.micro"
  }
  ```
  `terraform plan` (mostra o que vai mudar) → `terraform apply` (aplica).
- **Ansible**: automação de configuração de servidores (instalar pacotes, configurar serviços), usando playbooks YAML, sem agente instalado (via SSH).
- Benefício central: infraestrutura **versionada, revisável e reproduzível** — igual código de aplicação.

---

## 7. Cloud — conceitos essenciais

Os três grandes: **AWS**, **Azure**, **GCP**. Não precisa saber todos, mas os conceitos se repetem:

- **Compute**: máquinas virtuais (EC2, VM), funções serverless (Lambda, Functions).
- **Storage**: armazenamento de objetos (S3, Blob Storage), discos (EBS).
- **Networking**: VPC (rede virtual privada), subnets, load balancers.
- **IAM**: gerenciamento de identidade e permissões — quem pode fazer o quê.
- **Modelo de responsabilidade compartilhada**: o provedor cuida da infraestrutura física, você cuida da configuração e dos dados.

---

## 8. Monitoramento, Logs e Observabilidade

Os "3 pilares" da observabilidade:

| Pilar | O que é | Ferramentas comuns |
|---|---|---|
| **Métricas** | números ao longo do tempo (CPU, latência, taxa de erro) | Prometheus, Grafana |
| **Logs** | eventos registrados por aplicações/sistemas | ELK Stack (Elasticsearch, Logstash, Kibana), Loki |
| **Traces** | rastreamento de uma requisição através de múltiplos serviços | Jaeger, OpenTelemetry |

- **Alerting**: definir limites (thresholds) que disparam notificações antes que o problema vire incidente.
- **SLI/SLO/SLA**: indicadores e acordos de nível de serviço — quanto de disponibilidade/latência é aceitável.

---

## 9. Segurança (DevSecOps) — noções básicas

- Nunca commitar segredos (senhas, chaves de API) no código — usar **Secrets Manager**, variáveis de ambiente ou Vault.
- Escanear dependências e imagens em busca de vulnerabilidades (ex: `trivy`, `dependabot`).
- Aplicar **least privilege** (menor privilégio) em toda parte: IAM, permissões de arquivo, regras de firewall.
- **Shift-left security**: trazer verificações de segurança para o início do pipeline, não só no final.

---

## 10. Fluxo mental de um DevOps no dia a dia

```
código (Git) → pipeline CI/CD → build da imagem (Docker) → deploy (Kubernetes/Cloud)
     ↑                                                              │
     └────────────── monitoramento e feedback (logs/métricas) ──────┘
```

Tudo automatizado, tudo versionado, tudo observável.

---

## 11. Glossário rápido

- **Idempotência**: executar a mesma operação várias vezes produz o mesmo resultado (fundamental em IaC).
- **Rolling update**: atualizar réplicas gradualmente, sem downtime.
- **Blue-Green Deployment**: dois ambientes idênticos, troca instantânea de tráfego entre eles.
- **Canary Release**: libera a nova versão para uma pequena parte dos usuários antes do rollout completo.
- **Immutable Infrastructure**: em vez de alterar um servidor existente, você substitui por um novo já configurado corretamente.

---

## 12. Para praticar

1. Crie um repositório Git, escreva um `Dockerfile` para uma aplicação simples, e faça o build/run local.
2. Escreva um pipeline básico (GitLab CI ou GitHub Actions) que builda e testa a cada push.
3. Suba um cluster local (Minikube ou Kind) e faça o deploy da sua aplicação containerizada.
4. Escreva um `docker-compose.yaml` com app + banco de dados.
5. Configure Prometheus + Grafana localmente para monitorar um container.

## 13. Onde seguir aprendendo

- [Roadmap.sh — DevOps](https://roadmap.sh/devops) (base de referência deste conteúdo)
- Documentação oficial: [Docker](https://docs.docker.com/), [Kubernetes](https://kubernetes.io/docs/), [Terraform](https://developer.hashicorp.com/terraform/docs)
