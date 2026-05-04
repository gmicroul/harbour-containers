#!/bin/bash
# LXC setup xfce4 or i3-gaps in Fedora-based distributions
# run as root inside a Fedora container, or use harbour-containers' xsession setup button

USER_NAME=$1
USER_UID=$2
DISTRO=$3

# Ensure /run/display symlink exists
ln -sf /mnt/display /run/display

# Source the configure_desktop function
source /mnt/guest/setups/configure_desktop.sh

# Choose default WM
sleep 3
printf '\033[1;32m[?] Choose [x]fce4 or [i]3 as window manager for this %s container (default=x): \033[0m' "${3^}" && read -r REPLY

# Check if user setup is required
if [ ! -d "/home/${USER_NAME}" ]
then
	# Add user without interaction
	printf "\033[0;36m[+] Creating new user '$USER_NAME'\033[0m\n"
	useradd -m -u $USER_UID $USER_NAME
	sleep 1
	printf "\033[0;33m[!] Please set a password for the new user.\033[0m\n"
	passwd $USER_NAME

	# Add android group inet for user
	echo "inet:x:3003:${USER_NAME}" >> /etc/group
	echo "net_raw:x:3004:${USER_NAME}" >> /etc/group
	echo "nameserver 8.8.8.8" >> /etc/resolv.conf

	# Fedora uses systemd-resolved, make DNS permanent
	dnf install -y systemd-resolved 2>/dev/null
	systemctl enable systemd-resolved 2>/dev/null

	sleep 5

	# Add user to wheel group for sudo
	usermod -aG wheel $USER_NAME
fi

# Install base utilities for selected WM and X setup
printf "\033[0;36m[+] Installing selected WM and base utilities…\033[0m\n"

install_packages() {
	case "$REPLY" in
		"i" | "i3")
			LAUNCHCMD="exec i3"
			dnf install -y \
				dbus-x11 \
				dconf \
				dmenu \
				dunst \
				firefox \
				fzf \
				hsetroot \
				i3 \
				i3blocks \
				i3lock \
				i3status \
				libbsd-devel \
				mpv \
				pavucontrol \
				rofi \
				rsync \
				rxvt-unicode \
				sudo \
				thunar \
				thunar-volman \
				tumbler \
				viewnior \
				wget \
				xclip \
				xdg-user-dirs \
				xfce4-terminal \
				xinit \
				xsel \
				xsettingsd \
				xorg-x11-server-Xorg \
				xorg-x11-xinit \
				yad \
				yt-dlp || err=1
			;;
		"x" | "xfce" | "xfce4" | "" | *)
			LAUNCHCMD="exec startxfce4"
			dnf install -y \
				dbus-x11 \
				dconf \
				dmenu \
				exo \
				firefox \
				garcon \
				mpv \
				pavucontrol \
				rsync \
				rxvt-unicode \
				sudo \
				thunar \
				thunar-volman \
				tumbler \
				viewnior \
				wget \
				xdg-user-dirs \
				xfce4-appfinder \
				xfce4-panel \
				xfce4-power-manager \
				xfce4-session \
				xfce4-settings \
				xfce4-terminal \
				xfconf \
				xfdesktop \
				xfwm4 \
				xinit \
				xorg-x11-server-Xorg \
				xorg-x11-xinit || err=1
			;;
	esac

	if [[ "$err" -eq "1" ]]; then
		printf "\033[0;33m\n[!] Error(s) encountered when installing base packages. This may be caused by an unstable Internet connection. [R]etry or [c]ontinue anyway? (default=c) \033[0m" && read -r RETRY

		case "$RETRY" in
			"r" | "R" | "retry" | "Retry" | "RETRY")
				printf "Retrying to install base packages…\n"
				echo "nameserver 8.8.8.8" >> /etc/resolv.conf
				sleep 2
				dnf clean all
				install_packages
			;;
			"c" | "C" | "continue" | "Continue" | "CONTINUE" | "" | *)
				printf "\033[0;33mIgnoring install error(s) and continuing to next step…\033[0m\n"
				sleep 2
			;;
		esac
	fi
}

install_packages

# Mask unused services
systemctl mask lightdm 2>/dev/null
systemctl mask upower 2>/dev/null
systemctl mask firewalld 2>/dev/null

# On Fedora, SELinux can interfere with Xwayland; set permissive inside container
if command -v setenforce &>/dev/null; then
	setenforce 0 2>/dev/null
	printf "\033[0;33m[!] SELinux set to permissive for Xwayland compatibility.\033[0m\n"
fi

# Install Xwayland from Fedora repository (prebuilt binary may not be compatible)
printf "\033[0;36m[+] Installing Xwayland from Fedora repository…\033[0m\n"
dnf install -y xorg-x11-server-Xwayland || printf "\033[0;33m[!] Xwayland install failed, trying alternative…\033[0m\n"

# Download older Xwayland binary compatible with qxcompositor (XDG-WM-Base)
printf "\033[0;36m[+] Fetching Xwayland compatible with qxcompositor…\033[0m\n"
ARCH=$(uname -m)
mkdir -p /opt/bin
wget https://github.com/sailfish-containers/xserver/releases/download/b1/Xwayland.${ARCH}.libc-2.27.bin \
	-O /opt/bin/Xwayland -nc -q --show-progress || printf "\033[0;33m[!] Xwayland download failed\033[0m\n"
chmod +x /opt/bin/Xwayland 2>/dev/null

# Link harbour-containers scripts
ln -s /mnt/guest/start_desktop.sh /opt/bin/start_desktop.sh 2> /dev/null
ln -s /mnt/guest/setup_desktop.sh /opt/bin/setup_desktop.sh 2> /dev/null
ln -s /mnt/guest/start_onboard.sh /opt/bin/start_onboard.sh 2> /dev/null
ln -s /mnt/guest/kill_xwayland.sh /opt/bin/kill_xwayland.sh 2> /dev/null

# Desktop configuration prompt
printf "\033[0;36m[+] Preconfiguring desktop with sane default settings…\033[0m\n"
if [ -e "/home/$USER_NAME/.config/i3/config" ] || [ -e "/home/$USER_NAME/.config/xfce4/xfconf/xfce-perchannel-xml" ]; then
	printf "\033[0;33m[!] This container seems to have been configured already (possibly manually). Overwrite with defaults? [y/N] \033[0m" && read -r ANSWER
	case "$ANSWER" in
		"y" | "yes" | "Y" | "Yes" | "Yes")
			configure_desktop $DISTRO
			printf "\033[0;32mDefault configuration re-applied.\033[0m\n"
		;;
		"n" | "no" | "N" | "No" | "NO" | "" | *)
			printf "\033[0;33mAborting desktop reconfiguration…\033[0m\n"
		;;
	esac
else
	configure_desktop $DISTRO
	printf "\033[0;32mDone.\033[0m\n"
fi

# Generate locales
printf "\033[0;36m[+] Generating en_GB.UTF-8 locale…\033[0m\n"
dnf install -y glibc-langpack-en 2>/dev/null
localectl set-locale LANG=en_GB.UTF-8 2>/dev/null || true

# Make audio work within container
printf "\033[0;36m[+] Setting up audio…\033[0m\n"
usermod -aG audio $USER_NAME

# Wrap up
printf "\033[1;32m[✔] Setup complete. Press [Return] to close this terminal window. If everything went well, you should be able to start X from the GUI.\033[0m\n"
read -r _

# Reboot the container
shutdown -h now