FROM registry.developers.crunchydata.com/crunchydata/crunchy-postgres:ubi8-15.5-0

LABEL "org.opencontainers.image.authors"="miah0x41"

# Select user
USER root

# Add TimescaleDB repo and install community editions of components
RUN curl -sSL -o /etc/yum.repos.d/timescale_timescaledb.repo "https://packagecloud.io/install/repositories/timescale/timescaledb/config_file.repo?os=el&dist=8" && \
  microdnf update -y && \
  microdnf install -y timescaledb-2-loader-postgresql-15-2.12.2 && \
  microdnf install -y timescaledb-2-postgresql-15-2.12.2 && \
  microdnf install -y timescaledb-toolkit-postgresql-15-1.17.0 && \
  microdnf clean all

# Keep original user
USER 26
