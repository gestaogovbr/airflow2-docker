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

## Preparação e execução do Airflow

1. Instalar Docker CE [aqui!](https://docs.docker.com/get-docker/)

2. Clonar o repositório
   [airflow2-docker](https://github.com/economiagovbr/airflow2-docker)
   na máquina

```bash
git clone git@github.com:economiagovbr/airflow2-docker.git
cd airflow2-docker
```

3. No Linux, os volumes montados no contêiner usam as permissões de
   usuário / grupo do sistema de arquivos Linux nativo, portanto, você
   deve certificar-se de que o contêiner e o computador host têm
   permissões de arquivo correspondentes.

```bash
echo -e "AIRFLOW_UID=$(id -u)\nAIRFLOW_GID=0" > .env
```

4. Dentro da pasta clonada (na raiz do arquivo Dockerfile), executar o
   comando para gerar a estrutura do banco Postgres local

```bash
docker-compose -f docker-compose-cginf.yml up airflow-init
```

> Se o docker build retornar a mensagem `error checking context:
> 'can't stat '/home/<user-linux>/.../mnt/pgdata''.`, então executar:

```bash
sudo chown -R <user-linux> mnt/pgdata
```

Após a conclusão da inicialização, você deverá ver uma mensagem
como a seguir:

```
airflow-init_1       | Upgrades done
airflow-init_1       | Admin user airflow created
airflow-init_1       | 2.1.0
start_airflow-init_1 exited with code 0
```

A conta criada possui o usuário `airflow` e a senha `airflow`.

Neste momento já é possível executar o Airflow. Porém ainda é necessário
clonar mais outros repositórios, tanto os que contém **plugins** do
Airflow assim como o repositório contendo as **DAGs** de fato.

## Importando Plugins e DAGs

As DAGs desenvolvidas na Seges utilizam 2 frameworks (plugins). O
**FastETL**, que está aberto no github, e o **airflow_commons**.

### Importe o Framework FastETL

Este plugin é a parte mais organizada dos algoritmos e extensões do
Airflow inventados pela equipe para realizar tarefas repetitivas dentro
das DAGs, como a **carga incremental** de uma tabela entre BDs ou a
**carga de uma planilha do google** em uma tabela no datalake.

A partir do diretório corrente, execute:

```bash
cd ..

git clone https://github.com/economiagovbr/FastETL.git
```

### Importe o Framework airflow_commons

Já este é o que podemos chamar de "versão *alpha* do FastETL" ou o
"celeiro de novos plugins". Eventualmente você pode identificar um
código repetido em várias DAGs. Caso aconteça, você deveria refatorar e
criar um script no **airflow_commons**, e importá-lo nos diversos
projetos. A evolução seria esta função ser levada oficialmente ao
FastETL, para assim ser utilizada mais amplamente e melhor evoluída.

A partir do diretório corrente, execute:

```bash
git clone https://git.economia.gov.br/seges-cginf/airflow_commons.git
```

### Importe o repositório de DAGs do seu interesse

Atualmente a SEGES possui 3 repositórios onde estão organizadas as DAGs
do DETRU, do DELOG e da CGINF e demais unidades:

* CGINF - https://git.economia.gov.br/seges-cginf/airflow-dags/
* DELOG - https://git.economia.gov.br/seges/airflow-dags-delog/
* DETRU - https://git.economia.gov.br/seges/airflow-dags-detru/

Para clonar o repositório da **CGINF**, execute:

```bash
git clone https://git.economia.gov.br/seges-cginf/airflow-dags.git
```

Para clonar o repositório do **DELOG**, execute:

```bash
git clone https://git.economia.gov.br/seges/airflow-dags-delog.git
```

Para clonar o repositório do **DETRU**, execute:

```bash
git clone https://git.economia.gov.br/seges/airflow-dags-detru.git
```

## Executar o Airflow

A execução é feita de forma isolada por repositório de DAGs. Acesse o
repositório do ambiente local:

```bash
cd airflow2-docker
```

Para subir o Airflow com as dags da CGINF, execute:

```bash
docker-compose -f docker-compose-cginf.yml up -d
```

Para subir o Airflow com as dags do DELOG, execute:

```bash
docker-compose -f docker-compose-delog.yml up -d
```

Para subir o Airflow com as dags do DETRU, execute:

```bash
docker-compose -f docker-compose-detru.yml up -d
```


Acesse o Airflow em http://localhost:8080/ o/

Neste momento a interface web do Airlfow provavelmente apresentará uma
lista enorme de erros. São erros indicando que o Airflow não consegue
encontrar as variáveis e conexões utilizadas na compilação das DAGs.
Para resolver prossiga com os passos seguintes.

## Configurações finais

O Airflow possui módulos que possibilitam o isolamento de **variáveis**
e **conexões**, permitindo maior flexibilidade na configuração das DAGs
e a guarda segura (encriptada) das senhas utilizadas pelas DAGs para se
conectarem com os inúmeros serviços. As variáveis podem ser copiadas
facilmente do ambiente de produção, o que não é permitido com as
conexões, por motivos óbvios.

### Exportar variáveis do Airflow produção e importar no Airflow Local

No Airflow produção acesse a tela de cadastro de variáveis
([Admin >> Variables](http://airflow.seges.mp.intra/variable/list/)),
selecione todas as variáveis, e utilize a opção **Export** do menu
Actions e faça download do arquivo:

![Tela para exportação das variáveis](/doc/img/exportacao-variaveis.png)

Em seguida acesse a mesma tela no Airflow instalado localmente
[(Admin >> Variables)](http://localhost:8080/variable/list/) e utilize a
opção **Import Variables**.

### Criar as conexões no Airflow Local

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

![](/doc/img/tela-listagem-conexoes.png)

## Volumes

* Os arquivos de banco ficam persistidos em ```./mnt/pgdata```
* As dags devem estar em um diretório paralelo a este chamado
  **airflow-dag**. Ou seja o Airflow está preparado para carregar as
  dags no diretório ```../airflow-dags```. Se você executou corretamente
  o passo anterior (Clonando o repositório de dags), este diretório já
  está devidamente criado.

## Instalação de bibliotecas Python

Novas bibliotecas python podem ser instaladas adicionando o nome e
versão (opcional) na variável PYTHON_DEPS do arquivo
[Dockerfile](https://github.com/economiagovbr/airflow2-docker/blob/main/Dockerfile).

## Para desligar o ambiente Airflow

```bash
docker-compose -f docker-compose-cginf.yml down
```

ou

```bash
docker-compose -f docker-compose-delog.yml down
```

ou

```bash
docker-compose -f docker-compose-detru.yml down
```

## Para atualizar a imagem docker

```bash
docker-compose -f docker-compose-cginf.yml build
```

O comando deve ser executado na pasta que contém o arquivo
`docker-compose-cginf.yml`.

Após isso você já pode subir novamente os containers!

---
**Have fun!**
