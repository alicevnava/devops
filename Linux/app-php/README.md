# Exercício: publicar uma aplicação PHP em uma VM

## Pré-requisitos

Antes de iniciar o laboratório, instale o Git na máquina de trabalho e baixe o repositório do treinamento:
Caso não tenha criar uma conta no github.

```bash
sudo apt install git -y 
ou
sudo dnf/yum install git -y
```

```bash
git clone https://github.com/thiagoinacioalves/treinamento.git
cd ~/treinamento/Linux/app-php
```

Também é necessário ter:

- uma VM Linux criada e acessível pela rede;
- credenciais para acessar a VM;
- permissão para instalar e configurar serviços na VM;
- um navegador na máquina de trabalho;
- um web server com suporte ao PHP, que será preparado durante o exercício.

## Objetivo

Subir uma máquina virtual Linux, preparar um ambiente web, disponibilizar o código desta aplicação PHP e confirmar que a página está acessível pelo navegador.

O exercício conecta conceitos de infraestrutura e desenvolvimento: sistema operacional, instalação de serviços, organização de arquivos, permissões, processamento de PHP e atendimento de requisições HTTP.

## Resultado esperado

Ao final, a página `index.php` deve ser processada pelo PHP e exibida no navegador por meio do endereço da máquina virtual. A tela apresenta a mensagem **“Página publicada com sucesso!”**, o ambiente, o software do servidor web e a data e hora geradas no servidor.

## O que será praticado

- Criar ou iniciar uma VM Linux para o treinamento.
- Disponibilizar conectividade entre o computador do aluno e a VM.
- Instalar e habilitar um web server com suporte ao PHP.
- Transferir a pasta `app-php` para o diretório público do servidor.
- Conferir a posse e as permissões necessárias para a leitura dos arquivos.
- Acessar a aplicação usando o navegador.
- Observar a diferença entre um arquivo PHP processado pelo servidor e um arquivo estático.

## Fluxo do laboratório

1. Prepare uma VM Linux com recursos suficientes para o exercício e com acesso à rede.
2. Instale um web server e o interpretador PHP, mantendo os serviços habilitados para iniciar com o sistema.
3. Copie o conteúdo desta pasta para a área pública usada pelo web server.
4. Ajuste a posse e as permissões caso o serviço não consiga ler os arquivos.
5. Abra no navegador o endereço da VM e confirme que a mensagem de sucesso aparece.
6. Faça uma alteração simples no texto da página, atualize o navegador e confirme que a nova versão foi servida.

Este roteiro descreve o que precisa acontecer, sem prescrever comandos. A implementação pode variar conforme a distribuição Linux e o web server escolhidos.

## Critérios de conclusão

O laboratório está concluído quando:

- a VM está ligada e acessível pela rede;
- o web server está em execução;
- o PHP é processado sem aparecer como código-fonte no navegador;
- a página apresenta a mensagem de sucesso e os dados dinâmicos;
- uma alteração no arquivo é refletida em uma nova requisição;
- o aluno consegue explicar o caminho entre navegador, web server, PHP e arquivo da aplicação.

## Estrutura

```text
app-php/
├── index.php
└── README.md
```

## Observações

Esta aplicação é intencionalmente pequena e não usa banco de dados nem dependências externas. Ela serve como verificação visual de que o web server encontrou o arquivo, encaminhou a requisição ao PHP e devolveu uma página HTML ao navegador.
