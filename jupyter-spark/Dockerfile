FROM jupyter/all-spark-notebook:584f43f06586

ARG SPARK_VERSION
ARG HADOOP_VERSION
ARG SPARK_CHECKSUM
ARG OPENJDK_VERSION
ARG PYTHON_VERSION

# Install a different version of python inside the base environment
RUN conda install -y python=$PYTHON_VERSION

# Install required pip packages, e.g. pyspark
COPY requirements.txt /docker_build/requirements.txt
RUN pip install -r /docker_build/requirements.txt

# Install additional R packages
RUN conda install -y -c r r-rjdbc
RUN conda install -y -c conda-forge r-corrplot
