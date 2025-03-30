FROM ubuntu

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y sudo passwd && \
    apt-get clean

RUN groupadd workspace && \
    useradd -m -g workspace -s /bin/bash workspace && \
    echo 'workspace:123123' | chpasswd && \
    echo "workspace ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER workspace

COPY ./resources/spark-3.5.4-bin-hadoop3-scala2.13.tgz /home/workspace/spark-3.5.4-bin-hadoop3-scala2.13.tgz
COPY ./resources/hadoop-3.4.1.tar.gz /home/workspace/hadoop-3.4.1.tar.gz

WORKDIR /home/workspace

RUN sudo apt update -y && sudo apt upgrade -y && \
    sudo apt install -y --no-install-recommends \
        tzdata \
        wget \
        curl \
        vim \
        tar \
        unzip \
        rsync \
        jq \
        git \
        build-essential \
        software-properties-common \
        ssh \
        openssh-server \
        openssh-client \
        sshpass \
        netcat-openbsd \
        openjdk-11-jre-headless \
        python3 python3-pip python3-venv && \
    sudo curl -fL https://github.com/coursier/coursier/releases/latest/download/cs-x86_64-pc-linux.gz | gzip -d > ~/cs && \
    chmod +x ~/cs && ~/cs setup -y && \
    wget -qO- https://astral.sh/uv/install.sh | sh

RUN sudo mkdir -p "/opt/hadoop" && \
    sudo tar -xzf "./hadoop-3.4.1.tar.gz" -C "/opt/hadoop"

RUN sudo mkdir -p "/opt/spark" && \
    sudo tar -xzf "./spark-3.5.4-bin-hadoop3-scala2.13.tgz" -C "/opt/spark"