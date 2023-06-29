## Time series raster data in Postgres using timescaleDB and postgis_raster

## Setting up

```bash
# pull the docker image with timescale and postgis extensions
docker pull timescale/timescaledb-ha:pg15.3-ts2.11.0-all

# Let's create a container
docker run -d --name timescaledb-pg_raster -e POSTGRES_PASSWORD=postgres -p 7432:5432 timescale/timescaledb-ha:pg15.3-ts2.11.0-all

export PGPASSWORD=postgres
export PGHOST=localhost

psql -p 7432
```

```SQL
-- Creating a database for storing precipitation data;
create database prec_data;
\c prec_data;
create extension if not exists timescaleDB;
create extension postgis_raster CASCADE;
```

## Let's add some data

Source: https://www.worldclim.org/data/monthlywth.html#
