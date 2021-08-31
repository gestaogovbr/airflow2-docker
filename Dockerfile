FROM apache/airflow:2.1.2-python3.7

ARG PYTHON_DEPS=" \
    ctds==1.12.0 \
    tqdm==4.60.0 \
    ijson==3.0.4 \
    pysmb==1.2.6 \
    pyodbc==4.0.30 \
    xlrd==1.2.0 \
    pygsheets==2.0.3.1 \
    python-slugify==3.0.3 \
    lxml==4.5.1 \
    beautifulsoup4==4.9.1 \
    ipdb==0.13.3 \
    py-trello==0.17.1 \
    PyPDF2==1.26.0 \
    frictionless==4.2.1 \
    SQLAlchemy==1.3.23  \
    google-api-python-client \
    google-auth-httplib2 \
    google-auth-oauthlib \
    great-expectations==0.13.19 \
    airflow-provider-great-expectations==0.0.2 \
    unidecode==1.2.0 \
    odfpy==1.4.1 \
    Markdown==3.3.4 \
    openpyxl==3.0.7 \
    "

USER root
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
         build-essential \
         unixodbc-dev \
         freetds-dev \
         freetds-bin \
         vim \
         unzip \
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

# instala pgodbc 9.3
COPY script/odbc_config /odbc_config
COPY config/psql_odbcini.txt /psql_odbcini.txt
RUN apt-get update \
    && apt-get install -yqq libpq-dev libssl-dev \
    && chmod 777 /odbc_config \
    && curl -O https://ftp.postgresql.org/pub/odbc/versions/src/psqlodbc-09.03.0400.tar.gz \
    && tar -zxvf psqlodbc-09.03.0400.tar.gz \
    && cd psqlodbc-09.03.0400 \
    && ./configure --with-unixodbc=/odbc_config \
    && make \
    && make install \
    && cat /psql_odbcini.txt >> /etc/odbcinst.ini

USER airflow
RUN pip install --no-cache-dir --user 'apache-airflow[jdbc,microsoft.mssql,samba,google_auth,odbc]'==2.1.2 \
    && pip install --no-cache-dir --user 'apache-airflow-providers-docker'==2.1.0 \
    && if [ -n "${PYTHON_DEPS}" ]; then pip install ${PYTHON_DEPS}; fi \
    && mkdir /opt/airflow/export-data