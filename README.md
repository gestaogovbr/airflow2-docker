# Ambiente Airflow2 da SEGES - Secretaria de Gestão

Neste repositório estão os códigos e instruções da instalação e
configuração do ambiente Airflow2 utilizado pelos desenvolvedores da
SEGES.

Este ambiente é similar ao de produção: utiliza a mesma versão do
Airflow, instala os mesmo módulos extras do Airflow e as mesmas
dependências python. Isso possibilita que o desenvolvimento seja
realizado totalmente em ambiente local de forma compatível com o
ambiente produção.

Este repositório foi adaptado a partir da solução oficial da Apache
Airflow disponível em
https://airflow.apache.org/docs/apache-airflow/stable/start/docker.html.

## Índice

* [1. Preparação e execução do Airflow](#1-preparação-e-execução-do-airflow)
* [2. Importando Plugins e DAGs](#2-importando-plugins-e-dags)
* [3. Executando o Airflow](#3-executando-o-airflow)
* [4. Configurações finais](#4-configurações-finais)
* [5. Acessos](#5-acessos)
* [6. Instalação de pacotes, atualizações e upgrades](#6-instalação-de-pacotes-atualizações-e-upgrades)


## 1. Preparação e execução do Airflow

### 1.1. Instalar Docker CE [aqui!](https://docs.docker.com/get-docker/)

Obs.: É necessário que o `docker-compose` tenha versão mínima `1.29`
No Ubuntu `20.04`, recomenda-se instalar o docker a partir do
gerenciador de pacotes *snap*:

```shell
snap install docker
```

### 1.2. Clonar o repositório [airflow2-docker](https://github.com/gestaogovbr/airflow2-docker)

```shell
git clone https://github.com/gestaogovbr/airflow2-docker.git
```

### 1.3. Variáveis de configuração do Airflow

Atualizar, se desejar, variáveis de ambiente em [.env](.env).

### 1.4. Conexões e Variáveis do Airflow

Caso deseje pré-carregar as conexões e variáveis do Airflow no seu ambiente,
sobrescreva os arquivos [airflow-connections.json](/config/airflow-connections.json)
e [airflow-variables.json](/config/airflow-variables.json).

### 1.5. Inicializar banco, variáveis e conexões Airflow

Dentro da pasta clonada (na raiz do arquivo Dockerfile), executar o
comando para gerar a estrutura do banco Postgres local e carregar conexões
e variáveis do Airflow:

```shell
# de dentro da pasta clonada `airflow2-docker`
docker compose -f init.yml up
# espera concluir o processo
# Crtl+C
docker compose -f init.yml down
```

Se tudo funcionar, o output do comando acima deve ser algo semelhante à
tela a seguir:

![airflow-init](/doc/img/airflow-init.gif)

> Se o docker build retornar a mensagem `error checking context:
> 'can't stat '/home/<user-linux>/.../mnt/pgdata''.`, então executar:

```shell
sudo chown -R $USER mnt
```

A conta criada possui o usuário `airflow` e a senha `airflow` conforme
configuração em [.env](.env).

Neste momento já é possível executar o Airflow. Porém ainda é necessário
clonar mais outros repositórios, tanto os que contém **plugins** do
Airflow assim como o repositório contendo as **DAGs** de fato.

## 2. Importando Plugins e DAGs

As DAGs desenvolvidas na Seges utilizam 3 frameworks (plugins). O
**FastETL** e **Ro-dou**, que estão aberto no github, e o **airflow_commons**.

### 2.1. Plugins e códigos auxiliares

#### 2.1.1. 🔗 [FastETL](https://github.com/gestaogovbr/FastETL)

Este plugin é a parte mais organizada dos algoritmos e extensões do
Airflow inventados pela equipe para realizar tarefas repetitivas dentro
das DAGs, como a **carga incremental** de uma tabela entre BDs ou a
**carga de uma planilha do google** em uma tabela no datalake.

#### 2.1.2. 🔗 [airflow_commons](https://git.economia.gov.br/seges-cginf/airflow_commons)

Já este é o que podemos chamar de "versão *alpha* do FastETL" ou o
"celeiro de novos plugins". Eventualmente você pode identificar um
código repetido em várias DAGs. Caso aconteça, você deveria refatorar e
criar um script no **airflow_commons**, e importá-lo nos diversos
projetos. A evolução seria esta função ser levada oficialmente ao
FastETL, para assim ser utilizada mais amplamente e melhor evoluída.

#### 2.1.3. 🔗 [Ro-dou](https://github.com/gestaogovbr/Ro-dou)

O Ro-dou é uma ferramenta para gerar dinamicamente DAGs no Apache Airflow
que fazem clipping do Diário Oficial da União (DOU) e dos Diários Oficiais
de municípios por meio do Querido Diário (QD). Receba notificações
(email, slack, discord ou outros) de todas as publicações que contenham
as palavras chaves que você definir.

#### 2.1.4. 🔗 [airflow-great-expectations](https://git.economia.gov.br/seges-cginf/airflow-great-expectations)

Repositório com jupyter notebook para criação de expectations para DAGs
do Airflow.

### 2.2. DAGs

Atualmente a SEGES possui 3 repositórios onde estão organizadas as DAGs
do DETRU, do DELOG e da CGINF e demais unidades:

* CGINF - https://git.economia.gov.br/seges-cginf/airflow-dags/
* DELOG - https://git.economia.gov.br/seges/airflow-dags-delog/
* DETRU - https://git.economia.gov.br/seges/airflow-dags-detru/

### 2.3. Importando repositórios

A partir do repositório superior ao `airflow2-docker` clonado em
[1.2. clonar repositório](#12-clonar-o-repositório-airflow2-docker):

```shell
# plugins
git clone https://github.com/gestaogovbr/FastETL.git && \
git clone https://git.economia.gov.br/seges-cginf/airflow_commons.git && \
git clone https://github.com/gestaogovbr/Ro-dou.git && \
git clone https://git.economia.gov.br/seges-cginf/airflow-great-expectations && \
# DAGs
git clone https://git.economia.gov.br/seges-cginf/airflow-dags.git && \
git clone https://git.economia.gov.br/seges/airflow-dags-delog.git && \
git clone https://git.economia.gov.br/seges/airflow-dags-detru.git
```

## 3. Executando o Airflow

### 3.1. Iniciar serviço

```shell
# de dentro da pasta clonada `airflow2-docker`
docker compose up
```

Primeira vez que rodar o `docker compose up` o output deve ser semelhante a isso:

![airflow-1st-up](/doc/img/airflow-init.gif)

Segunda em diante o output deve ser semelhante a isso:

![airflow-n-up](/doc/img/airflow-n-up.gif)

Acesse o Airflow em [http://localhost:8080/](http://localhost:8080/)

Neste momento a interface web do Airlfow provavelmente apresentará uma
lista enorme de erros. São erros indicando que o Airflow não consegue
encontrar as variáveis e conexões utilizadas na compilação das DAGs.
Para resolver prossiga com os passos seguintes.

### 3.2. Interromper serviço

```shell
# de dentro da pasta clonada `airflow2-docker`
# ou na tela de logs, Ctrl+C e depois
docker-compose down
```

## 4. Configurações finais

O Airflow possui módulos que possibilitam o isolamento de **variáveis**
e **conexões**, permitindo maior flexibilidade na configuração das DAGs
e a guarda segura (encriptada) das senhas utilizadas pelas DAGs para se
conectarem com os inúmeros serviços. As variáveis podem ser copiadas
facilmente do ambiente de produção, o que não é permitido com as
conexões, por motivos óbvios.

### 👉 Etapas 4.1. e 4.2. são opcionais caso não tenha atualizado os arquivos [airflow-connections.json](/config/airflow-connections.json) e [airflow-variables.json](/config/airflow-variables.json) na etapa [1.4. Conexões e Variáveis do Airflow](#14-conexões-e-variáveis-do-airflow)

### 4.1. (Opcional) Exportar variáveis do Airflow Produção e importar no Airflow Local

No Airflow produção acesse a tela de cadastro de variáveis
([Admin >> Variables](http://hom.airflow.seges.mp.intra//variable/list/)),
selecione todas as variáveis, e utilize a opção **Export** do menu
Actions e faça download do arquivo:

![Tela para exportação das variáveis](/doc/img/exportacao-variaveis.png)

Em seguida acesse a mesma tela no Airflow instalado localmente
[(Admin >> Variables)](http://localhost:8080/variable/list/) e utilize a
opção **Import Variables**.

### 4.2. (Opcional) Criar as conexões no Airflow Local

Esta etapa é similar à anterior, porém, por motivos de segurança, não é
possível realizar a exportação e importação das conexões. Dessa forma é
necessário criar cada conexão na sua instalação do Airflow local.
Todavia é possível listar e copiar todos os parâmetros de cada conexão
com exceção do *password*. Para isso acesse no Airflow produção a tela
de cadastro de conexões
([Admin >> Connectios](http://airflow.seges.mp.intra/connection/list/)).
Selecione e copie os parâmetros visíveis das conexões que você precisa
utilizar, e solicite as devidas senhas aos colegas da equipe.

Se você seguiu todas as etapas até aqui, o Airflow ainda deve estar
apresentando uma lista enorme de erros. Como explicado no parágrafo
acima, daqui pra frente será necessário cadastrar as conexões no Airflow
uma a uma, o que levará muito tempo, além de ser desnecessário para o
desenvolvimento de uma nova DAG ou para dar manutenção em apenas uma DAG
existente. Para reduzir drasticamente a lista de erros basta criar uma
conexão do tipo **HTTP** com nome `slack`. Isso silenciará praticamente
todos os erros.

Uma rápida explicação é de que esta conexão chamada `slack` é utilizada
por praticamente todas as nossas DAGs para envio de notificação em caso
de falhas. Caso você execute localmente alguma DAG que implementa esta
configuração, o seu Airflow  não enviará notificações de fato já que a
conexão criada não possui nenhuma propriedade preenchida, com exceção do
nome.

Para visualizar os parâmetros de uma conexão registrada no Airflow
produção, clique no botão **Edit record**:

![tela-listagem-conexoes](/doc/img/tela-listagem-conexoes.png)

## 5. Acessos

### 5.1. Serviços

* `Airflow UI` em [http://localhost:8080/](http://localhost:8080/)
* `Jupyter lab` em [http://localhost:8888/lab](http://localhost:8888/lab)

### 5.2. Volumes

* Os arquivos de banco ficam persistidos em `./mnt/pgdata`
* Os arquivos de log ficam persistidos em `./mnt/logs`
* As dags devem estar em um diretório paralelo a este chamado
  **nome-da-sua-pasta-de-dags**. Ou seja o Airflow está preparado para carregar as
  dags no diretório `../nome-da-sua-pasta-de-dags`. Se você executou corretamente
  o passo [2.3. Importando Repositórios](#23-importando-repositórios), este diretório já
  está devidamente criado.
* Para editar os volumes de `DAGs`, `plugins` e outros edite o [docker-compose.yml](docker-compose.yml#L26)

## 6. Instalação de pacotes, atualizações e upgrades

### 6.1. Instalação de pacotes Python

Novas bibliotecas python podem ser instaladas adicionando o nome e versão
(obrigatório) no arquivo [requirements-cdata-dags.txt](requirements-cdata-dags.txt).

Para aplicar as mudanças rodar o comando de atualização da imagem em
[6.3. Atualização da imagem airflow2-docker](#63-atualização-da-imagem-airflow2-docker).

### 6.2. Upgrade da versão do Airflow

Atualização na versão do Airflow é realizada alterando a imagem de build
em [Dockerfile](Dockerfile#L3) conforme `tags` disponíveis em [https://hub.docker.com/r/apache/airflow](https://hub.docker.com/r/apache/airflow).

Para aplicar as mudanças rodar o comando de atualização da imagem em
[6.3. Atualização da imagem airflow2-docker](#63-atualização-da-imagem-airflow2-docker).

### 6.3. Atualização da imagem airflow2-docker

```shell
# de dentro da pasta clonada `airflow2-docker`
docker build -t ghcr.io/gestaogovbr/airflow2-docker:latest-dev --build-arg dev_build=true .
```

### 6.4. Atualizar banco (quando necessário)

Dependendo da atualização do Airflow, será necessário atualizar os esquemas
do banco. Para descobrir:

```shell
docker compose up
```

Se der mensagem de erro relacionada a upgrade de banco, rodar:

```shell
docker compose -f init.yml up airflow-init
```

---
**Have fun!**
