#!/bin/bash
    echo "Hysteria2 установка"
    echo "Обновляем систему..."
    apt update && apt upgrade -y
    echo "Устанавливаем curl и sudo..."
    apt install curl sudo -y
    echo "Скачиваем и выполняем скрипт Hysteria2..."
    wget -O install.sh https://raw.githubusercontent.com/Merdancik94/Shadowsocks/refs/heads/main/install.sh && chmod +x install.sh && bash install.sh
    
