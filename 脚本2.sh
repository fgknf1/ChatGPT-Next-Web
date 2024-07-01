#!/usr/bin/env bash

clear

echo -e "\e[36m
   ▄▄▄▄       ██                         ▄▄▄▄                                   
  ██▀▀██      ▀▀                         ▀▀██                                   
 ██    ██   ████     ██▄████▄   ▄███▄██    ██       ▄████▄   ██▄████▄   ▄███▄██ 
 ██    ██     ██     ██▀   ██  ██▀  ▀██    ██      ██▀  ▀██  ██▀   ██  ██▀  ▀██ 
 ██    ██     ██     ██    ██  ██    ██    ██      ██    ██  ██    ██  ██    ██ 
  ██▄▄██▀  ▄▄▄██▄▄▄  ██    ██  ▀██▄▄███    ██▄▄▄   ▀██▄▄██▀  ██    ██  ▀██▄▄███ 
   ▀▀▀██   ▀▀▀▀▀▀▀▀  ▀▀    ▀▀   ▄▀▀▀ ██     ▀▀▀▀     ▀▀▀▀    ▀▀    ▀▀   ▄▀▀▀ ██ 
       ▀                        ▀████▀▀                                 ▀████▀▀
\e[0m\n"

DOCKER_IMG_NAME="whyour/qinglong"
QL_PATH=""
SHELL_FOLDER=$(pwd)
CONTAINER_NAME=""
TAG="latest"
NETWORK="bridge"
QL_PORT=5700

HAS_IMAGE=false
PULL_IMAGE=true
HAS_CONTAINER=false
DEL_CONTAINER=true
INSTALL_WATCH=false
ENABLE_HANGUP=true
ENABLE_WEB_PANEL=true
OLD_IMAGE_ID=""

log() {
    echo -e "\e[32m\n$1 \e[0m\n"
}

inp() {
    echo -e "\e[33m\n$1 \e[0m\n"
}

opt() {
    echo -n -e "\e[36m输入您的选择->\e[0m"
}

warn() {
    echo -e "\e[31m$1 \e[0m\n"
}

cancelrun() {
    if [ $# -gt 0 ]; then
        echo -e "\e[31m $1 \e[0m"
    fi
    exit 1
}

docker_install() {
    echo "检测 Docker......"
    if [ -x "$(command -v docker)" ]; then
        echo "检测到 Docker 已安装!"
    else
        if [ -r /etc/os-release ]; then
            . /etc/os-release
            lsb_dist="$ID"
        fi
        if [ "$lsb_dist" == "openwrt" ]; then
            echo "openwrt 环境请自行安装 docker"
            exit 1
        else
            echo "安装 Docker 环境..."
            curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun
            echo "安装 Docker 环境完成!"
            systemctl enable docker
            systemctl start docker
        fi
    fi
}

docker_install
warn "降低学习成本，小白回车到底，一路默认选择"

# 配置文件保存目录
echo -n -e "\e[33m一、请输入配置文件保存的绝对路径（示例：/root/ql1)，回车默认为 当前目录/ql:\e[0m"
read -r ql_path
if [ -z "$ql_path" ]; then
    mkdir -p "$SHELL_FOLDER"/ql
    QL_PATH=$SHELL_FOLDER/ql
elif [ -d "$ql_path" ]; then
    QL_PATH=$ql_path
else
    mkdir -p "$ql_path"
    QL_PATH=$ql_path
fi

# 检测镜像是否存在
if [ -n "$(docker images -q $DOCKER_IMG_NAME:$TAG 2>/dev/null)" ]; then
    HAS_IMAGE=true
    OLD_IMAGE_ID=$(docker images -q --filter reference=$DOCKER_IMG_NAME:$TAG)
    inp "检测到先前已经存在的镜像，是否拉取最新的镜像：\n1) 拉取[默认]\n2) 不拉取"
    opt
    read -r update
    if [ "$update" = "2" ]; then
        PULL_IMAGE=false
    fi
fi

# 检测容器是否存在
check_container_name() {
    if docker ps -a | grep "$CONTAINER_NAME" 2>/dev/null; then
        HAS_CONTAINER=true
        inp "检测到先前已经存在的容器，是否删除先前的容器：\n1) 删除[默认]\n2) 不删除"
        opt
        read -r update
        if [ "$update" = "2" ]; then
            DEL_CONTAINER=false
            inp "您选择了不删除之前的容器，需要重新输入容器名称"
            input_container_name
        fi
    fi
}

# 容器名称
input_container_name() {
    echo -n -e "\e[33m\n二、请输入要创建的 Docker 容器名称[默认为：qinglong]->\e[0m"
    read -r container_name
    if [ -z "$container_name" ];then
        CONTAINER_NAME="qinglong"
    else
        CONTAINER_NAME=$container_name
    fi
    check_container_name
}
input_container_name

# 是否安装 WatchTower
inp "是否安装 containrrr/watchtower 自动更新 Docker 容器：\n1) 安装\n2) 不安装[默认]"
opt
read -r watchtower
if [ "$watchtower" = "1" ]; then
    INSTALL_WATCH=true
fi

inp "请选择容器的网络类型：\n1) host\n2) bridge[默认]"
opt
read -r net
if [ "$net" = "1" ]; then
    NETWORK="host"
fi

inp "是否在启动容器时自动启动挂机程序：\n1) 开启[默认]\n2) 关闭"
opt
read -r hang_s
if [ "$hang_s" = "2" ]; then
    ENABLE_HANGUP=false
fi

inp "是否启用青龙面板：\n1) 启用[默认]\n2) 不启用"
opt
read -r panel
if [ "$panel" = "2" ]; then
    ENABLE_WEB_PANEL=false
fi

# 端口问题
modify_ql_port() {
    inp "是否修改青龙端口[默认 5700]：\n1) 修改\n2) 不修改[默认]"
    opt
    read -r change_ql_port
    if [ "$change_ql_port" = "1" ]; then
        echo -n -e "\e[36m输入您想修改的端口->\e[0m"
        read -r QL_PORT
    fi
}

if [ "$NETWORK" = "bridge" ]; then
    inp "是否映射端口：\n1) 映射[默认]\n2) 不映射"
    opt
    read -r port
    if [ "$port" = "2" ];then
        MAPPING_QL_PORT=""
    else
        while check_port "$QL_PORT"; do
            echo -n -e "\e[31m端口:$QL_PORT 被占用，请重新输入青龙面板端口：\e[0m"
            read -r QL_PORT
        done
        echo -e "\e[34m恭喜，端口:$QL_PORT 可用\e[0m"
        MAPPING_QL_PORT="-p $QL_PORT:5700"
    fi
fi

# 删除旧容器
if [ "$HAS_CONTAINER" = true ] && [ "$DEL_CONTAINER" = true ]; then
    log "删除先前的容器"
    docker stop "$CONTAINER_NAME" >/dev/null
    docker rm "$CONTAINER_NAME" >/dev/null
fi

# 删除旧镜像
if [ "$HAS_IMAGE" = true ] && [ "$PULL_IMAGE" = true ]; then
    if [ -n "$OLD_IMAGE_ID" ] && [ "$HAS_CONTAINER" = true ] && [ "$DEL_CONTAINER" = true ]; then
        log "删除旧的镜像"
        docker image rm "$OLD_IMAGE_ID"
    fi
    log "开始拉取最新的镜像"
    docker pull "$DOCKER_IMG_NAME:$TAG"
    if [ $? -ne 0 ]; then
        cancelrun "** 错误：拉取不到镜像！"
    fi
fi

log "开始创建容器并执行"
docker run -dit \
    -t \
    -v "$QL_PATH":/ql/data \
    $MAPPING_QL_PORT \
    --name "$CONTAINER_NAME" \
    --hostname qinglong \
    --restart always \
    --network $NETWORK \
    --env ENABLE_HANGUP="$ENABLE_HANGUP" \
    --env ENABLE_WEB_PANEL="$ENABLE_WEB_PANEL" \
    "$DOCKER_IMG_NAME:$TAG"

if [ $? -ne 0 ]; then
    cancelrun "** 错误：容器创建失败，请翻译以上英文报错，Google/百度尝试解决问题！"
fi

if [ "$INSTALL_WATCH" = true ]; then
    log "开始