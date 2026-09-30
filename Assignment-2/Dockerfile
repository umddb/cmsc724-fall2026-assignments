# PostgreSQL Development Environment
# Builds PostgreSQL 17 from source with debug flags enabled.
# Students can modify source code, recompile, and experiment with extensions.
# The "university" database is pre-loaded so the image is ready to use on pull.

FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# ---------------------------------------------------------------------------
# Build dependencies
# ---------------------------------------------------------------------------
RUN apt-get update && apt-get install -y \
    # Core build tools
    build-essential \
    git \
    pkg-config \
    bison \
    flex \
    # Required libraries
    libreadline-dev \
    zlib1g-dev \
    libssl-dev \
    libxml2-dev \
    libxslt1-dev \
    libossp-uuid-dev \
    libldap2-dev \
    libpam0g-dev \
    libkrb5-dev \
    # Optional language runtimes for PL/Python, PL/Perl, PL/Tcl
    python3-dev \
    libperl-dev \
    tcl-dev \
    # Development & debugging tools
    gdb \
    valgrind \
    strace \
    linux-tools-generic \
    # Editor & utilities
    vim \
    nano \
    less \
    sudo \
    curl \
    wget \
    lsof \
    procps \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# Create the postgres user with passwordless sudo
# ---------------------------------------------------------------------------
RUN useradd -m -s /bin/bash postgres \
    && echo "postgres ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# ---------------------------------------------------------------------------
# Clone PostgreSQL 17 source (latest stable branch)
# ---------------------------------------------------------------------------
WORKDIR /home/postgres
RUN git clone --branch REL_17_STABLE --single-branch \
        https://github.com/postgres/postgres.git \
    && chown -R postgres:postgres /home/postgres/postgres

# ---------------------------------------------------------------------------
# Build & install PostgreSQL
# --enable-debug : keeps debug symbols, disables compiler optimizations
# --enable-cassert : enables runtime assertion checks (great for development)
# CFLAGS="-O0 -g3" : no optimization, maximum debug info
# ---------------------------------------------------------------------------
USER postgres
WORKDIR /home/postgres/postgres

RUN ./configure \
        --prefix=/usr/local/pgsql \
        --enable-debug \
        --enable-cassert \
        --with-openssl \
        --with-readline \
        --with-zlib \
        --with-libxml \
        --with-libxslt \
        --with-python \
        --with-perl \
        --with-tcl \
        --with-uuid=ossp \
        CFLAGS="-O0 -g3" \
    && make -j"$(nproc)" \
    && sudo make install \
    && make -C contrib -j"$(nproc)" \
    && sudo make -C contrib install

# ---------------------------------------------------------------------------
# Environment
# ---------------------------------------------------------------------------
ENV PATH="/usr/local/pgsql/bin:$PATH"
ENV LD_LIBRARY_PATH="/usr/local/pgsql/lib"
ENV PGDATA="/usr/local/pgsql/data"
ENV PGUSER="postgres"

# Persist env for interactive shells
RUN echo 'export PATH="/usr/local/pgsql/bin:$PATH"' >> /home/postgres/.bashrc \
    && echo 'export LD_LIBRARY_PATH="/usr/local/pgsql/lib"' >> /home/postgres/.bashrc \
    && echo 'export PGDATA="/usr/local/pgsql/data"' >> /home/postgres/.bashrc \
    && echo 'export PGUSER="postgres"' >> /home/postgres/.bashrc \
    && echo 'alias psql="psql -U postgres"' >> /home/postgres/.bashrc

# Give postgres ownership of the install directory so it can recompile & reinstall
RUN sudo chown -R postgres:postgres /usr/local/pgsql

# ---------------------------------------------------------------------------
# Initialize the "university" database and bake it into the image
# ---------------------------------------------------------------------------
COPY --chown=postgres:postgres DDL.sql                      /usr/local/pgsql/sql/DDL.sql
COPY --chown=postgres:postgres smallRelationsInsertFile.sql  /usr/local/pgsql/sql/smallRelationsInsertFile.sql
COPY --chown=postgres:postgres hello_world_exercise.md       /home/postgres/hello_world_exercise.md

RUN initdb -D "$PGDATA" --auth-local=trust --auth-host=trust -U postgres \
    && echo "listen_addresses = '*'" >> "$PGDATA/postgresql.conf" \
    && echo "host all all 0.0.0.0/0 trust" >> "$PGDATA/pg_hba.conf" \
    && pg_ctl -D "$PGDATA" -l "$PGDATA/initdb.log" start \
    && createdb university \
    && psql -d university -f /usr/local/pgsql/sql/DDL.sql \
    && psql -d university -f /usr/local/pgsql/sql/smallRelationsInsertFile.sql \
    && pg_ctl -D "$PGDATA" stop \
    && rm "$PGDATA/initdb.log"

# ---------------------------------------------------------------------------
# Entrypoint
# ---------------------------------------------------------------------------
COPY --chown=postgres:postgres entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# PostgreSQL port
EXPOSE 5432

ENTRYPOINT ["/entrypoint.sh"]
