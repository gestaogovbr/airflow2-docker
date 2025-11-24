# for dev: docker build -t ghcr.io/gestaogovbr/airflow2-docker:latest-dev --build-arg dev_build=true .

FROM apache/airflow:2.10.4-python3.10

USER root
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
         build-essential \
         unixodbc-dev \
         libpq-dev \
         vim \
         unzip \
         git \
         telnet \
         libsasl2-dev \
         libsasl2-modules-gssapi-mit \
         openjdk-17-jdk-headless \
  && curl https://packages.microsoft.com/keys/microsoft.asc | tee /etc/apt/trusted.gpg.d/microsoft.asc \
  && curl https://packages.microsoft.com/config/debian/12/prod.list | tee /etc/apt/sources.list.d/mssql-release.list \
  && echo "deb [arch=amd64,arm64,armhf] https://packages.microsoft.com/debian/12/prod bookworm main" > /etc/apt/sources.list.d/mssql-release.list \
  && apt-get update -yqq \
  && ACCEPT_EULA=Y apt-get install -yqq msodbcsql17 \
  && sed -i '/\[openssl_init\]/a ssl_conf = ssl_configuration' /etc/ssl/openssl.cnf \
  && echo "[ssl_configuration]" >> /etc/ssl/openssl.cnf \
  && echo "system_default = tls_system_default" >> /etc/ssl/openssl.cnf \
  && echo "[tls_system_default]" >> /etc/ssl/openssl.cnf \
  && echo "MinProtocol = TLSv1" >> /etc/ssl/openssl.cnf \
  && echo "CipherString = DEFAULT@SECLEVEL=0" >> /etc/ssl/openssl.cnf \
  && curl -O http://acraiz.icpbrasil.gov.br/credenciadas/CertificadosAC-ICP-Brasil/ACcompactado.zip \
  && unzip ACcompactado.zip -d /usr/local/share/ca-certificates/ \
  && update-ca-certificates \
  && apt-get autoremove -yqq --purge \
  && apt-get clean \
  && rm -rf \
    /var/lib/apt/lists/* \
    /tmp/* \
    /var/tmp/* \
    /usr/share/man \
    /usr/share/doc \
    /usr/share/doc-base \
  && sed -i 's/^# en_US.UTF-8 UTF-8$/en_US.UTF-8 UTF-8/g' /etc/locale.gen \
  && sed -i 's/^# pt_BR.UTF-8 UTF-8$/pt_BR.UTF-8 UTF-8/g' /etc/locale.gen \
  && locale-gen en_US.UTF-8 pt_BR.UTF-8 \
  && update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# Instala Java 17 e configura variáveis de ambiente para JDBC
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV PATH=$PATH:$JAVA_HOME/bin

# Cria diretório para drivers JDBC do Impala
RUN mkdir -p /opt/impala/jdbc

# Copia driver JDBC do Impala local
COPY driver/ImpalaJDBC42.jar /opt/impala/jdbc/

# Ajusta permissões (usando UID/GID do usuário airflow - geralmente 50000)
RUN chown -R 50000:0 /opt/impala || chmod -R 755 /opt/impala

# Configura CLASSPATH para incluir drivers JDBC
ENV CLASSPATH=/opt/impala/jdbc/*:$CLASSPATH

# Instala certificado `Thawte` intermediário
RUN curl https://ssltools.digicert.com/chainTester/webservice/validatecerts/certificate?certKey=issuer.intermediate.cert.98&fileName=Thawte%20RSA%20CA%202018&fileExtension=txt >> /home/airflow/.local/lib/python3.10/site-packages/certifi/cacert.pem

USER airflow

WORKDIR /opt/airflow

COPY requirements-uninstall.txt .
COPY requirements-cdata-dags.txt .

RUN pip install --upgrade pip
RUN pip uninstall -y -r requirements-uninstall.txt

ARG dev_build="false"
RUN \
  if [[ "${dev_build}" == "false" ]] ; \
  then pip install --no-cache-dir apache-airflow-providers-fastetl; \
  else \
  echo ***apache-airflow-providers-fastetl not installed***  && \
  (curl -L --retry 5 --retry-delay 2 https://raw.githubusercontent.com/gestaogovbr/FastETL/main/requirements.txt -o /tmp/fastetl-requirements.txt && \
   pip install --no-cache-dir -r /tmp/fastetl-requirements.txt) || \
  echo "Aviso: Não foi possível baixar requirements do FastETL, continuando sem ele..." ; \
  fi

RUN pip install --no-cache-dir -r \
    https://raw.githubusercontent.com/gestaogovbr/Ro-dou/main/requirements.txt && \
    pip install --no-cache-dir \
    apache-airflow-providers-microsoft-mssql==4.0.0 \
    apache-airflow-providers-samba==4.9.0 \
    apache-airflow-providers-odbc==4.9.0 \
    apache-airflow-providers-docker==4.0.0 \
    apache-airflow-providers-common-sql==1.21.0 \
    apache-airflow-providers-telegram==4.7.0 \
    apache-airflow-providers-hashicorp==4.0.0 \
    apache-airflow-providers-microsoft-azure==12.4.1 \
    apache-airflow-providers-databricks==7.3.2 \
    airflow-provider-great-expectations==1.0.0a5 \
    apache-airflow-providers-jdbc \
    impyla \
    thrift \
    thrift-sasl \
    sasl \
    bit_array \
    JayDeBeApi \
    JPype1 && \
    pip install --no-cache-dir -r requirements-cdata-dags.txt



RUN while [[ "$(curl -s -o /tmp/thawte.pem -w ''%{http_code}'' https://ssltools.digicert.com/chainTester/webservice/validatecerts/certificate?certKey=issuer.intermediate.cert.98&fileName=Thawte%20RSA%20CA%202018&fileExtension=txt)" != "200" ]]; do sleep 1; done
RUN cat /tmp/thawte.pem >> /home/airflow/.local/lib/python3.10/site-packages/certifi/cacert.pem
RUN rm ACcompactado.zip requirements-cdata-dags.txt requirements-uninstall.txt
