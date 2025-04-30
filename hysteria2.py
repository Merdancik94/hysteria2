import os
    import sys
    import requests

    def install_dependencies():
        os.system('apt install python3 python3-pip -y')
        os.system('pip3 install requests')

    def download_script():
        url = 'https://raw.githubusercontent.com/seagullz4/hysteria2/main/hysteria2.py'
        response = requests.get(url)
        with open('hysteria2.py', 'wb') as f:
            f.write(response.content)

    if __name__ == '__main__':
        print("Hysteria2 установщик")
        install_dependencies()
        download_script()
        print("Установка завершена!")
    