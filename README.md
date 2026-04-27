# KUMA_4.0_Linux_agent
Скрипты для автоматической установки и удаление агентов KUMA на Linux сервере.

Кратко:
Для установки агента запускаем скрипт setup_kuma_agent.sh с указанием ID сервиса: sudo ./setup_kuma_agent.sh 12345
Для удаление агента запускаем скрипт remove_kuma_agent.sh с указанием ID сервиса: sudo ./remove_kuma_agent.sh 12345

Подробно:
В процессе использования SIEM KUMA возникла ситуация, требующая использование агентов на Linux серверах.
Процесс установки агента руками не сильно сложный, но когда необходимо установить сразу десяток агентов на одном сервере - работа занимает не мало времени.

Порядок установки агента в кратце:
1. Создаём сервис агента во вкладке "Активные сервисы" на основе шаблона агента и копируем его ID. Важно - ID не шаблона агента, а сервиса агента.
2. Создаём пользователя kuma: sudo useradd --system kuma && usermod -s /usr/bin/false kuma
3. Создаём директории корневые: mkdir /opt/kaspersky && mkdir /opt/kaspersky/kuma
4. Копируем на сервер исполняемый файл в папку /opt/kaspersky/kuma/, называем его agent_kuma. Можете назвать иначе, но мне удобно так.
5. Даём права на исполнение файла "agent_kuma": sudo chmod +x /opt/kaspersky/kuma/agent_kuma
6. Создаём папку для агентов: mkdir -p /opt/kaspersky/kuma/agent
7. Создаём папку для агента с его ID: mkdir -p /opt/kaspersky/kuma/agent/<ID>
8. Готовим файл для работы сервиса агента как службы: touch /usr/lib/systemd/system/kuma-agent-<ID>.service
9. Пишем в этот файла следующее:  
[Unit]  
Description=KUMA Agent Syslog  
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
ExecStartPre=+-chown -R kuma:kuma /opt/kaspersky/kuma/agent/<ID>  
ExecStart=/opt/kaspersky/kuma/agent_kuma agent --core https://FQDN.domain.local:7210 --id <ID> --wd /opt/kaspersky/kuma/agent/<ID>/  

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

7. Даём права пользователю на папку kuma: sudo chown -R kuma:kuma /opt/kaspersky/kuma/
8. Далее обновляем конфигурацию: systemctl daemon-reload
9. Запускаем сервис: systemctl start kuma-agent-<ID>.service
10. Включаем сервис: systemctl enable kuma-agent-<ID>.service

И чтобы каждый раз руками это не править - сделал скрипт для установки и удаления агента.

Для использования скрипта для установки агента достаточно:
1. Наличия УЗ kuma и прав у неё.
2. Наличие пути /opt/kaspersky/kuma/.
3. Наличия установочного файла агента.
4. Созданный сервис агента в "Активных сервисах".

Скрипт установки сам создать подпапки, проверит наличие файлов и УЗ.
Скрипт удаление сам остановит службу и удалить все файлы, связанные с агентом.


