# Redes para DevOps — Trilha de Treinamento

Conteúdo básico/intermediário para quem está começando. O foco é entender como a informação viaja entre máquinas, porque toda aplicação distribuída, container ou serviço em nuvem depende disso — e a maioria dos incidentes em produção tem "rede" em algum ponto da causa raiz.

---

## 1. Por que Redes importa em DevOps

Você vai lidar com: containers se comunicando entre si, load balancers, DNS que não resolve, certificados TLS vencidos, portas bloqueadas por firewall, VPNs para acessar ambientes privados. Entender a base evita horas de troubleshooting às cegas.

---

## 2. O modelo em camadas (simplificado)

Não precisa decorar as 7 camadas OSI de cor, mas entender a ideia de **camadas** ajuda a isolar problemas:

| Camada | Exemplo | O que fazer quando falha |
|---|---|---|
| Aplicação | HTTP, DNS, SSH | erro 500, timeout de app |
| Transporte | TCP, UDP | porta fechada, conexão recusada |
| Rede | IP, roteamento | sem rota, IP errado |
| Enlace/Física | Ethernet, Wi-Fi | cabo, switch, interface down |

Quando algo não funciona, pergunte: "em que camada isso está quebrando?" — DNS não resolve (aplicação)? Porta não responde (transporte)? Sem conectividade nenhuma (rede/física)?

---

## 3. Endereçamento IP

- **IPv4**: `192.168.1.10` — 4 octetos, 0-255 cada.
- **Máscara de sub-rede / CIDR**: `192.168.1.0/24` — os primeiros 24 bits identificam a rede, o resto identifica o host. `/24` = 256 endereços (254 utilizáveis).
- **IP privado vs público**: faixas privadas (`10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`) não são roteáveis na internet — usadas em redes internas, VPCs, containers.
- **Gateway**: o "próximo salto" para tráfego que sai da rede local.
- **NAT (Network Address Translation)**: traduz IPs privados para um IP público compartilhado — é como sua rede de casa acessa a internet, e como containers Docker acessam a rede externa.

---

## 4. Portas e protocolos comuns

| Porta | Protocolo | Uso |
|---|---|---|
| 22 | SSH | acesso remoto seguro a servidores |
| 53 | DNS | resolução de nomes |
| 80 | HTTP | web sem criptografia |
| 443 | HTTPS | web com TLS/SSL |
| 25/587 | SMTP | envio de e-mail |
| 3306 | MySQL | banco de dados |
| 5432 | PostgreSQL | banco de dados |
| 6379 | Redis | cache/banco em memória |
| 8080 | HTTP alternativo | comum em apps/proxies |

Uma porta identifica **qual serviço**, dentro de uma máquina, deve receber o tráfego.

---

## 5. TCP vs UDP

- **TCP**: orientado a conexão, garante entrega e ordem (handshake de 3 vias: SYN, SYN-ACK, ACK). Usado quando confiabilidade importa — HTTP, SSH, bancos de dados.
- **UDP**: sem conexão, mais rápido, sem garantia de entrega. Usado em streaming, DNS, VoIP, onde velocidade importa mais que garantia total.

---

## 6. DNS (Domain Name System)

Traduz nomes (`exemplo.com`) em IPs. Fluxo básico:

```
navegador → resolver local → servidor raiz → servidor TLD (.com) → servidor autoritativo → IP retornado
```

Tipos de registro comuns:
- **A** — nome → IPv4
- **AAAA** — nome → IPv6
- **CNAME** — nome → outro nome (alias)
- **MX** — servidor de e-mail
- **TXT** — texto livre (validações, SPF, etc.)

Comandos:
```bash
nslookup exemplo.com
dig exemplo.com
dig +short exemplo.com A
```

---

## 7. HTTP/HTTPS

- **HTTP** é um protocolo request/response: cliente pede, servidor responde.
- Métodos: `GET` (ler), `POST` (criar), `PUT`/`PATCH` (atualizar), `DELETE` (remover).
- Códigos de status:
  - `2xx` sucesso (200 OK, 201 Created)
  - `3xx` redirecionamento (301, 302)
  - `4xx` erro do cliente (400 Bad Request, 401 Unauthorized, 403 Forbidden, 404 Not Found)
  - `5xx` erro do servidor (500 Internal Server Error, 502 Bad Gateway, 503 Service Unavailable, 504 Gateway Timeout)
- **HTTPS** = HTTP + TLS (criptografia). Certificados garantem autenticidade e criptografam o tráfego.

Testando:
```bash
curl -I https://exemplo.com          # só os headers
curl -v https://exemplo.com          # verbose, mostra handshake
```

---

## 8. TLS/SSL e certificados

- Certificado prova que o servidor é quem diz ser, e permite criptografar a comunicação.
- Emitido por uma **CA (Certificate Authority)** — ex: Let's Encrypt.
- Erros comuns: certificado expirado, cadeia incompleta, nome não corresponde ao domínio.
- `openssl s_client -connect exemplo.com:443` — inspecionar certificado de um host.

---

## 9. Firewalls e segurança de rede

- **Firewall**: filtra tráfego por regras (origem, destino, porta, protocolo).
- Em nuvem, isso normalmente é um **Security Group** (AWS) ou **NSG** (Azure) — regras de entrada (inbound) e saída (outbound).
- Regra de ouro: **negar tudo por padrão, liberar só o necessário** (princípio do menor privilégio, igual em permissões de arquivo).

---

## 10. Load Balancers e Proxies

- **Load Balancer**: distribui tráfego entre múltiplas instâncias de um serviço (round-robin, least-connections, etc.). Evita ponto único de falha e permite escalar horizontalmente.
- **Reverse Proxy** (ex: Nginx, Traefik, HAProxy): recebe requisições e as encaminha para servidores internos — usado para TLS termination, roteamento por path/domínio, cache.
- **Forward Proxy**: intermedia acesso de clientes para a internet (ex: proxy corporativo).

---

## 11. VPN e conectividade privada

VPN cria um túnel criptografado entre redes/hosts, simulando estar "dentro" de uma rede privada mesmo estando fisicamente fora. Comum para acessar ambientes internos de empresa ou VPCs em nuvem.

---

## 12. Redes em containers (conceito, aprofunda em Devops/)

Cada container geralmente tem seu próprio namespace de rede. Docker cria uma rede virtual (bridge) e faz NAT para o tráfego externo. Em Kubernetes, cada Pod recebe um IP próprio e a comunicação entre Pods/Services é abstraída por camadas adicionais (Service, Ingress).

---

## 13. Comandos de diagnóstico essenciais

| Comando | Uso |
|---|---|
| `ping host` | testa conectividade básica (ICMP) |
| `traceroute host` / `tracert` (Windows) | mostra o caminho (saltos) até o destino |
| `curl -v url` | testa requisição HTTP com detalhes |
| `dig` / `nslookup` | testa resolução DNS |
| `telnet host porta` ou `nc -zv host porta` | testa se uma porta está aberta |
| `ss -tulnp` / `netstat -tulnp` | mostra portas escutando localmente |
| `ip a` / `ip route` | mostra interfaces e tabela de rotas |

Fluxo de troubleshooting típico: **DNS resolve? → porta está aberta? → firewall libera? → aplicação responde?**

---

## 14. Para praticar

1. Use `dig` e `curl -v` para investigar como uma requisição a um site popular se resolve, do DNS ao TLS.
2. Suba dois containers Docker e teste a comunicação entre eles via nome de serviço.
3. Configure um Security Group/regra de firewall permitindo só a porta 443 e teste o que acontece com outras portas.
4. Use `traceroute`/`tracert` para visualizar os saltos até um servidor externo.

## 15. Onde seguir aprendendo

- [Roadmap.sh — DevOps](https://roadmap.sh/) (base de referência deste conteúdo)
- RFCs específicas quando quiser se aprofundar em um protocolo (ex: RFC 793 para TCP)
