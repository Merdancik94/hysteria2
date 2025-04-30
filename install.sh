#!/bin/bash
# Check if the current user is root
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root!"
  echo "You can use 'sudo -i' to enter root mode."
  exit 1
fi

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
    echo "Detected Debian-like system, please report if this is incorrect"
  elif [[ -f /etc/redhat-release || -f /etc/centos-release || -f /etc/fedora-release || -f /etc/rocky-release ]]; then
    OS_type="CentOS"
    echo "Detected CentOS-like system, please report if this is incorrect"
  else
    echo "Unknown"
  fi
}

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

random_color() {
  colors=("31" "32" "33" "34" "35" "36" "37")
  echo -e "\e[${colors[$((RANDOM % 7))]}m$1\e[0m"
}

if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_TYPE=$ID
    OS_VERSION=$VERSION_ID
else
    echo "Cannot determine the operating system type."
    exit 1
fi

install_custom_packages() {
    if [ "$OS_TYPE" = "debian" ] || [ "$OS_TYPE" = "ubuntu" ]; then
        apt update
        apt install -y wget sed sudo openssl net-tools psmisc procps iptables iproute2 ca-certificates jq
    elif [ "$OS_TYPE" = "centos" ] || [ "$OS_TYPE" = "rhel" ] || [ "$OS_TYPE" = "fedora" ] || [ "$OS_TYPE" = "rocky" ]; then
        yum install -y epel-release
        yum install -y wget sed sudo openssl net-tools psmisc procps-ng iptables iproute ca-certificates jq
    else
        echo "Unsupported operating system."
        exit 1
    fi
}

install_custom_packages

echo "Installed packages:"
for pkg in wget sed openssl iptables jq; do
    if command -v $pkg >/dev/null 2>&1; then
        echo "$pkg is installed"
    else
        echo "$pkg is not installed"
    fi
done

echo "All specified packages have been installed."

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
      echo "This system architecture is not supported, possibly because it is not in the known architecture range."
      exit 1
      ;;
  esac
}

get_installed_version() {
    if [ -x "/root/hy3/hysteria-linux-$arch" ]; then
        version="$("/root/hy3/hysteria-linux-$arch" version | grep Version | grep -o 'v[.0-9]*')"
    else
        version="Not installed yet"
    fi
}

get_latest_version() {
  local tmpfile
  tmpfile=$(mktemp)

  if ! curl -sS "https://api.hy2.io/v1/update?cver=installscript&plat=linux&arch="$arch"&chan=release&side=server" -o "$tmpfile"; then
    echo "Failed to get the latest version from the Hysteria 2 API, please check your network and try again."
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

checkact() {
pid=$(pgrep -f "hysteria-linux-$arch")

if [ -n "$pid" ]; then
  hy2zt="Running"
else
  hy2zt="Not running"
fi
}

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
        echo -e "${Error} grub.conf/grub.cfg not found, please check."
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
        echo -e "${Error} grub.cfg not found, please check."
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
        echo -e "${Error} grub.cfg not found, please check."
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
    #exit 1
  fi
}

# The script continues, configuring various options like the installation, removal, and management of the Hysteria 2 kernel, as well as other options.
