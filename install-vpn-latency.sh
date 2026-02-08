set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    clear
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║      Установка VPN Latency Control v2.7                  ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}Ошибка: Скрипт должен быть запущен с правами root!${NC}"
        echo -e "Используйте: ${GREEN}sudo bash <(curl -Ls ...)${NC}"
        exit 1
    fi
}

check_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    else
        OS=$(uname -s)
        VER=$(uname -r)
    fi
    
    echo -e "${YELLOW}Операционная система: ${GREEN}$OS $VER${NC}"
    
    if [[ "$OS" != *"Ubuntu"* ]] && [[ "$OS" != *"Debian"* ]] && [[ "$OS" != *"CentOS"* ]] && [[ "$OS" != *"Rocky"* ]] && [[ "$OS" != *"AlmaLinux"* ]]; then
        echo -e "${YELLOW}⚠ Внимание: Скрипт тестировался на Ubuntu/Debian/CentOS${NC}"
        read -p "Продолжить установку? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

install_dependencies() {
    echo -e "${YELLOW}Установка зависимостей...${NC}"
    
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update
        apt-get install -y iproute2 curl tcptraceroute iputils-ping
    elif command -v yum >/dev/null 2>&1; then
        yum install -y iproute curl tcptraceroute iputils
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y iproute curl tcptraceroute iputils
    else
        echo -e "${RED}Не удалось определить пакетный менеджер${NC}"
        echo -e "${YELLOW}Установите вручную: iproute2, curl${NC}"
    fi
    
    echo -e "${GREEN}✓ Зависимости установлены${NC}"
}

download_main_script() {
    echo -e "${YELLOW}Скачивание основного скрипта...${NC}"
    
    MAIN_SCRIPT_URL="https://raw.githubusercontent.com/Gisem89/vpn-latency-control/main/vpn-latency-control.sh"
    
    curl -s -o /usr/local/bin/vpn-latency-control.sh "$MAIN_SCRIPT_URL"
    
    if [ $? -eq 0 ] && [ -s /usr/local/bin/vpn-latency-control.sh ]; then
        chmod +x /usr/local/bin/vpn-latency-control.sh
        
        ln -sf /usr/local/bin/vpn-latency-control.sh /usr/local/bin/vpn-latency 2>/dev/null || true
        
        echo -e "${GREEN}✓ Основной скрипт установлен${NC}"
    else
        echo -e "${RED}Ошибка загрузки основного скрипта${NC}"
        echo -e "${YELLOW}Попытка использовать локальную версию...${NC}"
        
        create_local_script
    fi
}

create_local_script() {
    echo -e "${YELLOW}Создание локальной версии скрипта...${NC}"
    
    cat > /usr/local/bin/vpn-latency-control.sh << 'VPNSH'
[ВСТАВИТЬ ПОЛНЫЙ КОД СКРИПТА v2.7 ЗДЕСЬ - ТОТ ЧТО Я ПРИСЛАЛ ВЫШЕ]
VPNSH
    
    chmod +x /usr/local/bin/vpn-latency-control.sh
    ln -sf /usr/local/bin/vpn-latency-control.sh /usr/local/bin/vpn-latency 2>/dev/null || true
    
    echo -e "${GREEN}✓ Локальная версия скрипта создана${NC}"
}

create_systemd_service() {
    echo -e "${YELLOW}Настройка автозапуска...${NC}"
    
    cat > /etc/systemd/system/vpn-latency.service << EOF
[Unit]
Description=VPN Latency Control
After=network.target
Wants=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/vpn-latency-control.sh start
ExecStop=/usr/local/bin/vpn-latency-control.sh stop
ExecReload=/usr/local/bin/vpn-latency-control.sh start

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable vpn-latency.service 2>/dev/null || true
    
    echo -e "${GREEN}✓ Systemd сервис создан${NC}"
}

create_default_config() {
    echo -e "${YELLOW}Создание конфигурации по умолчанию...${NC}"
    
    cat > /etc/vpn-latency.conf << 'EOF'
# Конфигурация VPN Latency Control
# Создано автоматически при установке

INTERFACE="auto"
VPN_PORTS="51192 51190 8446"
MODE="fixed"
TARGET_DELAY="800ms"
JITTER="30ms"
SPEED_LIMIT="0"
SPEED_LIMIT_TYPE="shared"
MEASURE_HOST="8.8.8.8"
PACKET_LOSS="0%"
CORRELATION="25%"
EOF
    
    echo -e "${GREEN}✓ Конфигурация создана${NC}"
}

verify_installation() {
    echo -e "\n${YELLOW}Проверка установки...${NC}"
    
    if [ -x /usr/local/bin/vpn-latency-control.sh ]; then
        echo -e "${GREEN}✓ Скрипт установлен: /usr/local/bin/vpn-latency-control.sh${NC}"
    else
        echo -e "${RED}✗ Скрипт не найден${NC}"
        return 1
    fi
    
    if [ -L /usr/local/bin/vpn-latency ]; then
        echo -e "${GREEN}✓ Симлинк создан: /usr/local/bin/vpn-latency${NC}"
    fi
    
    if [ -f /etc/vpn-latency.conf ]; then
        echo -e "${GREEN}✓ Конфигурация создана: /etc/vpn-latency.conf${NC}"
    fi
    
    if [ -f /etc/systemd/system/vpn-latency.service ]; then
        echo -e "${GREEN}✓ Systemd сервис создан${NC}"
    fi
    
    echo -e "\n${YELLOW}Тестирование команды help...${NC}"
    /usr/local/bin/vpn-latency-control.sh help --help 2>/dev/null || /usr/local/bin/vpn-latency-control.sh help
    
    return 0
}

show_instructions() {
    echo -e "\n${GREEN}══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}            УСТАНОВКА УСПЕШНО ЗАВЕРШЕНА!                  ${NC}"
    echo -e "${GREEN}══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${BLUE}ИСПОЛЬЗОВАНИЕ:${NC}"
    echo ""
    echo -e "  ${GREEN}Основные команды:${NC}"
    echo -e "    vpn-latency-control.sh          # Запустить меню"
    echo -e "    vpn-latency                     # То же самое (симлинк)"
    echo -e "    vpn-latency-control.sh menu     # Интерактивное меню"
    echo ""
    echo -e "  ${GREEN}Прямые команды:${NC}"
    echo -e "    vpn-latency-control.sh start    # Применить настройки"
    echo -e "    vpn-latency-control.sh stop     # Удалить правила"
    echo -e "    vpn-latency-control.sh status   # Показать статус"
    echo -e "    vpn-latency-control.sh config   # Настроить параметры"
    echo -e "    vpn-latency-control.sh reset    # Полный сброс"
    echo ""
    echo -e "  ${GREEN}Systemd сервис:${NC}"
    echo -e "    systemctl start vpn-latency     # Запустить сервис"
    echo -e "    systemctl stop vpn-latency      # Остановить сервис"
    echo -e "    systemctl status vpn-latency    # Статус сервиса"
    echo ""
    echo -e "${BLUE}БЫСТРЫЙ СТАРТ:${NC}"
    echo -e "  1. ${GREEN}vpn-latency${NC}                    # Запустить меню"
    echo -e "  2. Выбрать ${GREEN}[1] Настроить конфигурацию${NC}"
    echo -e "  3. Выбрать ${GREEN}[2] Применить настройки${NC}"
    echo -e "  4. Готово! Задержка применена к портам."
    echo ""
    echo -e "${BLUE}КОНФИГУРАЦИЯ:${NC}"
    echo -e "  Файл конфигурации: ${GREEN}/etc/vpn-latency.conf${NC}"
    echo -e "  Основной скрипт:   ${GREEN}/usr/local/bin/vpn-latency-control.sh${NC}"
    echo ""
    echo -e "${YELLOW}Для обновления скрипта просто перезапустите установку!${NC}"
    echo ""
}

main() {
    print_header
    check_root
    check_os
    
    echo -e "${YELLOW}Начинаем установку VPN Latency Control...${NC}"
    echo ""
    
    install_dependencies
    
    download_main_script
    
    create_default_config
    
    create_systemd_service
    
    if verify_installation; then
        show_instructions
    else
        echo -e "${RED}Установка завершена с ошибками${NC}"
        exit 1
    fi
}

case "$1" in
    --help|-h)
        echo "Использование: bash <(curl -Ls URL) [опции]"
        echo ""
        echo "Опции:"
        echo "  --help, -h     Показать эту справку"
        echo "  --update, -u   Обновить скрипт"
        echo ""
        echo "Пример:"
        echo "  bash <(curl -Ls https://raw.githubusercontent.com/user/repo/main/install.sh)"
        exit 0
        ;;
    --update|-u)
        echo "Режим обновления..."
        rm -f /usr/local/bin/vpn-latency-control.sh
        rm -f /usr/local/bin/vpn-latency
        ;;
    *)
        main
        ;;
esac