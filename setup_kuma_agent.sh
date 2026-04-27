#!/bin/bash

# Скрипт для создания структуры директорий и настройки сервиса Kuma Agent

# Конфигурация сервиса (шаблон)
create_service_config() {
    local id="$1"
    local core_url="$2"
    
    # Если core_url не указан, используем значение по умолчанию
    if [ -z "$core_url" ]; then
        core_url="https://FQDN.domain.local:7210"
    fi
    
    cat <<EOF
[Unit]
Description=KUMA Agent Syslog (ID: ${id})
StartLimitIntervalSec=1
After=network.target

[Service]
Type=notify
Restart=always
RestartPreventExitStatus=99
TimeoutSec=300
RestartSec=5
WatchdogSec=60

User=kuma
Group=kuma

ExecStartPre=+-chown kuma:kuma /opt/kaspersky/kuma/agent
ExecStartPre=+-chown -R kuma:kuma /opt/kaspersky/kuma/agent/${id}
ExecStart=/opt/kaspersky/kuma/agent_kuma agent --core ${core_url} --id ${id} --wd /opt/kaspersky/kuma/agent/${id}/

LimitFSIZE=infinity
LimitCPU=infinity
LimitAS=infinity
LimitNOFILE=64000
LimitNPROC=64000
LimitMEMLOCK=infinity
TasksMax=infinity
TasksAccounting=false

[Install]
WantedBy=multi-user.target
EOF
}

# Функция для проверки существования пользователя и группы
check_user_group() {
    local user_exists=false
    local group_exists=false
    
    # Проверка существования пользователя kuma
    if id "kuma" &>/dev/null; then
        user_exists=true
        echo "  ✓ Пользователь 'kuma' существует"
    else
        echo "  ⚠ Пользователь 'kuma' не найден"
    fi
    
    # Проверка существования группы kuma
    if getent group "kuma" &>/dev/null; then
        group_exists=true
        echo "  ✓ Группа 'kuma' существует"
    else
        echo "  ⚠ Группа 'kuma' не найдена"
    fi
    
    if [ "$user_exists" = false ] || [ "$group_exists" = false ]; then
        echo ""
        echo "  ⚠ ВНИМАНИЕ: Пользователь или группа 'kuma' не существуют!"
        echo "     Для создания выполните:"
        echo "     sudo groupadd -r kuma"
        echo "     sudo useradd -r -g kuma -s /sbin/nologin -d /opt/kaspersky/kuma kuma"
        return 1
    fi
    
    return 0
}

# Функция для проверки наличия исполняемого файла
check_executable() {
    local exec_path="/opt/kaspersky/kuma/agent_kuma"
    
    if [ -f "$exec_path" ]; then
        echo "  ✓ Исполняемый файл найден: $exec_path"
        
        # Проверка прав на выполнение
        if [ -x "$exec_path" ]; then
            echo "  ✓ Исполняемый файл имеет права на выполнение"
        else
            echo "  ⚠ Исполняемый файл не имеет прав на выполнение"
            echo "     Выполните: sudo chmod +x $exec_path"
        fi
        return 0
    else
        echo "  ⚠ Исполняемый файл не найден: $exec_path"
        echo "     Убедитесь, что KUMA Agent установлен в /opt/kaspersky/kuma/"
        return 1
    fi
}

# Функция для выполнения команд с проверкой
execute_command() {
    local command="$1"
    local description="$2"
    
    echo "▶ Выполнение: ${description}"
    if eval "$command"; then
        echo "  ✓ Успешно выполнено"
        return 0
    else
        echo "  ✗ Ошибка при выполнении: ${description}"
        return 1
    fi
}

# Функция для управления сервисом
manage_service() {
    local id="$1"
    local service_name="kuma-agent-${id}.service"
    
    echo ""
    echo "=== Управление сервисом ${service_name} ==="
    
    # Перезагрузка systemd
    execute_command "systemctl daemon-reload" "Перезагрузка конфигурации systemd"
    
    # Запуск сервиса
    execute_command "systemctl start ${service_name}" "Запуск сервиса ${service_name}"
    
    # Включение автозапуска
    execute_command "systemctl enable ${service_name}" "Включение автозапуска ${service_name}"
    
    # Проверка статуса
    echo ""
    echo "=== Статус сервиса ==="
    systemctl status "${service_name}" --no-pager -l
    
    echo ""
    echo "✓ Сервис ${service_name} успешно настроен и запущен"
}

# Основная логика скрипта
main() {
    # Проверка наличия аргумента (ID)
    if [ $# -eq 0 ]; then
        echo "Ошибка: не указан ID"
        echo "Использование: $0 <ID> [CORE_URL]"
        echo "Пример: $0 12345"
        echo "Пример с URL: $0 12345 https://custom-core.local:7210"
        exit 1
    fi

    local ID="$1"
    local CORE_URL="$2"

    # Проверка, что ID не пустой и содержит только допустимые символы
    if [ -z "$ID" ]; then
        echo "Ошибка: ID не может быть пустым"
        exit 1
    fi

    # Проверка на наличие недопустимых символов (только буквы, цифры, дефис и подчеркивание)
    if [[ ! "$ID" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "Ошибка: ID содержит недопустимые символы. Разрешены только буквы, цифры, дефис и подчеркивание."
        exit 1
    fi

    echo ""
    echo "=================================================="
    echo "  Настройка KUMA Agent с ID: ${ID}"
    echo "=================================================="
    echo ""

    # Проверка системных требований
    echo "=== Проверка системных требований ==="
    check_user_group
    check_executable
    echo ""

    # Создание директорий
    echo "=== Создание директорий ==="
    
    if ! execute_command "mkdir -p /opt/kaspersky/kuma/agent" "Создание /opt/kaspersky/kuma/agent"; then
        exit 1
    fi
    
    if ! execute_command "mkdir -p /opt/kaspersky/kuma/agent/${ID}" "Создание /opt/kaspersky/kuma/agent/${ID}"; then
        exit 1
    fi

    # Установка владельца для директорий
    echo ""
    echo "=== Установка прав доступа ==="
    execute_command "chown -R kuma:kuma /opt/kaspersky/kuma/agent/${ID}" "Установка владельца для /opt/kaspersky/kuma/agent/${ID}"

    echo ""
    echo "✓ Директории успешно созданы:"
    echo "  - /opt/kaspersky/kuma/agent"
    echo "  - /opt/kaspersky/kuma/agent/${ID}"
    echo ""

    # Создание service файла с конфигурацией
    local SERVICE_FILE="/usr/lib/systemd/system/kuma-agent-${ID}.service"

    echo "=== Создание service файла ==="
    echo "  Шаблон: KUMA Agent Syslog"
    echo "  Core URL: ${CORE_URL:-https://FQDN.domain.local:7210}"
    echo "  Исполняемый файл: /opt/kaspersky/kuma/agent_kuma"
    
    # Создаем файл с конфигурацией
    create_service_config "$ID" "$CORE_URL" > "${SERVICE_FILE}"
    
    if [ $? -eq 0 ]; then
        echo "  ✓ Service файл успешно создан: ${SERVICE_FILE}"
        echo ""
        echo "  Содержимое файла:"
        echo "--------------------------------------------------"
        cat "${SERVICE_FILE}"
        echo "--------------------------------------------------"
        
        # Запрос на подтверждение
        echo ""
        echo "Проверьте конфигурацию выше. Все верно? (y/n)"
        read -r answer
        
        if [[ "$answer" =~ ^[YyДд]$ ]]; then
            
            # Запуск управления сервисом
            manage_service "$ID"
            
            # Дополнительная информация
            echo ""
            echo "=== Дополнительная информация ==="
            echo "  Логи сервиса: journalctl -u kuma-agent-${ID}.service -f"
            echo "  Статус сервиса: systemctl status kuma-agent-${ID}.service"
            echo "  Конфигурация: ${SERVICE_FILE}"
            echo "  Рабочая директория: /opt/kaspersky/kuma/agent/${ID}/"
            echo "  Исполняемый файл: /opt/kaspersky/kuma/agent_kuma"
            
        else
            echo ""
            echo "⚠ Конфигурация не утверждена."
            echo "  Вы можете отредактировать файл вручную:"
            echo "  nano ${SERVICE_FILE}"
            echo ""
            echo "  Затем выполните команды:"
            echo "  systemctl daemon-reload"
            echo "  systemctl start kuma-agent-${ID}.service"
            echo "  systemctl enable kuma-agent-${ID}.service"
        fi
    else
        echo "✗ Ошибка при создании service файла"
        exit 1
    fi
}

# Запуск основной функции с передачей всех аргументов
main "$@"

# Вывод итоговой информации
if [ $? -eq 0 ]; then
    echo ""
    echo "=================================================="
    echo "✅ Работа скрипта успешно завершена"
    echo "=================================================="
fi
