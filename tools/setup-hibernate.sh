#!/usr/bin/env bash
# Lid closed -> sleep, and after 30 min asleep -> hibernate (power fully off, safe in a bag).
# For Btrfs root + GRUB + systemd initramfs (Arch/CachyOS). Run it yourself: it uses sudo.
# Steps: a disk swapfile big enough for RAM (zram can't hold a hibernation image), the resume
# location on the kernel command line, and logind/sleep settings. Re-running is safe.
set -euo pipefail
DELAY="${HIBERNATE_AFTER:-30min}"
ram_gb=$(awk '/MemTotal/ {print int($2/1048576)+1}' /proc/meminfo)
size="$((ram_gb + 4))g"

echo "== 1/4 swapfile /swap/swapfile ($size, used only for hibernation; zram stays first)"
if [ ! -e /swap/swapfile ]; then
    sudo btrfs subvolume create /swap
    sudo btrfs filesystem mkswapfile --size "$size" --uuid clear /swap/swapfile
fi
grep -q '^/swap/swapfile' /etc/fstab || echo '/swap/swapfile none swap defaults,pri=0 0 0' | sudo tee -a /etc/fstab >/dev/null
swapon --show=NAME | grep -q '^/swap/swapfile' || sudo swapon --priority 0 /swap/swapfile

echo "== 2/4 resume location on the kernel command line (GRUB)"
uuid=$(findmnt -no UUID -T /swap/swapfile)
offset=$(sudo btrfs inspect-internal map-swapfile -r /swap/swapfile)
args="resume=UUID=$uuid resume_offset=$offset"
if ! grep -q "resume_offset=$offset" /etc/default/grub; then
    sudo sed -i -E 's/ ?resume(_offset)?=[^ "]*//g' /etc/default/grub
    sudo sed -i -E "s/^(GRUB_CMDLINE_LINUX_DEFAULT=\"[^\"]*)\"/\1 $args\"/" /etc/default/grub
    sudo grub-mkconfig -o /boot/grub/grub.cfg
fi

echo "== 3/4 lid closed: sleep, then hibernate after $DELAY (on battery and plugged in)"
sudo mkdir -p /etc/systemd/logind.conf.d /etc/systemd/sleep.conf.d
printf '[Login]\nHandleLidSwitch=suspend-then-hibernate\nHandleLidSwitchExternalPower=suspend-then-hibernate\nHandleLidSwitchDocked=ignore\n' \
    | sudo tee /etc/systemd/logind.conf.d/ansai-lid.conf >/dev/null
printf '[Sleep]\nHibernateDelaySec=%s\n' "$DELAY" | sudo tee /etc/systemd/sleep.conf.d/ansai-hibernate.conf >/dev/null

echo "== 4/4 done. Reboot once so the kernel knows where to resume from, then test:"
echo "   systemctl hibernate        (save your work first; the laptop powers off and comes back where it was)"
echo "logind picks up the lid settings at the next boot (or: sudo systemctl kill -s HUP systemd-logind)."
