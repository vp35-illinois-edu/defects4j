FROM ubuntu:20.04

MAINTAINER ngocpq <phungquangngoc@gmail.com>

#############################################################################
# Requirements
#############################################################################

RUN \
  apt-get update -y && \
  apt-get install software-properties-common -y && \
  apt-get update -y && \
  apt-get install -y openjdk-8-jdk \
  git \
  build-essential \
  subversion \
  perl \
  curl \
  unzip \
  cpanminus \
  make \
  bc \
  && \
  rm -rf /var/lib/apt/lists/*

RUN ARCH=$(uname -m) && \
  if [ "$ARCH" = "amd64" ] || [ "$ARCH" = "x86_64" ]; then \
  export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64; \
  elif [ "$ARCH" = "arm64" ] || [ "$ARCH" = "aarch64" ]; then \
  export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-arm64; \
  else \
  echo "Unsupported architecture: $ARCH"; \
  exit 1; \
  fi && \
  echo "JAVA_HOME is set to $JAVA_HOME"

# Java version
ENV JAVA_HOME $JAVA_HOME

# Timezone
ENV TZ=America/Los_Angeles
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone


#############################################################################
# Setup Defects4J
#############################################################################

# ----------- Step 1. Clone defects4j from github --------------
WORKDIR /
RUN git clone https://github.com/rjust/defects4j.git defects4j

# ----------- Step 2. Initialize Defects4J ---------------------
WORKDIR /defects4j
RUN cpanm --installdeps .
RUN ./init.sh

# ----------- Step 3. Add Defects4J's executables to PATH: ------
ENV PATH="/defects4j/framework/bin:${PATH}"  
#--------------
