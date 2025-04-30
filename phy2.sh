#!/bin/bash

install_dependencies() {
    local package_manager=$1
    local packages=(
        curl sudo openssl qrencode net-tools procps iptables ca-certificates python3 python3-pip
    )

    echo "Устанавливаю зависимости с использованием $package_manager..."
    if [ "$package_manager" == "apt" ]; then
        apt update && apt install -y "${packages[@]}"
    elif [ "$package_manager" == "dnf" ]; then
        dnf install -y epel-release  # Сначала устанавливаем epel-release
        dnf install -y "${packages[@]}"  # Затем устанавливаем остальные пакеты
    fi

    # Устанавливаем Python модули, чтобы pip имел права
    python3 -m pip install -q --user requests
}

check_linux_system() {
    # Чтение информации о системе (исправление пути)
    local os_info=$(grep -i '^id=' /etc/os-release | cut -d= -f2- | tr -d '"')

    case $os_info in
        ubuntu|debian)
            install_dependencies "apt"
            ;;
        rocky|centos|fedora)
            install_dependencies "dnf"
            ;;
        *)
            echo -e "\033[31mНеподдерживаемая версия Linux\033[0m"
            exit 1
            ;;
    esac
}

# Вызов основной функции
check_linux_system
