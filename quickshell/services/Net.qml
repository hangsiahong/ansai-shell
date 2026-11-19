pragma Singleton

import QtQuick
import qs
import Quickshell
import Quickshell.Networking
import Quickshell.Bluetooth

Singleton {
    id: root

    readonly property var devices: Networking.devices?.values ?? []
    readonly property var wifi: devices.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wired: devices.find(d => d.type === DeviceType.Wired && d.connected) ?? null
    readonly property var wifiNetworks: wifi?.networks?.values ?? []
    readonly property var activeWifi: wifiNetworks.find(n => n.connected) ?? null
    readonly property bool wifiOn: Networking.wifiEnabled
    readonly property string ssid: activeWifi?.name ?? ""
    readonly property real signal: activeWifi?.signalStrength ?? 0

    readonly property var bt: Bluetooth.defaultAdapter
    readonly property bool btOn: bt?.enabled ?? false
    readonly property var btConnected: (Bluetooth.devices?.values ?? []).filter(d => d.connected)

    function toggleWifi(): void {
        Networking.wifiEnabled = !Networking.wifiEnabled;
    }
    function toggleBt(): void {
        if (bt)
            bt.enabled = !bt.enabled;
    }

    function netIcon(): string {
        if (wired)
            return "lan";
        if (!wifiOn)
            return "wifi_off";
        if (!activeWifi)
            return "wifi_find";
        if (signal > 0.66)
            return "wifi";
        if (signal > 0.33)
            return "wifi_2_bar";
        return "wifi_1_bar";
    }
    function netLabel(): string {
        if (wired)
            return "Ethernet";
        if (!wifiOn)
            return "Off";
        return ssid || "Not connected";
    }
}
