FROM apache/airflow:2.6.3-python3.10

ARG PYTHON_DEPS=" \
    ctds==1.12.0 \
    tqdm==4.60.0 \
    ijson==3.0.4 \
    pysmb==1.2.6 \
    xlrd==1.2.0 \
    pygsheets==2.0.5 \
    ipdb==0.13.3 \
    py-trello==0.17.1 \
    PyPDF2==1.26.0 \
    frictionless==5.11.1 \
    great-expectations==0.17.2 \
    unidecode==1.2.0 \
    odfpy==1.4.1 \
    openpyxl==3.0.7 \
    pytest==6.2.5 \
    ckanapi==4.6 \
    sharepy==1.3.0 \
    Office365-REST-Python-Client==2.3.14 \
    GeoAlchemy2==0.10.2 \
    acryl-datahub-airflow-plugin==0.10.4 \
    geopandas==0.12.2 \
    "

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
  && ACCEPT_EULA=Y apt-get install -yqq msodbcsql17 \
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

RUN if [ -n "${PYTHON_DEPS}" ]; \
      then pip install --no-cache-dir --user ${PYTHON_DEPS}; \
    fi \
    && mkdir /opt/airflow/export-data

RUN pip install --no-cache-dir --user \
    apache-airflow[jdbc,microsoft.mssql,samba,google_auth,odbc,sentry] \
    apache-airflow-providers-docker \
    apache-airflow-providers-common-sql \
    apache-airflow-providers-telegram

ARG dev_build="false"
RUN \
  if [[ "${dev_build}" == "false" ]] ; \
  then pip install --no-cache-dir --user apache-airflow-providers-fastetl; \
  else \
  echo ***apache-airflow-providers-fastetl not installed*** ; \
  fi

RUN while [[ "$(curl -s -o /tmp/thawte.pem -w ''%{http_code}'' https://ssltools.digicert.com/chainTester/webservice/validatecerts/certificate?certKey=issuer.intermediate.cert.98&fileName=Thawte%20RSA%20CA%202018&fileExtension=txt)" != "200" ]]; do sleep 1; done
RUN cat /tmp/thawte.pem >> /home/airflow/.local/lib/python3.10/site-packages/certifi/cacert.pem
