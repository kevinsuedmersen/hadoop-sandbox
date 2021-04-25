# Hadoop Sandbox
This repos was forked from https://github.com/zar3bski/hadoop-sandbox and the following components were added:
- A PostgreSQL database backend for HUE, so that HiveQL queries can be executed
- A Spark cluster with one master and two worker nodes
- A Jupyter Notebook server to write code that is executed in the Spark cluster

# Prerequisits
you'll need a [docker engine](https://docs.docker.com/install/linux/docker-ce/ubuntu/) and [docker-compose](https://docs.docker.com/compose/)

# Setup
1. Clone this repo

2. Add an `.env` file at the root that contains the following info:
```
CLUSTER_NAME=the_name_of_your_cluster
ADMIN_NAME=your_name
ADMIN_PASSWORD=def@ultP@ssw0rd
INSTALL_PYTHON=true # whether you want python or not (to run hadoop streaming)
INSTALL_SQOOP=true
```

3. Install and start all services with `docker-compose up -d`

# Relevant locations
- hadoop streaming `/opt/hadoop-3.2.1/share/hadoop/tools/lib/hadoop-streaming-3.1.1.jar`

# Web interfaces:
- [Yarn ressource manager](http://localhost:8088)
- [hue](http://localhost:8000)
- [namenode overview](http://localhost:9870)
- [Spark master](http://localhost:8080/)
- [Jupyter Notebook server](http://localhost:8888). To See which token must be entered, execute
`docker exec jupyter-spark jupyter notebook list`

# Sources
Most sources were gathered from [big-data-europe](https://www.big-data-europe.eu/)'s repos
- [main repos](https://hub.docker.com/r/bde2020)
- [base of the docker-compose](https://github.com/big-data-europe/docker-hadoop/blob/master/docker-compose.yml)
parts added
- [hue](https://hub.docker.com/r/gethue/hue)
- [hiveserver2](https://hub.docker.com/r/bde2020/hive/)
- [zar3bski/hadoop-sandbox](https://github.com/zar3bski/hadoop-sandbox)

# Usefull ressources
[complete list of HDFS commands](https://hadoop.apache.org/docs/current/hadoop-project-dist/hadoop-common/FileSystemShell.html)
[Udemy Hadoop course](https://www.udemy.com/course/the-ultimate-hands-on-hadoop-tame-your-big-data/)

# Example usage
## Downloading some data and putting it into the HDFS
Go into the namenode and download some data
```
# Go into the namenode container
docker exec -it namenode bash

# Install some software utilities
apt-get install wget unzip

# Download some data into the hadoop-data directory
cd /hadoop-data
wget "http://files.grouplens.org/datasets/movielens/ml-100k.zip"

# Extract the zip file and remove redundant files
unzip ml-100k.zip
rm ml-100k.zip

# Create a directory in HDFS and print out where it is located
hadoop fs -mkdir -p playground # The -p is important!
hadoop fs -find / -name "playground" # Yields /user/root/playground

# Copy the data into HDFS and verify it worked
hadoop fs -copyFromLocal ml-100k playground/
hadoop fs -ls playground/ml-100k
```

Now, browse the HDFS file system from the [UI of the namenode](http://localhost:9870/explorer.html#/user/root/playground/ml-100k)
and convince yourself that the data is really there!

## Load some data into HIVE
To loading some data from HDFS into HIVE, open the [UI of hue](http://localhost:8000/),
open up a new HiveQL query console and execute the commands shown in
`hue/queries/load_ratings_into_hive.sql` or `hue/queries/load_names_into_hive.sql`

## Simple Pyspark app
To view a simple app that uses pyspark to connect to our spark cluster, parses some data,
converts that data into a dataframe and then executes a simple aggregation on it, please
view the notebook `jupyter-spark/work/tests/movie_dataframe.ipynb`

## Simple RSpark app
First, download the drivers from [here](https://www.progress.com/jdbc/apache-hadoop-hive), unzip all
files in it and then copy the files into `jupyter-spark/drivers/`.