#!/bin/bash
# Проверка, является ли текущий пользователь root
if [ "$EUID" -ne 0 ]; then
  echo "Пожалуйста, выполните этот скрипт от имени root!"
  echo "Вы можете использовать команду 'sudo -i' для входа в режим root."
  exit 1
fi

# Функция проверки системы
check_sys() {
  if [[ -f /etc/redhat-release ]]; then
    release="centos"
  elif grep -qi "debian" /etc/issue; then
    release="debian"
  elif grep -qi "ubuntu" /etc/issue; then
    release="ubuntu"
  elif grep -qi -E "centos|red hat|redhat|rocky" /etc/issue || grep -qi -E "centos|red hat|redhat|rocky" /proc/version; then
    release="centos"
  fi

  if [[ -f /etc/debian_version ]]; then
    OS_type="Debian"
    echo "Обнаружена система Debian, сообщите об ошибке, если определение неверно"
  elif [[ -f /etc/redhat-release || -f /etc/centos-release || -f /etc/fedora-release || -f /etc/rocky-release ]]; then
    OS_type="CentOS"
    echo "Обнаружена система CentOS, сообщите об ошибке, если определение неверно"
  else
    echo "Неизвестная система"
  fi
}

# Функция проверки существования команды
_exists() {
    local cmd="$1"
    if eval type type >/dev/null 2>&1; then
      eval type "$cmd" >/dev/null 2>&1
    elif command >/dev/null 2>&1; then
      command -v "$cmd" >/dev/null 2>&1
    else
      which "$cmd" >/dev/null 2>&1
    fi
    local rt=$?
    return ${rt}
}

# Функция для вывода цветного текста
random_color() {
  colors=("31" "32" "33" "34" "35" "36" "37")
  echo -e "\e[${colors[$((RANDOM % 7))]}m$1\e[0m"
}

# Определение типа ОС
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_TYPE=$ID
    OS_VERSION=$VERSION_ID
else
    echo "Не удалось определить тип операционной системы."
    exit 1
fi

# Установка необходимых пакетов
install_custom_packages() {
    if [ "$OS_TYPE" = "debian" ] || [ "$OS_TYPE" = "ubuntu" ]; then
        apt update
        apt install -y wget sed sudo openssl net-tools psmisc procps iptables iproute2 ca-certificates jq
    elif [ "$OS_TYPE" = "centos" ] || [ "$OS_TYPE" = "rhel" ] || [ "$OS_TYPE" = "fedora" ] || [ "$OS_TYPE" = "rocky" ]; then
        yum install -y epel-release
        yum install -y wget sed sudo openssl net-tools psmisc procps-ng iptables iproute ca-certificates jq
    else
        echo "Неподдерживаемая операционная система."
        exit 1
    fi
}

install_custom_packages

echo "Установленные пакеты:"
for pkg in wget sed openssl iptables jq; do
    if command -v $pkg >/dev/null 2>&1; then
        echo "$pkg установлен"
    else
        echo "$pkg не установлен"
    fi
done

echo "Все указанные пакеты успешно установлены."

# Определение архитектуры системы
set_architecture() {
  case "$(uname -m)" in
    'i386' | 'i686')
      arch='386'
      ;;
    'amd64' | 'x86_64')
      arch='amd64'
      ;;
    'armv5tel' | 'armv6l' | 'armv7' | 'armv7l')
      arch='arm'
      ;;
    'armv8' | 'aarch64')
      arch='arm64'
      ;;
    'mips' | 'mipsle' | 'mips64' | 'mips64le')
      arch='mipsle'
      ;;
    's390x')
      arch='s390x'
      ;;
    *)
      echo "Ваша система временно не поддерживается, возможно, из-за неизвестной архитектуры."
      exit 1
      ;;
  esac
}

# Получение установленной версии Hysteria
get_installed_version() {
    if [ -x "/root/hy3/hysteria-linux-$arch" ]; then
        version="$("/root/hy3/hysteria-linux-$arch" version | grep Version | grep -o 'v[.0-9]*')"
    else
        version="Еще не установлено, старина"
    fi
}

# Получение последней версии Hysteria
get_latest_version() {
  local tmpfile
  tmpfile=$(mktemp)

  if ! curl -sS "https://api.hy2.io/v1/update?cver=installscript&plat=linux&arch="$arch"&chan=release&side=server" -o "$tmpfile"; then
    error "Не удалось получить последнюю версию из API Hysteria 2, проверьте ваше соединение и попробуйте снова."
    exit 11
  fi

  local latest_version
  latest_version=$(grep -oP '"lver":\s*\K"v.*?"' "$tmpfile" | head -1)
  latest_version=${latest_version#'"'}
  latest_version=${latest_version%'"'}

  if [[ -n "$latest_version" ]]; then
    echo "$latest_version"
  fi

  rm -f "$tmpfile"
}

# Проверка состояния Hysteria
checkact() {
pid=$(pgrep -f "hysteria-linux-$arch")

if [ -n "$pid" ]; then
  hy2zt="работает"
else
  hy2zt="не работает"
fi
}

# Настройка GRUB для BBR
BBR_grub() {
  if [[ "${OS_type}" == "CentOS" ]]; then
    if [[ ${version} == "6" ]]; then
      if [ -f "/boot/grub/grub.conf" ]; then
        sed -i 's/^default=.*/default=0/g' /boot/grub/grub.conf
      elif [ -f "/boot/grub/grub.cfg" ]; then
        grub-mkconfig -o /boot/grub/grub.cfg
        grub-set-default 0
      elif [ -f "/boot/efi/EFI/centos/grub.cfg" ]; then
        grub-mkconfig -o /boot/efi/EFI/centos/grub.cfg
        grub-set-default 0
      elif [ -f "/boot/efi/EFI/redhat/grub.cfg" ]; then
        grub-mkconfig -o /boot/efi/EFI/redhat/grub.cfg
        grub-set-default 0
      else
        echo -e "${Error} Не удалось найти grub.conf/grub.cfg, проверьте."
        exit
      fi
    elif [[ ${version} == "7" ]]; then
      if [ -f "/boot/grub2/grub.cfg" ]; then
        grub2-mkconfig -o /boot/grub2/grub.cfg
        grub2-set-default 0
      elif [ -f "/boot/efi/EFI/centos/grub.cfg" ]; then
        grub2-mkconfig -o /boot/efi/EFI/centos/grub.cfg
        grub2-set-default 0
      elif [ -f "/boot/efi/EFI/redhat/grub.cfg" ]; then
        grub2-mkconfig -o /boot/efi/EFI/redhat/grub.cfg
        grub2-set-default 0
      else
        echo -e "${Error} Не удалось найти grub.cfg, проверьте."
        exit
      fi
    elif [[ ${version} == "8" ]]; then
      if [ -f "/boot/grub2/grub.cfg" ]; then
        grub2-mkconfig -o /boot/grub2/grub.cfg
        grub2-set-default 0
      elif [ -f "/boot/efi/EFI/centos/grub.cfg" ]; then
        grub2-mkconfig -o /boot/efi/EFI/centos/grub.cfg
        grub2-set-default 0
      elif [ -f "/boot/efi/EFI/redhat/grub.cfg" ]; then
        grub2-mkconfig -o /boot/efi/EFI/redhat/grub.cfg
        grub2-set-default 0
      else
        echo -e "${Error} Не удалось найти grub.cfg, проверьте."
        exit
      fi
      grubby --info=ALL | awk -F= '$1=="kernel" {print i++ " : " $2}'
    fi
  elif [[ "${OS_type}" == "Debian" ]]; then
    if _exists "update-grub"; then
      update-grub
    elif [ -f "/usr/sbin/update-grub" ]; then
      /usr/sbin/update-grub
    else
      apt install grub2-common -y
      update-grub
    fi
  fi
}

# Проверка версии системы
check_version() {
  if [[ -s /etc/redhat-release ]]; then
    version=$(grep -oE "[0-9.]+" /etc/redhat-release | cut -d . -f 1)
  else
    version=$(grep -oE "[0-9.]+" /etc/issue | cut -d . -f 1)
  fi
  bit=$(uname -m)
  check_github
}

# Установка ядра XanMod
installxanmod1 () {
# Проверка, является ли система Debian или Ubuntu
if [[ $(cat /etc/os-release) =~ ^(Debian|Ubuntu) ]]; then
  echo "OK"
else
  echo "Система не является Debian или Ubuntu"
  exit 1
fi

# Проверка архитектуры системы
if [[ $(uname -m) =~ ^(x86_64|amd64) ]]; then
  echo "Установка, пожалуйста подождите..."
else
  echo "Архитектура системы не x86/amd64, дружище, купи что-то получше"
  exit 1
fi

echo "Система соответствует требованиям, продолжение выполнения скрипта"
wget -qO - https://dl.xanmod.org/archive.key | sudo gpg --dearmor -o /usr/share/keyrings/xanmod-archive-keyring.gpg
echo 'deb [signed-by=/usr/share/keyrings/xanmod-archive-keyring.gpg] http://deb.xanmod.org releases main' | sudo tee /etc/apt/sources.list.d/xanmod-release.list
sudo apt update && sudo apt install linux-xanmod-x64v3
BBR_grub
echo -e "${Tip} Установка ядра завершена, проверьте успешность установки, по умолчанию загрузка с самого нового ядра"
echo "Установка завершена, пожалуйста перезагрузите систему"
}

installxanmod2 () {
  check_version
  wget -O check_x86-64_psabi.sh https://dl.xanmod.org/check_x86-64_psabi.sh
  chmod +x check_x86-64_psabi.sh
  cpu_level=$(./check_x86-64_psabi.sh | awk -F 'v' '{print $2}')
  echo -e "CPU поддерживает \033[32m${cpu_level}\033[0m"
  if [[ ${bit} != "x86_64" ]]; then
    echo -e "${Error} Поддерживаются только системы x86_64 !" && exit 1
  fi

  if [[ "${OS_type}" == "Debian" ]]; then
    apt update
    apt-get install gnupg gnupg2 gnupg1 sudo -y
    echo 'deb http://deb.xanmod.org releases main' | sudo tee /etc/apt/sources.list.d/xanmod-kernel.list
    wget -qO - https://dl.xanmod.org/gpg.key | sudo apt-key --keyring /etc/apt/trusted.gpg.d/xanmod-kernel.gpg add -
    if [[ "${cpu_level}" == "4" ]]; then
      apt update && apt install linux-xanmod-x64v4 -y
    elif [[ "${cpu_level}" == "3" ]]; then
      apt update && apt install linux-xanmod-x64v3 -y
    elif [[ "${cpu_level}" == "2" ]]; then
      apt update && apt install linux-xanmod-x64v2 -y
    else
      apt update && apt install linux-xanmod-x64v1 -y
    fi
  else
    echo -e "${Error} Текущая система ${release} ${version} ${bit} не поддерживается !" && exit 1
  fi

  BBR_grub
  echo -e "${Tip} Установка ядра завершена, проверьте успешность установки, по умолчанию загрузка с самого нового ядра, пожалуйста перезагрузите систему"
}

# Удаление ядер
detele_kernel() {
  if [[ "${OS_type}" == "CentOS" ]]; then
    rpm_total=$(rpm -qa | grep kernel | grep -v "${kernel_version}" | grep -v "noarch" | wc -l)
    if [ "${rpm_total}" ] >"1"; then
      echo -e "Обнаружено ${rpm_total} других ядер, начинаю удаление..."
      for ((integer = 1; integer <= ${rpm_total}; integer++)); do
        rpm_del=$(rpm -qa | grep kernel | grep -v "${kernel_version}" | grep -v "noarch" | head -${integer})
        echo -e "Начинаю удаление ${rpm_del} ядра..."
        rpm --nodeps -e ${rpm_del}
        echo -e "Удаление ${rpm_del} ядра завершено, продолжаю..."
      done
      echo --nodeps -e "Удаление ядер завершено, продолжаю..."
    else
      echo -e " Обнаружено неверное количество ядер, проверьте !" && exit 1
    fi
  elif [[ "${OS_type}" == "Debian" ]]; then
    deb_total=$(dpkg -l | grep linux-image | awk '{print $2}' | grep -v "${kernel_version}" | wc -l)
    if [ "${deb_total}" ] >"1"; then
      echo -e "Обнаружено ${deb_total} других ядер, начинаю удаление..."
      for ((integer = 1; integer <= ${deb_total}; integer++)); do
        deb_del=$(dpkg -l | grep linux-image | awk '{print $2}' | grep -v "${kernel_version}" | head -${integer})
        echo -e "Начинаю удаление ${deb_del} ядра..."
        apt-get purge -y ${deb_del}
        apt-get autoremove -y
        echo -e "Удаление ${deb_del} ядра завершено, продолжаю..."
      done
      echo -e "Удаление ядер завершено, продолжаю..."
    else
      echo -e " Обнаружено неверное количество ядер, проверьте !" && exit 1
    fi
  fi
}

# Удаление заголовков ядер
detele_kernel_head() {
  if [[ "${OS_type}" == "CentOS" ]]; then
    rpm_total=$(rpm -qa | grep kernel-headers | grep -v "${kernel_version}" | grep -v "noarch" | wc -l)
    if [ "${rpm_total}" ] >"1"; then
      echo -e "Обнаружено ${rpm_total} других заголовков ядер, начинаю удаление..."
      for ((integer = 1; integer <= ${rpm_total}; integer++)); do
        rpm_del=$(rpm -qa | grep kernel-headers | grep -v "${kernel_version}" | grep -v "noarch" | head -${integer})
        echo -e "Начинаю удаление ${rpm_del} заголовков ядра..."
        rpm --nodeps -e ${rpm_del}
        echo -e "Удаление ${rpm_del} заголовков ядра завершено, продолжаю..."
      done
      echo --nodeps -e "Удаление заголовков ядер завершено, продолжаю..."
    else
      echo -e " Обнаружено неверное количество заголовков ядер, проверьте !" && exit 1
    fi
  elif [[ "${OS_type}" == "Debian" ]]; then
    deb_total=$(dpkg -l | grep linux-headers | awk '{print $2}' | grep -v "${kernel_version}" | wc -l)
    if [ "${deb_total}" ] >"1"; then
      echo -e "Обнаружено ${deb_total} других заголовков ядер, начинаю удаление..."
      for ((integer = 1; integer <= ${deb_total}; integer++)); do
        deb_del=$(dpkg -l | grep linux-headers | awk '{print $2}' | grep -v "${kernel_version}" | head -${integer})
        echo -e "Начинаю удаление ${deb_del} заголовков ядра..."
        apt-get purge -y ${deb_del}
        apt-get autoremove -y
        echo -e "Удаление ${deb_del} заголовков ядра завершено, продолжаю..."
      done
      echo -e "Удаление заголовков ядер завершено, продолжаю..."
    else
      echo -e " Обнаружено неверное количество заголовков ядер, проверьте !" && exit 1
    fi
  fi
}

# Удаление пользовательских ядер
detele_kernel_custom() {
  BBR_grub
  read -p " Введите ключевое слово для ядра, которое нужно сохранить (например: 5.15.0-11) :" kernel_version
  detele_kernel
  detele_kernel_head
  BBR_grub
}

# Приветственное сообщение
welcome() {
echo -e "$(random_color '
░██  ░██
░██  ░██       ░████        ░█         ░█        ░█░█░█
░██  ░██     ░█      █      ░█         ░█        ░█    ░█
░██████     ░██████         ░█         ░█        ░█    ░█
░██  ░██     ░█             ░█ ░█      ░█  ░█     ░█░█░█
░██  ░██      ░██  █         ░█         ░█                   ')"
 echo -e "$(random_color '
В жизни есть две трагедии: первая - когда не получаешь того, чего хочешь, вторая - когда получаешь. ')"
}

echo -e "$(random_color 'Установка необходимых зависимостей......')"
install_missing_commands > /dev/null 2>&1
echo -e "$(random_color 'Зависимости успешно установлены')"

set_architecture

get_installed_version

latest_version=$(get_latest_version)

checkact

# Удаление Hysteria
uninstall_hysteria() {
sudo systemctl stop hysteria.service
sudo systemctl disable hysteria.service

if [ -f "/etc/systemd/system/hysteria.service" ]; then
  sudo rm "/etc/systemd/system/hysteria.service"
  echo "Файл службы Hysteria удален."
else
  echo "Файл службы Hysteria не существует."
fi

process_name="hysteria-linux-$arch"
pid=$(pgrep -f "$process_name")

if [ -n "$pid" ]; then
  echo "Найден процесс $process_name (PID: $pid), завершаю..."
  kill "$pid"
  echo "Процесс $process_name завершен."
else
  echo "Процесс $process_name не найден."
fi

if [ -f "/root/hy3/hysteria-linux-$arch" ]; then
  rm -f "/root/hy3/hysteria-linux-$arch"
  echo "Бинарный файл Hysteria удален."
else
  echo "Бинарный файл Hysteria не существует."
fi

if [ -f "/root/hy3/config.yaml" ]; then
  rm -f "/root/hy3/config.yaml"
  echo "Конфигурационный файл Hysteria удален."
else
  echo "Конфигурационный файл Hysteria не существует."
fi

rm -rf /root/hy3
systemctl stop ipppp.service
systemctl disable ipppp.service
rm -rf /etc/systemd/system/ipppp.service
rm -rf /bin/hy2
echo "Удаление завершено (ง ื▿ ื)ว."
}

# Установка быстрого запуска hy2
hy2easy() {
    rm -rf /usr/local/bin/hy2
    sudo wget -q hy2.crazyact.com -O /usr/local/bin/hy2
    sudo chmod +x /usr/local/bin/hy2
    echo "Добавлен быстрый запуск hy2"
}

hy2easy
welcome

# Меню выбора
echo "$(random_color 'Выберите действие, дружище (ง ื▿ ื)ว：')"
echo -e "$(random_color 'Введите hy2 для быстрого запуска скрипта')"
echo "1. Установка (мечтать не вредно)"
echo "2. Удаление (мыслями далеко)"
echo "$(random_color '>>>>>>>>>>>>>>>>>>>>')"
echo "3. Просмотр конфигурации (сквозь время)"
echo "4. Выход (назад в будущее)"
echo "$(random_color '>>>>>>>>>>>>>>>>>>>>')"
echo "5. Онлайн-обновление ядра hy2 (текущая версия: $version)"
echo "6. Управление ядром hy2"
echo "7. Установка ядра xanmod (лучшее использование сетевых ресурсов)"
echo "Последняя версия ядра hy2: $latest_version"
echo "$(random_color '>>>>>>>>>>>>>>>>>>>>')"
echo "Состояние hysteria2: $hy2zt"

read -p "Введите номер операции (1/2/3/4/5): " choice

case $choice in
   1)
     # Ничего не делаем
     ;;

   2)
uninstall_hysteria > /dev/null 2>&1
echo -e "$(random_color 'Не торопись, идет удаление......')"
echo -e "$(random_color 'Удаление завершено, старина ψ(｀∇´)ψ！')"
     exit
     ;;

   4)
     # Выход
     exit
     ;;

   3)
echo "$(random_color 'Информация о вашем узле nekobox:')"
echo "$(random_color '>>>>>>>>>>>>>>>>>>>>')"
echo "$(random_color '>>>>>>>>>>>>>>>>>>>>')"
cd /root/hy3/
cat /root/hy3/neko.txt
echo "$(random_color '>>>>>>>>>>>>>>>>>>>>')"
echo "$(random_color '>>>>>>>>>>>>>>>>>>>>')"
echo "$(random_color 'Ваша конфигурация clashmate:')"
cat /root/hy3/clash-mate.yaml
echo "$(random_color '>>>>>>>>>>>>>>>>>>>>')"
     exit
     ;;
    
   5)
get_updated_version() {
    if [ -x "/root/hy3/hysteria-linux-$arch" ]; then
        version2="$("/root/hy3/hysteria-linux-$arch" version | grep Version | grep -o 'v[.0-9]*')"
    else
        version2="Еще не установлено, старина"
    fi
}

updatehy2 () {
process_name="hysteria-linux-$arch"
pid=$(pgrep -f "$process_name")

if [ -n "$pid" ]; then
  echo "Найден процесс $process_name (PID: $pid), завершаю..."
  kill "$pid"
  echo "Процесс $process_name завершен."
else
  echo "Процесс $process_name не найден."
fi

cd /root/hy3
rm -r hysteria-linux-$arch

if wget -O hysteria-linux-$arch https://download.hysteria.network/app/latest/hysteria-linux-$arch; then
  chmod +x hysteria-linux-$arch
else
  if wget -O hysteria-linux-$arch https://github.com/apernet/hysteria/releases/download/app/$latest_version/hysteria-linux-$arch; then
    chmod +x hysteria-linux-$arch
  else
    echo "Не удалось загрузить файл"
    exit 1
  fi
fi

systemctl stop hysteria.service
systemctl start hysteria.service

echo "Обновление завершено, дружище, присядь-ка (ง ื▿ ื)ว."
}
echo "$(random_color 'Идет обновление, не торопись, старина')"
sleep 1
updatehy2 > /dev/null 2>&1
echo "$(random_color 'Обновление завершено, старина')"
get_updated_version
echo "Текущая версия после обновления: $version2"
      exit
      ;;

    6)
echo "Введите 1 для запуска ядра hy2, 2 для остановки, 3 для перезапуска"
read choicehy2
if [ "$choicehy2" = "1" ]; then
sudo systemctl start hysteria.service
echo "Ядро hy2 успешно запущено"
elif [ "$choicehy2" = "2" ]; then
sudo systemctl stop hysteria.service
echo "Ядро hy2 успешно остановлено"
elif [ "$choicehy2" = "3" ]; then
sudo systemctl restart hysteria.service
echo "Ядро hy2 успешно перезапущено"
else
  echo "Пожалуйста, введите правильный вариант"
fi
      exit
      ;;

   7)
echo "Введите y для установки, n для отмены, o для удаления (y/n/o)"
read answer
if [ "$answer" = "y" ]; then
check_sys
installxanmod2
elif [ "$answer" = "n" ]; then
  echo "Отмена и выход..."
  exit 0
elif [ "$answer" = "o" ]; then
check_sys
detele_kernel_custom
else
  echo "Неверный ввод. Пожалуйста, введите y, n или o."
fi
     exit
     ;;

   *)
     echo "$(random_color 'Неверный выбор, выход из скрипта.')"
     exit
     ;;
esac

echo "$(random_color 'Не торопись, не торопись, старина')"
sleep 1

if [ "$hy2zt" = "работает" ]; then
  echo "Hysteria уже запущена, пожалуйста, сначала удалите ее перед установкой."
  exit 1
else
  echo "Genshin Impact, запускай."
fi

uninstall_hysteria > /dev/null 2>&1

installhy2 () {
  cd /root
  mkdir -p ~/hy3
  cd ~/hy3

  REPO_URL="https://github.com/apernet/hysteria/releases"
  LATEST_RELEASE=$(curl -s $REPO_URL/latest | jq -r '.tag_name')
  DOWNLOAD_URL="https://github.com/apernet/hysteria/releases/download/$LATEST_RELEASE/hysteria-linux-$arch"

  if wget -O hysteria-linux-$arch https://download.hysteria.network/app/latest/hysteria-linux-$arch; then
    chmod +x hysteria-linux-$arch
  else
    if wget -O hysteria-linux-$arch $DOWNLOAD_URL; then
      chmod +x hysteria-linux-$arch
    else
      echo "Не удалось загрузить файл"
      exit 1
    fi
  fi

  echo "Последняя версия: $LATEST_RELEASE"
  echo "URL загрузки: $DOWNLOAD_URL"
}

echo "$(random_color 'Идет загрузка, старина ( ﾟдﾟ)つBye')"
sleep 1
installhy2 > /dev/null 2>&1

# Создание конфигурационного файла
cat <<EOL > config.yaml
listen: :443

auth:
  type: password
  password: Se7RAuFZ8Lzg

masquerade:
  type: proxy
  file:
    dir: /www/masq
  proxy:
    url: https://news.ycombinator.com/
    rewriteHost: true
  string:
    content: hello stupid world
    headers:
      content-type: text/plain
      custom-stuff: ice cream so good
    statusCode: 200

bandwidth:
  up: 0 gbps
  down: 0 gbps

udpIdleTimeout: 90s
EOL

while true; do
    echo "$(random_color 'Введите номер порта (по умолчанию 443, 0 для случайного 2000-60000, можно указать 1-65630): ')"
    read -p "" port
  
    if [ -z "$port" ]; then
      port=443
    elif [ "$port" -eq 0 ]; then
      port=$((RANDOM % 58001 + 2000))
    elif ! [[ "$port" =~ ^[0-9]+$ ]]; then
      echo "$(random_color 'Дружище, пожалуйста, введите число, попробуйте снова:')"
      continue
    fi
  
    while netstat -tuln | grep -q ":$port "; do
      echo "$(random_color 'Порт занят, введите другой:')"
      read -p "" port
    done
  
    if sed -i "s/443/$port/" config.yaml; then
      echo "$(random_color 'Порт установлен:')" "$port"
    else
      echo "$(random_color 'Не удалось изменить порт, выход.')"
      exit 1
    fi
  
# Генерация самоподписанного сертификата
generate_certificate() {
    read -p "Введите домен для самоподписанного сертификата (по умолчанию bing.com): " user_domain
    domain_name=${user_domain:-"bing.com"}
    if curl --output /dev/null --silent --head --fail "$domain_name"; then
        mkdir -p /etc/ssl/private
        openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name prime256v1) -keyout "/etc/ssl/private/$domain_name.key" -out "/etc/ssl/private/$domain_name.crt" -subj "/CN=$domain_name" -days 36500
        chmod 777 "/etc/ssl/private/$domain_name.key" "/etc/ssl/private/$domain_name.crt"
        echo -e "Самоподписанный сертификат и ключ созданы!"
    else
        echo -e "Неверный домен или домен недоступен, введите действительный домен!"
        generate_certificate
    fi
}

read -p "Выберите тип сертификата (1 - ACME, 2 - самоподписанный, по умолчанию ACME): " cert_choice

if [ "$cert_choice" == "2" ]; then
    generate_certificate

    certificate_path="/etc/ssl/private/$domain_name.crt"
    private_key_path="/etc/ssl/private/$domain_name.key"

    echo -e "Сертификат сохранен в /etc/ssl/private/$domain_name.crt"
    echo -e "Ключ сохранен в /etc/ssl/private/$domain_name.key"

    temp_file=$(mktemp)
    echo -e "temp_file: $temp_file"
    sed '3i\tls:\n  cert: '"/etc/ssl/private/$domain_name.crt"'\n  key: '"/etc/ssl/private/$domain_name.key"'' /root/hy3/config.yaml > "$temp_file"
    mv "$temp_file" /root/hy3/config.yaml
    touch /root/hy3/ca
    ovokk="insecure=1&"
    choice1="true"
    echo -e "Информация о сертификате добавлена в /root/hy3/config.yaml."
    
# Получение IPv4 информации
get_ipv4_info() {
  ip_address=$(wget -4 -qO- --no-check-certificate --user-agent=Mozilla --tries=2 --timeout=3 http://ip-api.com/json/) &&
  
  ispck=$(expr "$ip_address" : '.*isp\":[ ]*\"\([^"]*\).*')

  if echo "$ispck" | grep -qi "cloudflare"; then
    echo "Обнаружен Warp, введите правильный IP сервера:"
    read new_ip
    ipwan="$new_ip"
  else
    ipwan="$(expr "$ip_address" : '.*query\":[ ]*\"\([^"]*\).*')"
  fi
}

# Получение IPv6 информации
get_ipv6_info() {
  ip_address=$(wget -6 -qO- --no-check-certificate --user-agent=Mozilla --tries=2 --timeout=3 https://api.ip.sb/geoip) &&
  
  ispck=$(expr "$ip_address" : '.*isp\":[ ]*\"\([^"]*\).*')

  if echo "$ispck" | grep -qi "cloudflare"; then
    echo "Обнаружен Warp, введите правильный IP сервера:"
    read new_ip
    ipwan="[$new_ip]"
  else
    ipwan="[$(expr "$ip_address" : '.*ip\":[ ]*\"\([^"]*\).*')]"
  fi
}

while true; do
  echo "1. Режим IPv4"
  echo "2. Режим IPv6"
  echo "Нажмите Enter для выбора IPv4 по умолчанию."

  read -p "Выберите: " choice

  case $choice in
    1)
      get_ipv4_info
      echo "Ваш IP адрес: $ipwan"
      ipta="iptables"
      break
      ;;
    2)
      get_ipv6_info
      echo "Ваш IP адрес: $ipwan"
      ipta="ip6tables"
      break
      ;;
    "")
      echo "Используется IPv4 по умолчанию."
      get_ipv4_info
      echo "Ваш IP адрес: $ipwan"
      ipta="iptables"
      break
      ;;
    *)
      echo "Невер
