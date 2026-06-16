#!/bin/bash
# Скрипт для настройки маскарадинга на Ubuntu
# Запускать с правами root (sudo)

# === НАСТРОЙКИ ===
# Укажите интерфейс, через который сервер выходит в интернет (например, eth0, ens3, wlan0)
INTERNET_IFACE="eth0"

# === ПРОВЕРКА ПРАВ ===
if [[ $EUID -ne 0 ]]; then
   echo "Ошибка: скрипт нужно запускать с правами root (sudo)." 
   exit 1
fi

# === ВКЛЮЧЕНИЕ IP-FORWARDING ===
echo "Включаем IP-forwarding..."
sysctl -w net.ipv4.ip_forward=1

# Чтобы пережило перезагрузку, раскомментируйте строку ниже:
# sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf

# === ДОБАВЛЕНИЕ ПРАВИЛА МАСКАРАДИНГА ===
echo "Добавляем правило iptables для маскарадинга на интерфейсе $INTERNET_IFACE..."
iptables -t nat -A POSTROUTING -o $INTERNET_IFACE -j MASQUERADE

# === СОХРАНЕНИЕ ПРАВИЛ (опционально) ===
# Установите пакет iptables-persistent (если ещё не установлен) и сохраните правила
# apt update && apt install -y iptables-persistent
# netfilter-persistent save

# Если iptables-persistent не используется, можно сохранить в файл и восстанавливать при загрузке:
# iptables-save > /etc/iptables.rules
# затем в /etc/network/interfaces или /etc/rc.local добавить строку восстановления:
# pre-up iptables-restore < /etc/iptables.rules

echo "Маскарадинг настроен для интерфейса $INTERNET_IFACE."
echo "Не забудьте разрешить форвардинг на постоянной основе (отредактируйте /etc/sysctl.conf)."
