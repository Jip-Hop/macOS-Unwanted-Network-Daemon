# macOS-Unwanted-Network-Daemon

This script is a workaround for the annoyance which is caused by macOS storing Wi-Fi networks + credentials in NVRAM. On startup, macOS will connect to the most recently connected Wi-Fi network (stored in NVRAM), even if the OS that's currently booted doesn't have the credentials for this network... This is a problem in the case of dual booting two isolated operating systems (both on different encrypted disks) where one of them is not supposed to connect to some networks. Run this script at startup on both of the operating systems and modify the UNWANTED_NETWORKS list for each OS. It will disconnect from the unwanted networks, purge the network from preferred networks and remove the credentials from the keychain.

## Install

```bash
sudo cp unwanted_network_daemon.sh /usr/local/bin/unwanted_network_daemon.sh
sudo chmod -w /usr/local/bin/unwanted_network_daemon.sh
sudo chmod +x /usr/local/bin/unwanted_network_daemon.sh

sudo cp it.debeer.unwanted_network_daemon.plist /Library/LaunchDaemons
sudo launchctl load /Library/LaunchDaemons/it.debeer.unwanted_network_daemon.plist
```

## Start/stop/status

```bash
sudo launchctl stop it.debeer.unwanted_network_daemon
sudo launchctl start it.debeer.unwanted_network_daemon
sudo launchctl print system/it.debeer.unwanted_network_daemon
```

## Notes

I tried to clear the NVRAM variables before shutdown, to prevent the Wi-Fi networks from leaking to the other macOS installation.

```bash
function clear_networks_from_nvram {
    echo "EXIT"
    # Currently connected Wi-Fi is stored separately in NVRAM (current-network),
    # as long as I'm connected to Wi-Fi I can't clear this one
    # # Disable Wi-Fi before shutdown
    # sudo networksetup -setnetworkserviceenabled Wi-Fi off

    # Disconnect from Wi-Fi (without turning off Wi-Fi completely)
    # This will already clear the current-network from NVRAM
    sudo /System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport en0 -z

    # And clear the network NVRAM variables
    sudo nvram -d preferred-networks # This doesn't seem to delete the NVRAM variable as long as there are still Preferred Networks in System Preferences -> Network -> Wi-Fi -> Advanced...
    sudo nvram -d current-network # This should already have been cleared by disconnecting from Wi-Fi
    sudo nvram -d preferred-count # Is this one even set?
}

# Clear the networks + credentials from NVRAM on shutdown,
# so we prevent these from being leaked and picked up by another OS in a dual boot or multi boot scenario
trap clear_networks_from_nvram EXIT
```

This didn't actually seem to work. While it's possible to clear the current-network variable by disconnecting from a Wi-Fi network (`sudo nvram -d current-network` doesn't work while still connected to Wi-Fi), deleting the preferred-networks variable is impossible without clearing all of the Preferred Networks from the list in System Preferences -> Network -> Wi-Fi -> Advanced. That's too rigorous, since that would mean having to manually connect (and authenticate) with Wi-Fi after each boot. I also tried to 'exhaust' the preferred-networks variable, by creating many bogus networks in the list of preferred networks with a lower index (higher on the list) as the network I don't want it to leak. But this didn't work, as the preferred-networks variable doesn't adhere to the index of the network in the Preferred Networks list. The most recently connected network will be stored as the first item in the preferred-networks NVRAM variable. So this means I have to settle for a cleanup job...