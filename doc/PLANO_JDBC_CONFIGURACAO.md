# Configuração de Impala via JDBC no Airflow

Este documento explica como configurar e usar Impala através de JDBC no Airflow, caso você precise usar JDBC ao invés de Thrift (impyla).

## Status da Implementação

✅ **Configuração Completa**

- ✅ Java 17 (OpenJDK) instalado no Dockerfile
- ✅ Driver JDBC (`ImpalaJDBC42.jar`) copiado da pasta `driver/` local
- ✅ Provider JDBC do Airflow instalado
- ✅ Bibliotecas Python (`JayDeBeApi`, `JPype1`) instaladas
- ✅ CLASSPATH configurado
- ✅ Conexão `impala_jdbc` configurada no `airflow-connections.json`

**Versões utilizadas:**

- Java: OpenJDK 17 (disponível no Debian 12)
- Driver: `ImpalaJDBC42.jar` (versão 42)
- Classe do driver: `com.cloudera.impala.jdbc.Driver`

## Diferença: JDBC vs Thrift (impyla)

- **Thrift (impyla)**: Biblioteca Python pura, mais simples, já instalada
- **JDBC**: Protocolo padrão, compatível com mais ferramentas, requer driver

## Pré-requisitos

Para usar JDBC com Impala, você precisa:

1. **Driver JDBC do Impala** (Cloudera Impala JDBC Driver)
2. **Provider JDBC do Airflow** (`apache-airflow-providers-jdbc`)
3. **Biblioteca Python JDBC** (`JayDeBeApi` ou `py4j`)

## Instalação

**Status:** ✅ O Dockerfile já está configurado com todas as dependências necessárias.

### 1. Verificar o Dockerfile

O Dockerfile já está configurado com as seguintes dependências:

**Java 17 (OpenJDK):**

```dockerfile
# Instalar Java 17 (necessário para JDBC)
# Nota: Debian 12 (bookworm) só tem OpenJDK 17 disponível
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    openjdk-17-jdk-headless

# Definir JAVA_HOME
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV PATH=$PATH:$JAVA_HOME/bin
```

**Dependências Python para JDBC:**

```dockerfile
RUN pip install --no-cache-dir \
    apache-airflow-providers-jdbc \
    JayDeBeApi \
    JPype1
```

**Nota importante:** O Java 17 é usado porque é a versão disponível no Debian 12 (bookworm). O driver `ImpalaJDBC42.jar` é compatível com Java 17.

### 2. Driver JDBC do Impala

O driver JDBC do Impala está configurado para ser copiado da pasta local `driver/` durante o build.

**Configuração atual (driver local):**

```dockerfile
# Cria diretório para drivers JDBC do Impala
RUN mkdir -p /opt/impala/jdbc

# Copia driver JDBC do Impala local
COPY driver/ImpalaJDBC42.jar /opt/impala/jdbc/

# Ajusta permissões (usando UID/GID do usuário airflow - geralmente 50000)
RUN chown -R 50000:0 /opt/impala || chmod -R 755 /opt/impala

# Configura CLASSPATH para incluir drivers JDBC
ENV CLASSPATH=/opt/impala/jdbc/*:$CLASSPATH
```

**Requisitos:**

- O arquivo `ImpalaJDBC42.jar` deve estar na pasta `driver/` na raiz do projeto
- O driver será copiado automaticamente durante o build da imagem

**Nota:** Se você precisar usar um driver diferente ou baixar do Cloudera, pode modificar o Dockerfile para usar `curl` ao invés de `COPY`.

### 3. Build da Imagem

Após verificar que o driver `ImpalaJDBC42.jar` está na pasta `driver/`, execute o build:

```bash
docker build -t ghcr.io/gestaogovbr/airflow2-docker:latest-dev --build-arg dev_build=true .
```

**O que será instalado automaticamente:**

- ✅ Java 17 (OpenJDK)
- ✅ Provider JDBC do Airflow (`apache-airflow-providers-jdbc`)
- ✅ Bibliotecas Python (`JayDeBeApi`, `JPype1`)
- ✅ Driver JDBC (`ImpalaJDBC42.jar` copiado de `driver/`)
- ✅ CLASSPATH configurado

## Configuração da Conexão

### 1. Via Airflow UI

1. Acesse **Admin > Connections** no Airflow UI
2. Clique em **+** para adicionar uma nova conexão
3. Configure os seguintes campos:

   - **Connection Id**: `impala_jdbc` (ou outro nome)
   - **Connection Type**: `JDBC`
   - **Host**: `acessostageha.serpro.gov.br`
   - **Schema**: `default` (ou outro schema)
   - **Login**: Seu usuário
   - **Password**: Sua senha
   - **Port**: `21050`
   - **Extra**: JSON com a URL JDBC e driver:

     ```json
     {
       "driver_path": "/opt/impala/jdbc/ImpalaJDBC42.jar",
       "driver_class": "com.cloudera.impala.jdbc.Driver",
       "jdbc_url": "jdbc:impala://acessostageha.serpro.gov.br:21050/default;AuthMech=3;SSL=0"
     }
     ```

     **Nota:** Estamos usando o driver versão 42 (`ImpalaJDBC42.jar`) com a classe `com.cloudera.impala.jdbc.Driver`.

### 2. Via arquivo JSON

Edite o arquivo `config/airflow-connections.json` e adicione:

```json
{
  "impala_jdbc": {
    "conn_type": "jdbc",
    "description": "Conexão Impala via JDBC",
    "login": "seu_usuario",
    "password": "sua_senha",
    "host": "acessostageha.serpro.gov.br",
    "port": 21050,
    "schema": "default",
    "extra": "{\"driver_path\": \"/opt/impala/jdbc/ImpalaJDBC42.jar\", \"driver_class\": \"com.cloudera.impala.jdbc.Driver\", \"jdbc_url\": \"jdbc:impala://acessostageha.serpro.gov.br:21050/default;AuthMech=3;SSL=0\"}"
  }
}
```

### Parâmetros da URL JDBC

A URL JDBC do Impala segue este formato:

```
jdbc:impala://host:port/database;param1=value1;param2=value2
```

**Parâmetros comuns:**

- `AuthMech=3`: Autenticação PLAIN (usuário/senha)
- `AuthMech=1`: Sem autenticação
- `AuthMech=2`: Kerberos
- `SSL=0`: Desabilitar SSL
- `SSL=1`: Habilitar SSL
- `UseSasl=0`: Desabilitar SASL
- `UseSasl=1`: Habilitar SASL

## Exemplo de DAG usando JDBC

```python
from datetime import datetime, timedelta
from airflow import DAG
from airflow.providers.jdbc.operators.jdbc import JdbcOperator
from airflow.providers.jdbc.hooks.jdbc import JdbcHook

default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'email_on_failure': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

dag = DAG(
    'exemplo_impala_jdbc',
    default_args=default_args,
    description='Exemplo usando Impala via JDBC',
    schedule_interval=timedelta(days=1),
    start_date=datetime(2024, 1, 1),
    catchup=False,
    tags=['impala', 'jdbc'],
)


def executar_consulta_jdbc(**context):
    """Executa uma consulta usando JDBC."""
    hook = JdbcHook(jdbc_conn_id='impala_jdbc')

    # Executa uma consulta
    sql = "SHOW DATABASES"
    results = hook.get_records(sql)

    print(f"Databases encontrados: {results}")
    return results


# Usando JdbcOperator
task_consulta = JdbcOperator(
    task_id='listar_databases',
    jdbc_conn_id='impala_jdbc',
    sql='SHOW DATABASES',
    dag=dag,
)

# Usando JdbcHook em PythonOperator
from airflow.operators.python import PythonOperator

task_consulta_custom = PythonOperator(
    task_id='consulta_customizada',
    python_callable=executar_consulta_jdbc,
    dag=dag,
)
```

## Comparação: JDBC vs Thrift (impyla)

| Característica      | JDBC                                    | Thrift (impyla)                 |
| ------------------- | --------------------------------------- | ------------------------------- |
| **Complexidade**    | Mais complexo (requer Java, driver)     | Mais simples (Python puro)      |
| **Performance**     | Similar                                 | Similar                         |
| **Compatibilidade** | Padrão da indústria                     | Específico do Impala            |
| **Instalação**      | Requer driver e Java                    | Apenas pip install              |
| **Uso em DAGs**     | JdbcOperator/JdbcHook                   | Código Python direto            |
| **Recomendação**    | Use se precisar de compatibilidade JDBC | Use para desenvolvimento Python |

## Troubleshooting

### Erro: "Driver not found"

- Verifique se o driver está no caminho correto: `/opt/impala/jdbc/ImpalaJDBC42.jar`
- Verifique se o arquivo `driver/ImpalaJDBC42.jar` existe localmente antes do build
- Verifique se o `CLASSPATH` está configurado (deve incluir `/opt/impala/jdbc/*`)
- Verifique se o nome do arquivo `.jar` está correto (deve ser `ImpalaJDBC42.jar`)

### Erro: "Class not found"

- Verifique se o `driver_class` está correto: deve ser `com.cloudera.impala.jdbc.Driver`
- Verifique se todas as dependências do driver estão presentes
- Certifique-se de que está usando `ImpalaJDBC42.jar` e não `ImpalaJDBC41.jar`

### Erro: "Package openjdk-X-jdk-headless not available"

- **Debian 12 (bookworm)** só tem OpenJDK 17 disponível nos repositórios padrão
- Se você tentar usar OpenJDK 8 ou 11, receberá este erro
- Use `openjdk-17-jdk-headless` (já configurado no Dockerfile)
- O driver `ImpalaJDBC42.jar` é compatível com Java 17

### Erro: "chown: invalid group: 'airflow:airflow'"

- O grupo `airflow` pode não existir durante o build (quando ainda estamos como USER root)
- O Dockerfile usa `chown -R 50000:0` (UID diretamente) para evitar este problema
- O fallback `chmod -R 755` garante permissões de leitura mesmo se o chown falhar

### Erro de conexão

- Verifique se a URL JDBC está correta
- Verifique os parâmetros `AuthMech` e `SSL`
- Verifique se o host e porta estão acessíveis

### Erro de autenticação

- Verifique se `AuthMech=3` está na URL (para PLAIN)
- Verifique usuário e senha
- Para Kerberos, use `AuthMech=2` e configure o keytab

## Referências

- [Apache Airflow JDBC Provider](https://airflow.apache.org/docs/apache-airflow-providers-jdbc/stable/index.html)
- [Cloudera Impala JDBC Driver](https://www.cloudera.com/downloads/connectors/impala/jdbc.html)
- [JayDeBeApi Documentation](https://pypi.org/project/JayDeBeApi/)
- [Impala JDBC Connection String](https://www.cloudera.com/documentation/enterprise/latest/topics/impala_jdbc.html)
