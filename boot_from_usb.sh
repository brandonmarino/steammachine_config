#!/bin/bash

# 1. Look for any active USB block storage (sda, sdb, etc.)
USB_DISK=$(lsblk -S -o NAME,TRAN | grep usb | awk '{print $1}' | head -n 1)

if [ -z "$USB_DISK" ]; then
    notify-send "Boot Error" "No physical USB drive detected. Please plug it in." --icon=drive-removable-media
    exit 1
fi

# 2. Extract the unique UUID of the first partition on that USB drive
USB_UUID=$(lsblk /dev/${USB_DISK}1 -no UUID | head -n 1)

if [ -z "$USB_UUID" ]; then
    # Fallback if partition 1 layout isn't standard; grab the first partition that has a UUID
    USB_UUID=$(lsblk /dev/$USB_DISK -no UUID | grep -v '^$' | head -n 1)
fi

if [ -z "$USB_UUID" ]; then
    notify-send "Boot Error" "USB found, but couldn't read its filesystem partition UUID." --icon=drive-removable-media
    exit 1
fi

echo "Targeting USB Partition UUID: $USB_UUID"
notify-send "USB Detected" "Setting GRUB to boot from USB on next restart..." --icon=drive-removable-media

# 3. Instruct GRUB to boot directly from this external storage block once.
# This forces the bootloader to search for the specific partition UUID and execute its EFI payload.
sudo grub-reboot "uuid:$USB_UUID" 2>/dev/null

# If grub-reboot fails or isn't supported by this specific immutable distro config,
# use the universal GRUB environmental variable fallback.
if [ $? -ne 0 ]; then
    sudo grub-editenv grubenv set next_entry="uuid:$USB_UUID"
fi

# Perform a clean system restart
sudo systemctl reboot
