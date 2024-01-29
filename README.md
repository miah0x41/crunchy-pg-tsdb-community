<!--toc:start-->

- [TimescaleDB Community Edition based on CrunchyData PostgreSQL](#timescaledb-community-edition-based-on-crunchydata-postgresql)
  - [Scope](#scope)
  - [Background](#background)
  - [Test Case](#test-case)
  - [Potential Remedy](#potential-remedy)
  - [Build](#build)
  - [Deploy](#deploy)
- [License](#license)
<!--toc:end-->

# TimescaleDB Community Edition based on CrunchyData PostgreSQL

Date: 29 Nov 2023

Author: miah0x41

![Docker Pulls](https://img.shields.io/docker/pulls/miah0x41/crunchy-pg-tsdb-community)

## Scope

The `timescaledb` _Community Edition_ packages built upon the _CrunchyData_ PostgresSQL images intended to be used with the _CrunchyData_ [PostgreSQL Operator (PGO)](https://access.crunchydata.com/documentation/postgres-operator/latest/). This repository contains a static example of a `Dockerfile` that combines both.

## Background

The default images used in the _CrunchyData_ [PostgreSQL Operator (PGO)](https://access.crunchydata.com/documentation/postgres-operator/latest/) are based on [CrunchyData PostgreSQL](https://www.crunchydata.com/), which is provisioned with the [Apache Licensed](https://www.apache.org/licenses/LICENSE-2.0) `timescaledb` extension only. This lacks importance features such as compression based on a [comparison of editions](https://www.timescale.com/products/editions).

## Test Case

A minimal use can be derived from the [PGO Blog Post](https://blog.crunchydata.com/blog/using-the-postgres-operator-to-deploy-timescaledb) on using _TimeScaleDB_. First of all extend the cluster definition with and apply changes:

```yaml
spec:
  patroni:
    dynamicConfiguration:
      postgresql:
        parameters:
          shared_preload_libraries: timescaledb
```

Connect to the cluster and using a `SUPERUSER` and confirm the library was loaded:

```sql
-- Show libraries
SHOW shared_preload_libraries;

  shared_preload_libraries
-----------------------------
 pgaudit,pgaudit,timescaledb

-- Add TimescaleDB extension
CREATE EXTENSION timescaledb;

WARNING:
WELCOME TO
 _____ _                               _     ____________
|_   _(_)                             | |    |  _  \ ___ \
  | |  _ _ __ ___   ___  ___  ___ __ _| | ___| | | | |_/ /
  | | | |  _ ` _ \ / _ \/ __|/ __/ _` | |/ _ \ | | | ___ \
  | | | | | | | | |  __/\__ \ (_| (_| | |  __/ |/ /| |_/ /
  |_| |_|_| |_| |_|\___||___/\___\__,_|_|\___|___/ \____/
               Running version 2.12.2
For more information on TimescaleDB, please visit the following links:

 1. Getting started: https://docs.timescale.com/timescaledb/latest/getting-started
 2. API reference documentation: https://docs.timescale.com/api/latest

Note: Please enable telemetry to help us improve our product by running: ALTER DATABASE "flood" SET timescaledb.telemetry_level = 'basic';

CREATE EXTENSION
```

Create a `hypertable` and insert data:

```sql
CREATE TABLE hippos (
  observed_at timestamptz NOT NULL,
  total int NOT NULL
);

SELECT create_hypertable('hippos', 'observed_at');

INSERT INTO hippos
SELECT ts, (random() * 100)::int
FROM generate_series(CURRENT_TIMESTAMP - '1 year'::interval, CURRENT_TIMESTAMP, '1 minute'::interval) ts;
```

Enable compression and apply a policy:

```sql
-- Enable compression
ALTER TABLE hippos SET (
  timescaledb.compress
);

ERROR:  functionality not supported under the current "apache" license. Learn more at https://timescale.com/.
HINT:  To access all features and the best time-series experience, try out Timescale Cloud.
```

If the _Community Edition_ is used, the compression can be enabled:

```sql
-- Enable compression
ALTER TABLE hippos SET (
  timescaledb.compress
);

ALTER TABLE

-- Apply compression policy
SELECT add_compression_policy('hippos', compress_after => INTERVAL '60d');

 add_compression_policy
------------------------
                   1000
(1 row)
```

## Potential Remedy

The absence of the _Community Edition_ was discussed in the PGO [GitHub Issue #2692](https://github.com/CrunchyData/postgres-operator/issues/2692) and it was recognised that due to licensing concerns/restrictions the summary was that users should generate their own container images. The `Dockerfile` was based on [a comment](https://github.com/CrunchyData/postgres-operator/issues/2692#issuecomment-1687095661):

```Dockerfile
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
```

The user needs to determine compatible versions of the base image, the `loader-postgresql`, `postgresql` and `toolkit-postgresql` packages:

1. Use the base images from PGO i.e. `ubi8-15.5-0`.
2. Identify suitable packages from the [Timescale Package Repository](https://packagecloud.io/app/timescale/timescaledb/search).
3. To determine a suitable `toolkit` package, the [Changelog](https://github.com/timescale/timescaledb-toolkit/releases) may need to be consulted.

## Build

Any suitable `Containerfile` or `Dockerfile` build tool can be used. The example utilises [`buildah`](https://buildah.io/):

```bash
# Navigate to desired directory
cd /path/to/directory

# Clone repository
git clone https://github.com/miah0x41/crunchy-pg-tsdb-community.git

# Navigate to repository
cd crunchy-pg-tsdb-community

# Build image for Docker Hub
buildah bud -t docker.io/<username>/crunchy-pg-tsdb-community:15.5-2.12.2

# Login to Docker Hub
buildah login docker.io

# Push image to Docker Hub
buidah push docker.io/<username>/crunchy-pg-tsdb-community:15.5-2.12.2
```

## Deploy

Update the cluster definition to use the new image from:

```yaml
spec:
  image: registry.developers.crunchydata.com/crunchydata/crunchy-postgres:ubi8-15.5-0
  postgresVersion: 15
```

Update to:

```yaml
spec:
  image: docker.io/<username>/crunchy-pg-tsdb-community:15.5-2.12.2
  postgresVersion: 15
```

And the license type of the extension:

```yaml
spec:
  patroni:
    dynamicConfiguration:
      postgresql:
        parameters:
          shared_preload_libraries: timescaledb
          timescaledb.license: timescale
```

Create a new cluster with the updated definition and repeat the test case, except the output of the compression commands should be as follows:

```sql
-- Enable compression
ALTER TABLE hippos SET (
  timescaledb.compress
);

ALTER TABLE

-- Apply compression policy
SELECT add_compression_policy('hippos', compress_after => INTERVAL '60d');

 add_compression_policy
------------------------
                   1000
(1 row)
```

# License

The user should take care to understand the myriad of licenses involved. The contents of this repository is licensed under [Apache 2.0](https://www.apache.org/licenses/LICENSE-2.0). The artifacts generated are not!

The base image is from _CrunchyData_ and subject to their licenses as per the [Crunchy Data Container Suite](https://access.crunchydata.com/documentation/crunchy-postgres-containers/latest/) and most notably the _TimescaleDB Community Edition_ are subject to the [Timescale License](https://github.com/timescale/timescaledb/blob/main/tsl/LICENSE-TIMESCALE).
