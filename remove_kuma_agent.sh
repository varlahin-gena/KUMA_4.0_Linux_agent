#!/bin/bash

# Скрипт для удаления сервиса KUMA Agent

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функция для вывода цветных сообщений
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Функция для выполнения команд с проверкой
execute_command() {
    local command="$1"
    local description="$2"
    local ignore_errors="${3:-false}"
    
    echo -n "▶ ${description}... "
    
    if eval "$command" &>/dev/null; then
        echo -e "${GREEN}✓${NC}"
        return 0
    else
        echo -e "${RED}✗${NC}"
        if [ "$ignore_errors" = "false" ]; then
            print_error "Ошибка при выполнении: ${description}"
            return 1
        else
            print_warning "Ошибка игнорируется: ${description}"
            return 0
        fi
    fi
}

# Функция для подтверждения действия
confirm_action() {
    local message="$1"
    local response
    
    echo ""
    echo -e "${YELLOW}⚠ ВНИМАНИЕ: ${message}${NC}"
    echo -n "Вы уверены, что хотите продолжить? (y/n): "
    read -r response
    
    if [[ "$response" =~ ^[YyДд]$ ]]; then
        return 0
    else
        return 1
    fi
}

# Функция для остановки и отключения сервиса
stop_and_disable_service() {
    local id="$1"
    local service_name="kuma-agent-${id}.service"
    
    print_info "Остановка и отключение сервиса ${service_name}"
    
    # Проверяем, существует ли сервис
    if systemctl list-unit-files | grep -q "${service_name}"; then
        # Проверяем, активен ли сервис
        if systemctl is-active --quiet "${service_name}"; then
            execute_command "systemctl stop ${service_name}" "Остановка сервиса"
        else
            print_info "Сервис уже остановлен"
        fi
        
        # Проверяем, включен ли сервис в автозагрузку
        if systemctl is-enabled --quiet "${service_name}" 2>/dev/null; then
            execute_command "systemctl disable ${service_name}" "Отключение автозагрузки"
        else
            print_info "Сервис не в автозагрузке"
        fi
        
        return 0
    else
        print_warning "Сервис ${service_name} не найден"
        return 0
    fi
}

# Функция для удаления service файла
remove_service_file() {
    local id="$1"
    local service_file="/usr/lib/systemd/system/kuma-agent-${id}.service"
    
    print_info "Удаление service файла"
    
    if [ -f "${service_file}" ]; then
        # Показываем содержимое перед удалением
        echo ""
        echo "Содержимое удаляемого файла:"
        echo "--------------------------------------------------"
        cat "${service_file}"
        echo "--------------------------------------------------"
        echo ""
        
        if confirm_action "Удалить service файл ${service_file}?"; then
            execute_command "rm -f ${service_file}" "Удаление ${service_file}"
            
            # Перезагружаем systemd после удаления
            execute_command "systemctl daemon-reload" "Перезагрузка systemd"
            execute_command "systemctl reset-failed" "Сброс failed сервисов"
            
            return 0
        else
            print_warning "Удаление service файла отменено"
            return 1
        fi
    else
        print_info "Service файл не найден: ${service_file}"
        return 0
    fi
}

# Функция для удаления директории агента
remove_agent_directory() {
    local id="$1"
    local agent_dir="/opt/kaspersky/kuma/agent/${id}"
    
    print_info "Удаление директории агента"
    
    if [ -d "${agent_dir}" ]; then
        # Показываем содержимое директории
        echo ""
        echo "Содержимое удаляемой директории ${agent_dir}:"
        echo "--------------------------------------------------"
        ls -la "${agent_dir}"
        echo "--------------------------------------------------"
        echo ""
        
        # Подсчет размера директории
        local dir_size=$(du -sh "${agent_dir}" 2>/dev/null | cut -f1)
        echo "Размер директории: ${dir_size:-неизвестно}"
        echo ""
        
        if confirm_action "Удалить директорию ${agent_dir} и все её содержимое?"; then
            execute_command "rm -rf ${agent_dir}" "Удаление ${agent_dir}"
            return 0
        else
            print_warning "Удаление директории отменено"
            return 1
        fi
    else
        print_info "Директория не найдена: ${agent_dir}"
        return 0
    fi
}

# Основная функция удаления
main() {
    # Проверка наличия аргумента (ID)
    if [ $# -eq 0 ]; then
        print_error "Не указан ID"
        echo "Использование: $0 <ID>"
        echo "Пример: $0 12345"
        exit 1
    fi

    local ID="$1"

    # Проверка, что ID не пустой
    if [ -z "$ID" ]; then
        print_error "ID не может быть пустым"
        exit 1
    fi

    echo ""
    echo "=================================================="
    echo "  Удаление KUMA Agent с ID: ${ID}"
    echo "=================================================="
    echo ""

    # Показываем информацию о том, что будет удалено
    print_warning "Будут удалены:"
    echo "  - Сервис: kuma-agent-${ID}.service"
    echo "  - Service файл: /usr/lib/systemd/system/kuma-agent-${ID}.service"
    echo "  - Директория: /opt/kaspersky/kuma/agent/${ID}/"
    echo ""
    print_info "Родительские директории (/opt/kaspersky/kuma/agent и /opt/kaspersky/kuma) НЕ будут удалены"
    print_info "Исполняемый файл /opt/kaspersky/kuma/agent_kuma НЕ будет удален"

    # Финальное подтверждение
    if ! confirm_action "Это действие нельзя отменить. Удалить сервис KUMA Agent с ID ${ID}?"; then
        print_info "Операция отменена пользователем"
        exit 0
    fi

    echo ""

    # Шаг 1: Остановка и отключение сервиса
    print_info "Шаг 1: Остановка сервиса"
    stop_and_disable_service "$ID"
    
    echo ""

    # Шаг 2: Удаление service файла
    print_info "Шаг 2: Удаление service файла"
    remove_service_file "$ID"
    
    echo ""

    # Шаг 3: Удаление директории агента
    print_info "Шаг 3: Удаление директории агента"
    remove_agent_directory "$ID"
    
    echo ""
    echo "=================================================="
    
    # Финальная проверка
    print_info "Проверка результатов удаления:"
    
    # Проверка сервиса
    if systemctl list-unit-files | grep -q "kuma-agent-${ID}"; then
        print_error "Сервис все еще существует в systemd"
    else
        print_success "Сервис удален из systemd"
    fi
    
    # Проверка service файла
    if [ -f "/usr/lib/systemd/system/kuma-agent-${ID}.service" ]; then
        print_error "Service файл все еще существует"
    else
        print_success "Service файл удален"
    fi
    
    # Проверка директории агента
    if [ -d "/opt/kaspersky/kuma/agent/${ID}" ]; then
        print_error "Директория агента все еще существует"
    else
        print_success "Директория агента удалена"
    fi
    
    # Проверка родительских директорий и исполняемого файла
    echo ""
    print_info "Проверка родительских директорий:"
    
    if [ -d "/opt/kaspersky/kuma/agent" ]; then
        print_success "Родительская директория /opt/kaspersky/kuma/agent сохранена"
        
        # Показываем оставшиеся агенты
        local remaining_agents=$(find "/opt/kaspersky/kuma/agent" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
        if [ "${remaining_agents}" -gt 0 ]; then
            echo "  Осталось агентов: ${remaining_agents}"
        else
            echo "  Директория agent пуста"
        fi
    else
        print_warning "Директория /opt/kaspersky/kuma/agent не существует"
    fi
    
    if [ -d "/opt/kaspersky/kuma" ]; then
        print_success "Родительская директория /opt/kaspersky/kuma сохранена"
        
        # Проверяем наличие исполняемого файла
        if [ -f "/opt/kaspersky/kuma/agent_kuma" ]; then
            print_success "Исполняемый файл /opt/kaspersky/kuma/agent_kuma сохранен"
        fi
    else
        print_warning "Директория /opt/kaspersky/kuma не существует"
    fi
    
    echo "=================================================="
    echo -e "${GREEN}✅ Процесс удаления завершен${NC}"
    echo "=================================================="
}

# Запуск основной функции
main "$@"
