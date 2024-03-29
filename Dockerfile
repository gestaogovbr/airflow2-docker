# for dev: docker build -t ghcr.io/gestaogovbr/airflow2-docker:latest-dev --build-arg dev_build=true .

FROM apache/airflow:2.7.3-python3.10

USER root
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
         build-essential \
         unixodbc-dev \
         libpq-dev \
         freetds-dev \
         freetds-bin \
         vim \
         unzip \
         git \
  && curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add --no-tty - \
  && curl https://packages.microsoft.com/config/debian/10/prod.list > /etc/apt/sources.list.d/mssql-release.list \
  && apt-get update -yqq \
  && ACCEPT_EULA=Y apt-get install -yqq msodbcsql17 mssql-tools \
  && sed -i 's,^\(MinProtocol[ ]*=\).*,\1'TLSv1.0',g' /etc/ssl/openssl.cnf \
  && sed -i 's,^\(CipherString[ ]*=\).*,\1'DEFAULT@SECLEVEL=1',g' /etc/ssl/openssl.cnf \
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

# Instala certificado `Thawte` intermediário
RUN curl https://ssltools.digicert.com/chainTester/webservice/validatecerts/certificate?certKey=issuer.intermediate.cert.98&fileName=Thawte%20RSA%20CA%202018&fileExtension=txt >> /home/airflow/.local/lib/python3.10/site-packages/certifi/cacert.pem

USER airflow

WORKDIR /opt/airflow

COPY requirements-uninstall.txt .
COPY requirements-cdata-dags.txt .

RUN pip uninstall -y -r requirements-uninstall.txt && \
    pip install --no-cache-dir --user -r requirements-cdata-dags.txt && \
    pip install --no-cache-dir --user -r \
    https://raw.githubusercontent.com/gestaogovbr/Ro-dou/main/requirements.txt && \
    pip install --no-cache-dir --user \
    apache-airflow[jdbc,microsoft.mssql,samba,odbc,sentry] \
    apache-airflow-providers-docker \
    apache-airflow-providers-common-sql \
    apache-airflow-providers-telegram \
    acryl-datahub-airflow-plugin==0.10.4

ARG dev_build="false"
RUN \
  if [[ "${dev_build}" == "false" ]] ; \
  then pip install --no-cache-dir --user apache-airflow-providers-fastetl; \
  else \
  echo ***apache-airflow-providers-fastetl not installed***  && \
  pip install --no-cache-dir --user -r https://raw.githubusercontent.com/gestaogovbr/FastETL/main/requirements.txt ; \
  fi

RUN while [[ "$(curl -s -o /tmp/thawte.pem -w ''%{http_code}'' https://ssltools.digicert.com/chainTester/webservice/validatecerts/certificate?certKey=issuer.intermediate.cert.98&fileName=Thawte%20RSA%20CA%202018&fileExtension=txt)" != "200" ]]; do sleep 1; done
RUN cat /tmp/thawte.pem >> /home/airflow/.local/lib/python3.10/site-packages/certifi/cacert.pem
RUN echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bashrc && \
    source ~/.bashrc
RUN rm ACcompactado.zip requirements-cdata-dags.txt requirements-uninstall.txt
