#!/bin/bash

def agree_treaty():       # Этот метод спрашивает, согласен ли пользователь с условиями
    def hy_shortcut():   # Добавление ярлыка hy2
        hy2_shortcut = Path(r"/usr/local/bin/hy2")  # Создание ярлыка
        hy2_shortcut.write_text("#!/bin/bash\nwget -O hy2.py https://raw.githubusercontent.com/seagullz4/hysteria2/main/hysteria2.py && chmod +x hy2.py && python3 hy2.py\n")  # Запись в файл
        hy2_shortcut.chmod(0o755)
    file_agree = Path(r"/etc/hy2config/agree.txt")  # Получение пути к файлу
    if file_agree.exists():       # Если файл существует, пропускаем этот шаг
        print("Вы уже согласились, спасибо")
        hy_shortcut()
    else:
        while True:
            print("Я согласен с условиями использования этого программного обеспечения, соблюдая законы страны размещения сервера и страны пользователя. Это ПО предназначено только для образовательных целей и не может быть использовано в коммерческих целях.")
            choose_1 = input("Согласны ли вы с условиями и хотите установить hysteria2? [y/n]: ")
            if choose_1 == "y":
                check_file = subprocess.run("mkdir /etc/hy2config && touch /etc/hy2config/agree.txt && touch /etc/hy2config/hy2_url_scheme.txt", shell=True)
                print(check_file)    # При согласии пользователя создается файл, чтобы в будущем этот шаг пропустить
                hy_shortcut()
                break
            elif choose_1 == "n":
                print("Вы не согласились с условиями установки")
                sys.exit()
            else:
                print("\033[91mПожалуйста, выберите правильный вариант!\033[m")

def hysteria2_install():    # Установка hysteria2
    while True:
        choice_1 = input("Хотите установить/обновить hysteria2? [y/n]: ")
        if choice_1 == "y":
            print("1. Установить последнюю версию\n2. Установить конкретную версию")
            choice_2 = input("Введите номер варианта: ")
            if choice_2 == "1":
                hy2_install = subprocess.run("bash <(curl -fsSL https://get.hy2.sh/)", shell=True, executable="/bin/bash")  # Использование официального скрипта для установки
                print(hy2_install)
                print("Установка hysteria2 завершена, пожалуйста, настройте с помощью автоматической конфигурации")
                hysteria2_config()
                break
            elif choice_2 == "2":
                version_1 = input("Введите номер версии для установки (например, 2.6.0): ")
                hy2_install_2 = subprocess.run(f"bash <(curl -fsSL https://get.hy2.sh/) --version v{version_1}", shell=True, executable="/bin/bash")  # Установка конкретной версии
                print(hy2_install_2)
                print(f"Установка hysteria2 версии {version_1} завершена, пожалуйста, настройте с помощью автоматической конфигурации")
                hysteria2_config()
                break
            else:
                print("\033[91mОшибка ввода, пожалуйста, попробуйте снова\033[m")
        elif choice_1 == "n":
            print("Установка hysteria2 отменена")
            break
        else:
            print("\033[91mОшибка ввода, пожалуйста, попробуйте снова\033[m")

def hysteria2_uninstall():   # Удаление hysteria2
    while True:
        choice_1 = input("Хотите удалить hysteria2? [y/n]: ")
        if choice_1 == "y":
            hy2_uninstall_1 = subprocess.run("bash <(curl -fsSL https://get.hy2.sh/) --remove", shell=True, executable="/bin/bash")  # Использование официального скрипта для удаления
            print(hy2_uninstall_1)
            hy2_uninstall_1_2 = subprocess.run("rm -rf /etc/hysteria; rm -rf /etc/systemd/system/multi-user.target.wants/hysteria-server.service; rm -rf /etc/systemd/system/multi-user.target.wants/hysteria-server@*.service; systemctl daemon-reload; /etc/hy2config/jump_port_back.sh; rm -rf /etc/ssl/private/; rm -rf /etc/hy2config; rm -rf /usr/local/bin/hy2", shell=True)  # Удаление системных служб
            print(hy2_uninstall_1_2)
            print("Удаление hysteria2 завершено")
            sys.exit()
        elif choice_1 == "n":
            print("Удаление hysteria2 отменено")
            break
        else:
            print("\033[91mОшибка ввода, пожалуйста, попробуйте снова\033[m")

def server_manage():   # Управление службой hysteria2
    while True:
            print("1. Запустить службу (автоматически настроить автозапуск)\n2. Остановить службу\n3. Перезапустить службу\n4. Просмотреть статус службы\n5. Просмотр логов\n6. Просмотр информации о версии hy2\n0. Назад")
            choice_2 = input("Введите вариант: ")
            if choice_2 == "1":
                print(subprocess.run("systemctl enable --now hysteria-server.service", shell=True))
            elif choice_2 == "2":
                print(subprocess.run("systemctl stop hysteria-server.service", shell=True))
            elif choice_2 == "3":
                print(subprocess.run("systemctl restart hysteria-server.service", shell=True))
            elif choice_2 == "4":
                print("\033[91mВведите q, чтобы выйти\033[m")
                print(subprocess.run("systemctl status hysteria-server.service", shell=True))
            elif choice_2 == "5":
                print(subprocess.run("journalctl --no-pager -e -u hysteria-server.service", shell=True))
            elif choice_2 == "6":
                os.system("/usr/local/bin/hysteria version")
            elif choice_2 == "0":
                break
            else:
                print("\033[91mОшибка ввода, пожалуйста, попробуйте снова\033[m")

# Пример конфигурации сервера hysteria2
