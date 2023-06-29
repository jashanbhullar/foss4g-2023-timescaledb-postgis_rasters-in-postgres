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
Once you have downloaded the data, we can load the data using `raster2pgsql`

```bash
# Loading without a tile size will load the whole of raster in a single row
raster2pgsql -s 4326 -I wc2.1_10m_prec_2020-01.tif public.worldclim | psql -p 7432 -d prec_data

# Loading at 100x100
raster2pgsql -s 4326 -I -t 100x100 wc2.1_10m_prec_2020-01.tif public.worldclim_100x100 | psql -p 7432 -d prec_data

# Loading at 10x10
raster2pgsql -s 4326 -I -t 10x10 wc2.1_10m_prec_2020-01.tif public.worldclim_10x10 | psql -p 7432 -d prec_data

# Loading at 5x5
raster2pgsql -s 4326 -I -t 5x5 wc2.1_10m_prec_2020-01.tif public.worldclim_5x5 | psql -p 7432 -d prec_data

# have added a countries_shape as file which will be used in the queries below
psql -d prec_data -f ./countries_shapes_2023-06-29-12-25.sql
```

## Let's get those damn rasters!!

```SQL
-- Select all the rasters in India
select rid, rast
FROM worldclim_100x100 as worldclim join countries_shapes on ST_Intersects(worldclim.rast, countries_shapes.way) where countries_shapes.osm_id = '-304716'

-- Store these results as materialized views to view in QGIS and more analysis
-- 5x5
create materialized view india_rasters_5x5 as select rid, rast
FROM worldclim_5x5 as worldclim join countries_shapes on ST_Intersects(worldclim.rast, countries_shapes.way) where countries_shapes.osm_id = '-304716'
-- 501 rows

-- 10x10
create materialized view india_rasters_10x10 as select rid, rast
FROM worldclim_10x10 as worldclim join countries_shapes on ST_Intersects(worldclim.rast, countries_shapes.way) where countries_shapes.osm_id = '-304716'
-- 146

-- 100x100
create materialized view india_rasters_100x100 as select rid, rast
FROM worldclim_100x100 as worldclim join countries_shapes on ST_Intersects(worldclim.rast, countries_shapes.way) where countries_shapes.osm_id = '-304716'
-- 6
```

## Let's add way more data

```bash
# a simple script
./load-data.sh

# loads all the raster at 3x3 resolution
```

Adding temporal domain

```SQL
-- Add a new column to the table
ALTER TABLE worldclim  ADD COLUMN timestamp timestamp;

-- Update the new column with random timestamps
UPDATE worldclim  SET timestamp = timestamp '2000-01-01' + random() * (timestamp '2021-12-31' - timestamp '2000-01-01');

```

## Let's do some timescale stuff

```SQL
-- Creating a copy of table
CREATE TABLE worldclim_hypertable (
	rid serial4 NOT NULL,
	rast public.raster NULL,
	"timestamp" timestamp NULL,
	CONSTRAINT worldclim_hypertable_pkey PRIMARY KEY (rid)
);
CREATE INDEX worldclim_hypertable_st_convexhull_idx ON public.worldclim_hypertable USING gist (st_convexhull(rast));

-- create hypertable with 1 month chunks
SELECT create_hypertable('worldclim_hypertable', 'timestamp', chunk_time_interval => INTERVAL '1 month');

-- Let's load the data
Insert into worldclim_hypertable select * from worldclim ;
```

## Let's do some spatial-temporal stuff

```SQL
-- Get summary stats for an year
SELECT ST_SummaryStatsAgg(worldclim.rast, true, 1)
FROM worldclim
where timestamp >= '2001-01-01' AND timestamp < '2002-01-01';


-- Let's automate this step
-- yearly aggregates of all the rasters
CREATE MATERIALIZED VIEW worldclim_continous_aggregates_yearly(st_summarystatsagg)
WITH (timescaledb.continuous) AS
  SELECT ST_SummaryStatsAgg(worldclim_hypertable.rast, true, 1)
	FROM worldclim_hypertable
	group by time_bucket('1year', timestamp);
-- Boom
select * from worldclim_continous_aggregates_yearly;
```

## More things to try

- Add indexing on rasters using h3 and create zonal aggregates
- Use retention policy to remove old data
- Use compression policy to compress not-so-much accessed data
- Actions and automation using timescale to create workflows

Sources:

- https://www.worldclim.org/data/monthlywth.html#
- https://docs.timescale.com/api/latest
- https://postgis.net/docs/using_raster_dataman.html
- https://postgis.net/docs/RT_reference.html
- https://github.com/jashanbhullar/foss4g-2023-timescaledb-postgis_rasters-in-postgres
