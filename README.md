<p align="center">
  <img src="docs/assets/Woloong_Logo.png" alt="Woloong" height="88">
</p>

<h1 align="center">Woloong Kernel</h1>

<p align="center">
  <b>Woloong 定制内核 · Klipper / CAN 驱动内置</b><br>
  fork 自 ophub/kernel · 每月 1/16 日构建 · 版本号带 -Woloong
</p>

<p align="center">
  <a href="https://github.com/Woloong-DS/Woloong-OS">Woloong-OS</a> ·
  <a href="https://github.com/Woloong-DS/Woloong-amlogic-s9xxx-armbian">基础镜像</a> ·
  <a href="https://github.com/ophub/kernel">上游 ophub/kernel</a> ·
  <a href="README.en.md">English</a>
</p>

---

## 这是什么

本仓库是 **Woloong OS** 的定制内核构建仓库，fork 自 [ophub/kernel](https://github.com/ophub/kernel)。
构建产物供 [Woloong-amlogic-s9xxx-armbian](https://github.com/Woloong-DS/Woloong-amlogic-s9xxx-armbian) 打系统镜像时下载，也可在已装机上通过 `armbian-update` 在线升级。

设计目标只有一句话：**既能持续接收官方内核更新，又不会在更新中丢掉自己的定制。**

## 在 Woloong 栈中的位置

| 层 | 仓库 | 职责 |
|---|---|---|
| 内核 | **Woloong-kernel**（本仓库） | 内核配置、驱动、`-Woloong` 签名 |
| 基础镜像 | [Woloong-amlogic-s9xxx-armbian](https://github.com/Woloong-DS/Woloong-amlogic-s9xxx-armbian) | 在 Armbian 基础上产出可启动镜像 |
| 产品层 | [Woloong-OS](https://github.com/Woloong-DS/Woloong-OS) | 离线包、软件栈、置备与验收 |
| 运行时 | Woloong-kiauh（私有，随镜像提供） | 安装/卸载/更新/体检 |

## 目录

- [在 Woloong 栈中的位置](#在-woloong-栈中的位置)
- [这个仓库做了什么](#这个仓库做了什么)
- [构建产物与 Release](#构建产物与-release)
- [目录结构](#目录结构)
- [自动化编译](#自动化编译)
- [内核配置：接收官方更新而不丢定制](#内核配置接收官方更新而不丢定制)
- [设备端使用](#设备端使用)
- [与上游保持同步](#与上游保持同步)
- [常见问题](#常见问题)
- [文档与许可证](#文档与许可证)

## 这个仓库做了什么

相对上游 [ophub/kernel](https://github.com/ophub/kernel)，只做三件事：

| # | 定制 | 落点 |
|---|------|------|
| 1 | **品牌签名**：内核版本号带 `-Woloong`（如 `6.18.55-Woloong`） | `compile-mainline-stable-kernel.yml` 的 `kernel_sign` 默认值 |
| 2 | **功能保证**：Klipper / CAN 需要的配置项声明为"必需项"，官方配置更新后自动写回 | `kernel-config/required-options.conf` + `kernel-config/tools/sync-from-upstream.sh` |
| 3 | **自动化**：每月 1 日、16 日（UTC 20:00）自动编译并发布主线稳定内核 | `.github/workflows/compile-mainline-stable-kernel.yml` |

## 构建产物与 Release

所有主线稳定内核发布在 **[`kernel_stable`](../../releases/tag/kernel_stable)** 标签下：

| 产物 | 内容 | 用途 |
|------|------|------|
| `<版本>.tar.gz`（如 `6.18.55.tar.gz`） | 内核镜像 + 模块 + 设备树 | 镜像构建、`armbian-update` 升级 |
| `deb-<版本>.tar.gz` | `.deb` 安装包 | 手动 `dpkg -i` 安装 |

其余标签（`kernel_beta`、`kernel_flippy`、`kernel_rk3588`、`kernel_rk35xx`、`toolchain`、`tools`）沿用上游机制。

产物内版本名形如 `6.18.55-Woloong`，因此设备上 `uname -r` 可直接看出内核来源。

## 目录结构

```
.github/workflows/
├── compile-mainline-stable-kernel.yml   # 【已定制】主线稳定内核编译（含配置同步/校验/回写）
├── compile-mainline-beta-kernel.yml     # 主线测试内核（上游）
├── compile-rockchip-rk3588-kernel.yml   # RK3588 专用内核（上游）
├── compile-rockchip-rk35xx-kernel.yml   # RK35xx 专用内核（上游）
└── delete-older-releases-workflows.yml  # 清理旧 Release（上游）
kernel-config/
├── required-options.conf                # 【新增】必需项声明：SCOPE + 强制写回清单
├── tools/sync-from-upstream.sh          # 【新增】官方基线 + 强制写回必需项
└── release/stable/config-6.18           # 【已定制】官方基线 + CONFIG_LOCALVERSION="-Woloong"
kernel-patch/                            # 内核补丁集（上游）
```

## 自动化编译

### 定时构建

| 工作流 | cron (UTC) | 北京时间 | 说明 |
|--------|-----------|----------|------|
| Compile mainline stable kernel | `0 20 1,16 * *` | 每月 2 日、17 日 04:00 | 与镜像构建（8/23 日）错开半个月 |

> GitHub 的定时工作流在仓库连续 60 天无提交活动后会被自动停用，需要到 Actions 页面手动重新启用。

### 手动触发

`Actions → Compile mainline stable kernel → Run workflow`，主要参数：

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `kernel_source` | `ophub` | 内核源码仓库（`ophub/linux-x.y` 或 `unifreq/linux-x.y`） |
| `kernel_version` | `6.18.y` | 内核分支，`all` 会展开为 5.10/5.15/6.1/6.6/6.12/6.18 六版本矩阵 |
| `kernel_auto` | `true` | 自动使用该分支最新小版本（如 6.18.56） |
| `delete_source` | `true` | 编译后删除源码释放磁盘 |
| `kernel_package` | `all` | `all`=内核+模块+设备树；`dtbs`=只编译设备树 |
| `kernel_toolchain` | `gcc` | 工具链（`clang` / `gcc` / `gcc-15.3` …） |
| `ccache_clear` | `false` | 是否清空 ccache |
| `docker_image` | `bookworm` | 编译容器（Debian 12） |
| `kernel_sign` | `-Woloong` | 内核签名后缀，决定产物版本名 |
| `kernel_config` | `kernel-config/release/stable` | 自定义 `.config` 路径，`false` 表示不用 |
| `sync_config` | `true` | 编译前先从官方同步 config（官方基线 + 强制写回必需项） |

> **测试请用 `kernel_package=all`，不要用 `dtbs`。** `dtbs` 会生成与当前版本同号、但只含设备树的 Release 资产，`replaces_artifacts: true` 会直接覆盖镜像构建所需的内核包。

### 流水线步骤

1. **Checkout** —— 拉取本仓库。
2. **Sync kernel config from upstream** —— 调 `kernel-config/tools/sync-from-upstream.sh`，用官方基线覆盖 `config-<版本>` 并写回必需项。
3. **Initialize the build environment** —— 清理 runner 预装组件、安装编译依赖、统一 UTC 时间。
4. **Create virtual disk for extended storage** —— 用 `/root.img` + `losetup` 挂 xfs 到 `/builder`，解决编译所需大磁盘。
5. **Get kernel source commit hash** / **Cache ccache** —— 用源码 commit 作 ccache key。
6. **Verify kernel config** —— 校验必需项是否真的启用，缺失且在本版本范围内就**直接失败**，不让"静默退回官方配置"的空跑发生。
7. **Compile the kernel** —— 调 `ophub/amlogic-s9xxx-armbian@main`，`build_target: kernel`。
8. **Commit refreshed kernel config** —— 同步结果有变化就提交回仓库（`[skip ci]`）。
9. **Upload Kernel to Release** —— 产物上传到 `kernel_stable`。

## 内核配置：接收官方更新而不丢定制

这是本仓库相对上游的核心差异，思路是"**官方基线 + 必需项强制写回 + 编译前校验**"：

1. `kernel-config/required-options.conf` 声明必需项（`SCOPE=6.18` 限定生效范围）；
2. `kernel-config/tools/sync-from-upstream.sh` 克隆官方仓库，用其 `config-6.18` 覆盖本地模板，再**原地**把必需项改成声明值（存在则替换、`# ... is not set` 则替换、都没有则追加），最后自检；
3. 工作流编译前再校验一遍，缺项即失败；
4. 同步产生的变更自动提交回仓库，因此仓库里始终有一份"官方最新 + 我们的必需项"的配置可供 review。

### 当前必需项（`SCOPE=6.18`）

| 分类 | 配置项 |
|------|--------|
| CAN / SocketCAN（Klipper CAN 工具头） | `CAN` `CAN_RAW` `CAN_BCM` `CAN_GW` `CAN_DEV` `CAN_GS_USB`（均为 `=m`） |
| USB 串口（打印板 MCU / USB-CAN 盒） | `USB_ACM=m`、`USB_SERIAL=y`、`CH341` `CP210X` `FTDI_SIO` `PL2303`（`=y`） |
| 品牌标识 | `LOCALVERSION="-Woloong"` |
| 传感器 / 外设 | `SPI_SPIDEV=m`、`I2C_CHARDEV=y`、`PWM=y`、`HWMON=y` |

### 手动/本地同步

```bash
cd kernel-config/tools
./sync-from-upstream.sh          # 同步 SCOPE 声明的版本（默认 6.18）
./sync-from-upstream.sh 6.18     # 指定版本

# 可选环境变量
FLAVOR=stable UPSTREAM_REF=main UPSTREAM_REPO=https://github.com/ophub/kernel.git ./sync-from-upstream.sh 6.18
```

脚本幂等、可反复执行，结束后用 `git diff` 复核再提交即可。

## 设备端使用

```bash
# 升级到本仓库最新稳定内核（-r 指定内核仓库）
sudo armbian-update -k 6.18.y -u stable -r Woloong-DS/Woloong-kernel

# 校验
uname -r                      # 应为 6.18.xx-Woloong
grep -E '^(VERSION|VENDOR)' /etc/armbian-release
```

Klipper / CAN 相关（USB-CAN 适配器插上后）：

```bash
sudo modprobe gs_usb
ip -br link show can0
ls /lib/modules/"$(uname -r)"/kernel/drivers/net/can/usb/   # gs_usb.ko
```

## 与上游保持同步

```bash
git fetch upstream
git merge upstream/main
```

注意事项：

- **不要用浅克隆/部分克隆**（`--depth=1`、`--filter=blob:none`）后再推送，会出现 `did not receive expected object ... remote unpack failed`；需要完整克隆。
- 冲突点通常集中在 `.github/workflows/compile-mainline-stable-kernel.yml` 与 `kernel-config/release/stable/config-6.18`，解决原则是"保留 Woloong 定制（签名 / 必需项 / 调度）"。
- 上游若新增内核分支（例如 6.19），需要同步在 `required-options.conf` 的 `SCOPE`、工作流 `kernel_version` 选项、以及 `config-<版本>` 模板上补齐。

## 常见问题

**Q：Release 里下载下来的 config 中 `CONFIG_LOCALVERSION=""`，是不是签名丢了？**
不是。编译脚本会用 `kernel_sign` 以 make 变量 `LOCALVERSION` 的方式注入签名，同时清空配置文件里的该项，因此归档 config 显示为空属正常；产物版本名仍为 `6.18.xx-Woloong`。

**Q：只想临时改签名（例如节日主题）？**
把工作流的 `kernel_sign` 换成对应选项即可；若要让仓库模板长期一致，同时改 `required-options.conf` 里的 `CONFIG_LOCALVERSION`。

**Q：构建要多久 / 用什么 runner？**
`ubuntu-26.04-arm`（原生 arm64 编译），单版本约数小时，已用 ccache 缓存加速。

## 文档与许可证

- 上游英文文档（原 `README.md`，保留原始内容）：[`README.ophub.md`](README.ophub.md)
- 上游中文文档：[`README.cn.md`](README.cn.md)
- 本仓库英文说明：[`README.en.md`](README.en.md)
- 许可证：见 [`LICENSE`](LICENSE)（沿用上游）
