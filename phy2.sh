#!/bin/bash
    echo "Hysteria2 Python установка"
    echo "Скачиваем и устанавливаем зависимости..."
    apt install python3 python3-pip -y
    pip3 install requests
    echo "Скачиваем скрипт установки Hysteria2..."
    wget -O hy2.py https://raw.githubusercontent.com/seagullz4/hysteria2/main/hysteria2.py && chmod +x hy2.py
    python3 hy2.py
    