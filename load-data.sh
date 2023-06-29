#!/bin/bash

# Set the directory path where the raster files are located
directory_path="./data"

# Set the PostgreSQL connection parameters
host="localhost"
port="7432"
database="prec_data"

# Loop through each file in the directory
for file in $directory_path/*; do
  # Execute raster2pgsql command for each file
  raster2pgsql -a -s 4326 -t 3x3 "$file" public.worldclim | psql -h $host -p $port -d $database
  # echo $file
done
