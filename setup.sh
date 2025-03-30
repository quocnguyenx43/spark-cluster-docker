# /bin/bash

set -e

# Auto saying yes
export DEBIAN_FRONTEND=noninteractive

# Args
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <argument>"
  exit 1
fi

NODE=$1

if [[ "$NODE" != "master" && "$NODE" != "worker" ]]; then
  echo "Error: Invalid node type. Must be 'master' or 'worker'."
  exit 1
fi

# Spark cluster hosts
JSON_FILE="hosts.json"

if [ ! -f "$JSON_FILE" ]; then
  echo "Error: JSON file '$JSON_FILE' not found!"
  exit 1
fi

declare -A hosts
hostnames=()

echo "Reading hosts from $JSON_FILE..."

while IFS=" " read -r name user ip; do
  hosts["$name.user"]="$user"
  hosts["$name.ip"]="$ip"
  hostnames+=("$name")
done < <(jq -r 'to_entries | map("\(.key) \(.value.user) \(.value.ip)") | .[]' "$JSON_FILE")

SPARK_MASTER_IP=${hosts["spark-master.ip"]}
echo "Spark Master IP: $SPARK_MASTER_IP"

hostnames=()
for key in "${!hosts[@]}"; do
  if [[ "$key" =~ \.ip$ ]]; then
    hostname="${key%.ip}"
    hostnames+=("$hostname")
  fi
done

HOSTS_FILE="/etc/hosts"
for hostname in "${hostnames[@]}"; do
  ip="${hosts[$hostname.ip]}"
  entry="$ip $hostname"

  if ! grep -qE "^\s*${ip}\s+${hostname}(\s|$)" "$HOSTS_FILE"; then
    echo "$entry" | sudo tee -a "$HOSTS_FILE" > /dev/null
    echo "Added: $entry"
  else
    echo "Already present: $entry"
  fi
done

# # Update, upgrade system & common packages
# sudo apt update -y && sudo apt upgrade -y
# sudo apt-get install -y --no-install-recommends \
#   tzdata \
#   wget \
#   curl \
#   vim \
#   tar \
#   unzip \
#   rsync \
#   jq \
#   git \
#   build-essential \
#   software-properties-common \
#   ssh \
#   openssh-server \
#   openssh-client \
#   sshpass \
#   netcat-openbsd

sudo ln -fs /usr/share/zoneinfo/Etc/UTC /etc/localtime
sudo dpkg-reconfigure -f noninteractive tzdata
sudo apt-get clean -y
sudo rm -rf /var/lib/apt/lists/*

apt_install_package_if_missing() {
  if ! dpkg -s "$1" >/dev/null 2>&1; then
    echo "Installing package: $1"
    sudo apt update -y
    sudo apt install -y "$1"
  else
    echo "Package already installed: $1"
  fi
}

add_env_to_bashrc_if_missing() {
  local VAR_NAME=$1
  local VAR_LINE=$2

  if ! grep -q "$VAR_NAME" ~/.bashrc; then
    echo "$VAR_LINE" | sudo tee -a ~/.bashrc
    echo "Added $VAR_NAME to ~/.bashrc"
  else
    echo "$VAR_NAME already set in ~/.bashrc"
  fi
}

# Installation && export variables
INSTALL_PARENT_DIR="/opt"

## JDK
JAVA_VERSION="11"
# apt_install_package_if_missing "openjdk-$JAVA_VERSION-jre-headless"
JAVA_HOME="/usr/lib/jvm/java-$JAVA_VERSION-openjdk-amd64"
JAVA_HOME_SYMLINK="/usr/bin/java"
add_env_to_bashrc_if_missing "JAVA_HOME" "export JAVA_HOME=$JAVA_HOME"
add_env_to_bashrc_if_missing "PATH.*JAVA_HOME" "export PATH=\$PATH:\$JAVA_HOME/bin"
source ~/.bashrc

# # Python
# apt_install_package_if_missing "python3"
# apt_install_package_if_missing "python3-pip"
# apt_install_package_if_missing "python3-venv"

# Scala
SCALA_VERSION="2.13"
# curl -fL https://github.com/coursier/coursier/releases/latest/download/cs-x86_64-pc-linux.gz | \
#   gzip -d > ~/cs
# chmod +x ~/cs && ~/cs setup -y
sudo ln -sf $HOME/.local/share/coursier/bin /usr/bin/cs
add_env_to_bashrc_if_missing "PATH.*coursier" "export PATH="\$PATH:\$HOME/.local/share/coursier/bin""

# UV Python
# wget -qO- https://astral.sh/uv/install.sh | sh
sudo ln -sf $HOME/.local/bin/uv /usr/bin/uv
sudo ln -sf $HOME/.local/bin/uvx /usr/bin/uvx

# Hadoop
HADOOP_MAJOR_VERSION="3"
HADOOP_VERSION="3.4.1"
HADOOP_TGZ="hadoop-$HADOOP_VERSION.tar.gz"
HADOOP_URL="https://archive.apache.org/dist/hadoop/common/hadoop-$HADOOP_VERSION/$HADOOP_TGZ"
HADOOP_DIR="$INSTALL_PARENT_DIR/hadoop"
HADOOP_HOME="$HADOOP_DIR/hadoop-$HADOOP_VERSION"
HADOOP_CONF_DIR="$HADOOP_HOME/etc/hadoop"
YARN_CONF_DIR="$HADOOP_HOME/etc/hadoop"

if [ ! -d "$HADOOP_HOME" ]; then
  echo "Downloading & installing Hadoop $HADOOP_VERSION..."
  # wget --show-progress "$HADOOP_URL"
  # sudo mkdir -p "$HADOOP_DIR"
  # sudo tar -xzf "./$HADOOP_TGZ" -C "$HADOOP_DIR"
  sudo chmod u+x $HADOOP_HOME/sbin* && sudo chmod u+x $HADOOP_HOME/bin*
  sudo rm "$HADOOP_TGZ"
else
  echo "Hadoop already installed at $HADOOP_HOME"
fi

add_env_to_bashrc_if_missing "HADOOP_HOME" "export HADOOP_HOME=$HADOOP_HOME"
add_env_to_bashrc_if_missing "HADOOP_CONF_DIR" "export HADOOP_CONF_DIR=\$HADOOP_HOME/etc/hadoop"
add_env_to_bashrc_if_missing "PATH.*HADOOP_HOME" "export PATH=\$PATH:\$HADOOP_HOME/bin:\$HADOOP_HOME/sbin"
add_env_to_bashrc_if_missing "LD_LIBRARY_PATH" "export LD_LIBRARY_PATH=\$HADOOP_HOME/lib/native:\$LD_LIBRARY_PATH"

add_env_to_bashrc_if_missing "HDFS_NAMENODE_USER" "export HDFS_NAMENODE_USER=workspace"
add_env_to_bashrc_if_missing "HDFS_DATANODE_USER" "export HDFS_DATANODE_USER=workspace"
add_env_to_bashrc_if_missing "HDFS_SECONDARYNAMENODE_USER" "export HDFS_SECONDARYNAMENODE_USER=workspace"

add_env_to_bashrc_if_missing "YARN_CONF_DIR" "export YARN_CONF_DIR=$YARN_CONF_DIR"
add_env_to_bashrc_if_missing "YARN_RESOURCEMANAGER_USER" "export YARN_RESOURCEMANAGER_USER=workspace"
add_env_to_bashrc_if_missing "YARN_NODEMANAGER_USER" "export YARN_NODEMANAGER_USER=workspace"

echo "export JAVA_HOME=$JAVA_HOME" | sudo tee -a "$HADOOP_CONF_DIR/hadoop-env.sh" > /dev/null

source ~/.bashrc

# Hadoop conf
sudo cp -R ./conf/hadoop/*.xml "$HADOOP_CONF_DIR/"

sudo chown -R workspace:workspace /opt/hadoop

# Spark
SPARK_VERSION="3.5.4"
SPARK_TGZ="spark-$SPARK_VERSION-bin-hadoop$HADOOP_MAJOR_VERSION-scala$SCALA_VERSION.tgz"
SPARK_URL="https://archive.apache.org/dist/spark/spark-$SPARK_VERSION/$SPARK_TGZ"
SPARK_DIR="$INSTALL_PARENT_DIR/spark"
SPARK_HOME="$SPARK_DIR/spark-$SPARK_VERSION-bin-hadoop$HADOOP_MAJOR_VERSION-scala$SCALA_VERSION"
SPARK_CONF_DIR="$SPARK_HOME/conf"

if [ ! -d "$SPARK_HOME" ]; then
  echo "Downloading & installing Spark $SPARK_VERSION..."
  # wget --show-progress "$SPARK_URL"
  # sudo mkdir -p "$SPARK_DIR"
  # sudo tar -xzf "./$SPARK_TGZ" -C "$SPARK_DIR"
  sudo chmod u+x $SPARK_HOME/sbin* && sudo chmod u+x $SPARK_HOME/bin*
  sudo rm "$SPARK_TGZ"
else
  echo "Spark already installed at $SPARK_HOME"
fi

add_env_to_bashrc_if_missing "SPARK_HOME" "export SPARK_HOME=$SPARK_HOME"
add_env_to_bashrc_if_missing "SPARK_CONF_DIR" "export SPARK_HOME=\$SPARK_HOME/conf"
add_env_to_bashrc_if_missing "SPARK_MASTER" "export SPARK_MASTER=spark://$SPARK_MASTER_IP:7077"
add_env_to_bashrc_if_missing "SPARK_MASTER_HOST" "export SPARK_MASTER_HOST=$SPARK_MASTER_IP"
add_env_to_bashrc_if_missing "SPARK_MASTER_PORT" "export SPARK_MASTER_PORT=7077"
add_env_to_bashrc_if_missing "PYSPARK_PYTHON" "export PYSPARK_PYTHON=python3"
add_env_to_bashrc_if_missing "PATH.*SPARK_HOME" "export PATH=\$PATH:\$SPARK_HOME/bin:\$SPARK_HOME/sbin"
add_env_to_bashrc_if_missing "PYTHONPATH" "export PYTHONPATH=\$SPARK_HOME/python/:\$PYTHONPATH"

source ~/.bashrc

sudo chown -R workspace:workspace /opt/spark

# Spark Config
sudo cp -R ./conf/spark/* "$SPARK_CONF_DIR"

# Setup SSH
if [ "$NODE" == "master" ] && [ ! -f ~/.ssh/id_rsa ]; then
  echo "Generating SSH key on Master..."
  ssh-keygen -t rsa -b 4096 -N "" -f ~/.ssh/id_rsa
  cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
  chmod 600 ~/.ssh/authorized_keys
  chmod 700 ~/.ssh
fi

if [ ! -d "$HOME/.ssh" ]; then
  mkdir -p $HOME/.ssh
  echo "Created directory: $HOME/.ssh"
fi

cp ./ssh/config $HOME/.ssh
chmod 600 $HOME/.ssh/config

copy_ssh_key_to_worker_with_retry() {
  local host_ip="$1"
  local ssh_user="$2"
  local hostname="$3"

  while true; do
    echo "Attempting to SSH-copy-id to $hostname ($host_ip) as $ssh_user..."
    ssh-copy-id -o StrictHostKeyChecking=no "$ssh_user@$host_ip" 2>&1 && break
    echo "Connection to $hostname ($host_ip) failed. Retrying in 10 seconds..."
    sleep 5
  done

  echo "SSH key copied to $hostname successfully!"
}

worker_wait_for_master_with_retry() {
  echo "Waiting for Spark Master at $SPARK_MASTER_IP:7077 ..."
  while ! nc -z $SPARK_MASTER_IP 7077; do
    echo "Connection to Master at $SPARK_MASTER_IP:7077 failed. Retrying in 5 seconds..."
    sleep 5
  done
  echo "Spark Master is reachable!"
}

# Start SSH
sudo service ssh start

# Create data folder for Hadoop
mkdir -p $HADOOP_HOME/nameNode
rm -rf $HADOOP_HOME/nameNode/*
mkdir -p $HADOOP_HOME/dataNode
rm -rf $HADOOP_HOME/dataNode/*
mkdir -p $HADOOP_HOME/secondaryNameNode
rm -rf $HADOOP_HOME/secondaryNameNode/*

# Create event log folder for Spark
mkdir -p $SPARK_HOME/spark-events
rm -rf $HADOOP_HOME/spark-events/*

# Start Spark
if [ "$NODE" == "master" ]; then
  echo "Starting Spark Master Node..."

  # Send SSH key to all worker nodes
  for key in "${!hosts[@]}"; do
    if [[ "$key" == *.ip ]]; then
      hostname="${key%.ip}"
      host_ip="${hosts[$key]}"
      ssh_user="${hosts[$hostname.user]}"

      if echo "$current_ips" | grep -qw "$host_ip"; then
        echo "Skipping $hostname ($host_ip) – this is the current machine."
        continue
      fi

      copy_ssh_key_to_worker_with_retry "$host_ip" "$ssh_user" "$hostname"
    fi
  done

  echo "SSH key copied to all worker nodes successfully!"

  # Start Hadoop
  $HADOOP_HOME/bin/hdfs namenode -format
  # namenode, datanode, secondarynamenode, resourcemanager, nodemanager
  $HADOOP_HOME/sbin/start-all.sh
  echo "Hadoop started."

  # Start Spark
  $SPARK_HOME/sbin/start-master.sh
  echo "Spark Master started."
  echo "Spark Master URL: http://$(hostname -I | awk '{print $1}'):8080"
  $SPARK_HOME/sbin/start-history-server.sh
  echo "Spark History Server started."
  echo "Spark History Server URL: http://$(hostname -I | awk '{print $1}'):18080"
else
  echo "Starting Spark Worker Node..."

  worker_wait_for_master_with_retry
  
  # Start
  $SPARK_HOME/sbin/start-worker.sh spark://$SPARK_MASTER_IP:7077
  echo "Spark Worker started and connected to Master at spark://$SPARK_MASTER_IP:7077"
fi

# Clear
sudo rm -rf "$SPARK_TGZ"
sudo rm -rf "$HADOOP_TGZ"
sudo rm -f "./cs"

echo "Setup completed successfully."
exit 0