# ==========================================
# ETAPA 1: Compilar la extensión duckdb_fdw
# ==========================================
FROM postgres:17.10 AS builder

# Instalar herramientas de compilación y herramientas de descarga (curl, unzip)
RUN apt-get update && apt-get install -y \
    build-essential \
    postgresql-server-dev-17 \
    git \
    wget \
    curl \
    unzip \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Descargar y compilar duckdb_fdw
RUN git clone https://github.com/alitrack/duckdb_fdw.git /build/duckdb_fdw
WORKDIR /build/duckdb_fdw
RUN ./download_libduckdb.sh
RUN make && make install

# ==========================================
# ETAPA 2: Imagen final limpia y optimizada
# ==========================================
FROM postgres:17.10

# Instalar dependencias y TimescaleDB oficial para PostgreSQL 17 (Debian Bookworm)
RUN apt-get update && apt-get install -y \
    gnupg \
    lsb-release \
    wget \
    ca-certificates \
    && wget --quiet -O - https://packagecloud.io/timescale/timescaledb/gpgkey | gpg --dearmor -o /usr/share/keyrings/timescale.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/timescale.gpg] https://packagecloud.io/timescale/timescaledb/debian/ $(lsb_release -c -s) main" | tee /etc/apt/sources.list.d/timescaledb.list \
    && apt-get update \
    && apt-get install -y timescaledb-2-postgresql-17 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copiar los binarios compilados de duckdb_fdw (versión 17) desde la ETAPA 1
COPY --from=builder /usr/lib/postgresql/17/lib/duckdb_fdw.so /usr/lib/postgresql/17/lib/
COPY --from=builder /usr/share/postgresql/17/extension/duckdb_fdw* /usr/share/postgresql/17/extension/

# Copiar la librería dinámica libduckdb y actualizar el enlazador
COPY --from=builder /build/duckdb_fdw/libduckdb.so /usr/lib/
RUN ldconfig

# Configurar la pre-carga automática de TimescaleDB y pg_stat_statements
RUN echo "shared_preload_libraries = 'timescaledb,pg_stat_statements'" >> /usr/share/postgresql/postgresql.conf.sample

EXPOSE 5432
