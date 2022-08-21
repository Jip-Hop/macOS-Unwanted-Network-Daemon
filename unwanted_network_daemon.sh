#!/usr/bin/env bash

# This script is a workaround for the annoyance which is caused by macOS storing Wi-Fi networks + credentials in NVRAM.
# On startup, macOS will connect to the most recently connected Wi-Fi network (stored in NVRAM), even if the OS that's currently booted
# doesn't have the credentials for this network...
# This is a problem in the case of dual booting two isolated operating systems (both on different encrypted disks) where one of them is
# not supposed to connect to some networks.
# Run this script at startup on both of the operating systems and modify the UNWANTED_NETWORKS list for each OS.
# It will disconnect from the unwanted networks, purge the network from preferred networks and remove the credentials from the keychain.

UNWANTED_NETWORKS=("guest" "OPEN")
WIFI_DEVICE_NAME="$(networksetup -listallhardwareports | awk '/Wi-Fi|AirPort/{getline; print $2}')" # for example: en0
SLEEP_TIME=10
MAX_SLEEP_TIME=3600

function remove_unwanted_networks {
    # Get SSID of currently connected Wi-Fi network
    CURRENT_NETWORK="$(networksetup -getairportnetwork "$WIFI_DEVICE_NAME" | cut -d ' ' -f 4)"
    RESTORE_WIFI=0

    for UNWANTED_NETWORK in "${UNWANTED_NETWORKS[@]}";
    do
        # Turn off Wi-Fi if we're currently connected to this network
        if [ "$CURRENT_NETWORK" = "$UNWANTED_NETWORK" ] && [ $RESTORE_WIFI -eq 0 ]; then
            networksetup -setnetworkserviceenabled Wi-Fi off
            RESTORE_WIFI=1
        fi
        # Remove this unwanted Wi-Fi network from the list of preferred networks,
        # this will also update preferred-networks in NVRAM
        networksetup -removepreferredwirelessnetwork "$WIFI_DEVICE_NAME" "$UNWANTED_NETWORK" &>/dev/null
        # Remove credentials from keychain
        security delete-generic-password -l "$UNWANTED_NETWORK" "/Library/Keychains/System.keychain" &>/dev/null
    done

    # Turn Wi-Fi back on if we were connected to an unwanted Wi-Fi network
    # and let it auto-connect to a preferred network
    if [ $RESTORE_WIFI -eq 1 ]; then
        networksetup -setnetworkserviceenabled Wi-Fi on
    fi
}

# Remove the unwanted networks on startup and periodically
while :
do
    remove_unwanted_networks
    sleep $SLEEP_TIME
    
    # Increase next sleep time (exponential back-off with a max sleep time)
    if (( SLEEP_TIME < MAX_SLEEP_TIME)); then
        SLEEP_TIME=$((SLEEP_TIME * 2))
    elif (( SLEEP_TIME > MAX_SLEEP_TIME)); then
        SLEEP_TIME=$MAX_SLEEP_TIME
    fi
done