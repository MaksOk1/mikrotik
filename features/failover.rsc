# 1. Захист: Перевірка наявності DHCP-клієнтів
:local ethFind [/ip/dhcp-client/find where interface="ether1"]
:local wifiFind [/ip/dhcp-client/find where interface="wifi2"]

:if ([:len $ethFind] = 0 || [:len $wifiFind] = 0) do={
    :log error "--- Failover: ether1 or wifi2 DHCP client missing! Script stopped. ---"
    :error "Required interfaces not found"
}

# Примусово тримаємо ether1 увімкненим
:if ([/ip/dhcp-client/get $ethFind disabled] = true) do={
    :log warning "--- Failover: ether1 DHCP was disabled. Forcing ENABLE... ---"
    /ip/dhcp-client/enable $ethFind
}

:local ethStatus [/ip/dhcp-client/get $ethFind status]
:local wifiDisabled [/ip/dhcp-client/get $wifiFind disabled]
:local internetUp false

# 2. Перевірка реального доступу до мережі через кабель
:if ($ethStatus = "bound") do={
    # Пінгуємо за межі мережі конкретно через інтерфейс ether1
    :local pingCount [/ping 1.1.1.1 interface=ether1 count=3]
    :if ($pingCount > 1) do={
        :set internetUp true
    } else={
        :log warning "--- Failover: ether1 is BOUND, but PING FAILED (No internet) ---"
    }
} else {
    :log info "--- Failover: ether1 is down (Status: $ethStatus) ---"
}

# 3. Логіка перемикання з детальним логуванням
:if ($internetUp = true) do={
    :if ($wifiDisabled = false) do={
        :log info "--- Failover: MAIN LINK RESTORED. Switching back to ether1... ---"
        /ip/dhcp-client/disable $wifiFind
        /interface/list/member disable [find interface="wifi2" list="WAN"]
        /interface/bridge/port/enable [find where interface="wifi2"]
        /interface/wifi/set [find name="wifi2"] configuration=wifi-homik-config configuration.mode=ap
        /interface/list/member enable [find interface="ether1" list="WAN"]
        :log info "--- Failover: Main link restoration complete. ---"
    }
} else={
    :if ($wifiDisabled = true) do={
        :log warning "--- Failover: MAIN LINK DOWN. Activating Mobile Backup... ---"
        /interface/list/member disable [find interface="ether1" list="WAN"]
        /interface/bridge/port/disable [find where interface="wifi2"]
        /interface/wifi/set [find name="wifi2"] configuration=samsung-uplink-config configuration.mode=station
        /interface/list/member enable [find interface="wifi2" list="WAN"]
        /ip/dhcp-client/enable $wifiFind
        :log warning "--- Failover: Mobile Backup activation complete. ---"
    }
}
