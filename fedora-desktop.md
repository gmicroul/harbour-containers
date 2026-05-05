# Fedora Desktop 支持

为 harbour-containers 添加 Fedora 系列发行版的桌面环境支持。

## 适用版本

- Fedora 42+（arm64/aarch64）
- 理论上也支持 RHEL / CentOS（未测试）

## 新增/修改文件

### 新增文件

| 文件 | 说明 |
|---|---|
| `scripts/guest/setups/fedora.sh` | Fedora 版 desktop 安装脚本（dnf 包管理器） |
| `qml/images/container-fedora.png` | Fedora 容器图标（占位，可替换） |
| `scripts/guest/configs/Wallpapers/fedora-1.jpg` | 壁纸（暂用 Debian 壁纸替代） |
| `scripts/guest/configs/Wallpapers/fedora-2.jpg` | 壁纸 |
| `scripts/guest/configs/Wallpapers/fedora-3.jpg` | 壁纸 |

### 修改文件

| 文件 | 改动 |
|---|---|
| `scripts/guest/setup_desktop.sh` | 添加 `fedora / rhel / centos` → `DISTRO_VER=fedora` 映射 |
| `scripts/guest/setups/configure_desktop.sh` | i3/xfce4 壁纸选择分支加入 `fedora` |

## fedora.sh 关键细节

### 包管理器
`dnf install -y`（Fedora 42 默认 dnf5）

### 用户创建
- 用 `useradd -m -u`（Fedora 没有交互式 `adduser`）
- sudoers：Fedora 默认 wheel 组已在 sudoers，只需 `usermod -aG wheel`

### 包名映射（对比 Arch）

| 用途 | Arch | Fedora |
|---|---|---|
| X Server | xorg-server | xorg-x11-server-Xorg |
| X init | xorg-xinit | xorg-x11-xinit |
| i3 | i3-gaps | i3 |
| xfce4 | xfce4 | 逐包安装（无 group meta） |
| libbsd | libbsd | libbsd（运行时） + libbsd-devel |

### 已移除的包（Fedora 仓库无匹配）
- ~~onboard~~ / ~~florence~~ — 虚拟键盘会牵出 GNOME 网络栈依赖（wpa_supplicant、NetworkManager-wifi 等），容器内安装后与宿主 SFOS WiFi 管理冲突，导致 WiFi 断连且密码失效。暂不安装任何虚拟键盘。
- `xorg-x11-server-utils` — Fedora 42 无此包
- `mousetweaks` — Fedora 仓库无此包（脚本会静默跳过）

### DNS 问题
Fedora 使用 systemd-resolved，容器内 systemd-resolved 的 DNS stub listener（127.0.0.53:53）与 SFOS 宿主端口冲突。安装包触发 resolved 重启时会导致 WiFi DNS 解析异常。

解决方法（容器内 root 执行，一次性）：
```bash
cat > /etc/systemd/resolved.conf << 'EOF'
[Resolve]
DNS=8.8.8.8
DNSStubListener=no
EOF
systemctl restart systemd-resolved
echo "nameserver 8.8.8.8" > /etc/resolv.conf
```

### SELinux
脚本内执行 `setenforce 0` 防止干扰 Xwayland（容器内不影响宿主）。

### Xwayland
- 不使用 Fedora 自带的 Xwayland（不支持 qxcompositor 的 XDG-WM-Base 协议）
- 下载 sailfish-containers 预编译的 **libc-2.27** 版本（libc-2.29 在 Fedora 42 上兼容性不佳）

## 启动桌面（当前方案）

harbour-containers GUI 的一键 Start Xsession 暂不支持 Fedora。
需要两步手动启动：

**Terminal 1**（宿主，挂着别关）：
```bash
su -c "export XDG_RUNTIME_DIR=/run/user/100000 && /usr/share/harbour-containers/scripts/host/new_display.sh 88 100000 portrait" defaultuser
```

**Terminal 2**（宿主，新开 SSH）：
```bash
devel-su lxc-attach -n fedora -- su - user -c "killall Xwayland 2>/dev/null; rm -f /tmp/.X0-lock /tmp/.X11-unix/X0; export XDG_RUNTIME_DIR=/run/user/100000; export WAYLAND_DISPLAY=../../display/wayland-container-88; /opt/bin/Xwayland :0 -nolisten tcp & sleep 2; export DISPLAY=:0; xfce4-session &"
```

### 关闭桌面
Ctrl+C 关掉 Terminal 1（qxcompositor 停止），桌面自动退出。

## 已知问题

1. **GUI 一键启动不可用** — `new_display.sh` 被 harbour-containers daemon 调用时环境变量和 CWD 传递有问题，qxcompositor 闪退。需手动分两步启动。
2. **xauth 死锁** — Fedora 容器内 `xauth` 在 root 下锁 `/root/.serverauth.*` 卡住，容器内已改为 `su -p user -c "xinit /home/user/.xinitrc -- /opt/bin/Xwayland :0 -nolisten tcp -auth /dev/null"` 跳过 xauth。
3. **`.xinitrc` 语法** — Fedora 的默认 `.xinitrc` 有 `if...elif...else...fi` 结构，`configure_desktop.sh` 追加内容时破坏了 `fi`，导致 `syntax error: unexpected end of file`。需要手动写完整的 `.xinitrc`。
4. **Xwayland 软件渲染** — `Disabling glamor and dri3, EGL setup failed`，无硬件加速，仅软件渲染。

## 未完成事项

- [ ] 修复 GUI 一键启动（harbour-containers daemon 调用 `new_display.sh` 的环境变量问题）
- [ ] 寻找不引入 GNOME 网络栈依赖的虚拟键盘方案
- [ ] 真实的 Fedora 壁纸和容器图标
- [ ] xfce4 横竖屏自适应

## 测试环境

- 设备：OnePlus 6T (fajita)
- 宿主：Sailfish OS 5.0
- LXC 版本：5.0
- 容器架构：arm64 (aarch64)
- Fedora 版本：42

## fedora.sh 安装步骤（首次部署）

1. 创建 Fedora 42 arm64 容器（通过 harbour-containers GUI 或 `lxc-create`）
2. 启动容器，确保网络连通
3. SSH 进宿主机，进入容器：
   ```bash
   devel-su lxc-attach -n <容器名>
   ```
4. 修 DNS 并禁用 systemd-resolved stub 防止 WiFi 冲突：
   ```bash
   cat > /etc/systemd/resolved.conf << 'EOF'
   [Resolve]
   DNS=8.8.8.8
   DNSStubListener=no
   EOF
   systemctl restart systemd-resolved
   echo "nameserver 8.8.8.8" > /etc/resolv.conf
   ```
5. 在容器内执行安装脚本：
   ```bash
   bash /mnt/guest/setups/fedora.sh user 100000 fedora
   ```
6. **重启容器**（脚本最后会自动 `shutdown -h now`）
7. 修复 `.xinitrc`：
   ```bash
   bash /tmp/fedora_xinitrc_fix.sh
   ```
8. 手动两步启动桌面（见上文"启动桌面"章节）