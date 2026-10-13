# 内核自定义配置说明（Woloong）

> 本文档由 Woloong 维护，替代上游同名说明：保留上游使用方法，并补充本项目的「必需项」机制。
> 相关文件：`required-options.conf`、`tools/sync-from-upstream.sh`、`../.github/workflows/compile-mainline-stable-kernel.yml`

## 1. 目录约定

    kernel-config/
    ├── release/<flavor>/config-<主版本>     每次编译使用的配置模板
    ├── required-options.conf                必须存在的编译选项声明（Woloong 机制）
    └── tools/sync-from-upstream.sh          以官方基线同步配置的工具

- `flavor`：`stable`（主线，供镜像工程使用）、`rk3588`、`rk35xx`（预留上游支持）。
- 配置文件以**主版本**命名：`config-6.18` 对应 6.18.y。
- 工作流传入的是**目录**而不是文件（例如 `kernel_config: kernel-config/release/stable`）；action 会把该目录下的 `config-*` 复制进编译环境。

现有配置（共 11 个）：

    rk3588  : config-5.10  config-6.1
    rk35xx  : config-5.10  config-6.1
    stable  : config-5.10  config-5.15  config-5.4  config-6.1  config-6.12  config-6.18  config-6.6

## 2. Woloong 必需项机制（本目录的核心）

`required-options.conf` 声明「编译时必须存在」的选项；文件顶部的 `SCOPE=6.18` 表示**只对 6.18 强制**校验与覆盖，其它版本仅告警。当前共 17 项：

    CAN / SocketCAN（Klipper CAN 工具头）：CONFIG_CAN=m、CONFIG_CAN_RAW=m、CONFIG_CAN_BCM=m、CONFIG_CAN_GW=m、CONFIG_CAN_DEV=m、CONFIG_CAN_GS_USB=m
    USB 串口（打印板 MCU / USB-CAN 盒）：CONFIG_USB_ACM=m、CONFIG_USB_SERIAL=y、CONFIG_USB_SERIAL_CH341=y、CONFIG_USB_SERIAL_CP210X=y、CONFIG_USB_SERIAL_FTDI_SIO=y、CONFIG_USB_SERIAL_PL2303=y
    品牌标识：CONFIG_LOCALVERSION="-Woloong"
    传感器 / 总线 / 风扇：CONFIG_SPI_SPIDEV=m、CONFIG_I2C_CHARDEV=y、CONFIG_PWM=y、CONFIG_HWMON=y

**为什么需要它**：上游配置会持续更新。必需项机制让「跟随上游」与「Klipper 能力不被上游改动冲掉」同时成立——官方基线照抄，必需项强制写回。

**本次核对结果**：`config-6.18` 与上游 `ophub/kernel` 同名文件相比**只差一行**（`CONFIG_LOCALVERSION="-Woloong"`），17 项必需项全部满足——即上游基线本就满足 Klipper 需求，此机制用于**防御未来变化**。

**维护铁律**：不要直接编辑 `config-*` 里的必需项。同步时官方基线会整份覆盖该文件，只有写进 `required-options.conf` 的项才会被强制保留。

## 3. 同步工具 tools/sync-from-upstream.sh

    ./tools/sync-from-upstream.sh            # 同步 SCOPE 声明的版本（当前 6.18）
    ./tools/sync-from-upstream.sh 6.18       # 指定版本
    UPSTREAM_REF=main ./tools/sync-from-upstream.sh 6.18

执行四步：

    1) 以官方 ophub/kernel 的 config-<版本> 为基线（git clone --depth=1）
    2) 整份覆盖 kernel-config/release/<flavor>/config-<版本>
    3) 原地写入必需项：已存在的键替换；「# CONFIG_X is not set」也替换；不存在的追加到文件末（带 # Woloong required 注释）
    4) 自检：任一必需项缺失即非零退出

可用环境变量覆盖默认值：`UPSTREAM_REPO`、`UPSTREAM_REF`、`FLAVOR`。脚本幂等，可反复执行。

## 4. CI 中的三步（compile-mainline-stable-kernel.yml）

| 步骤 | 行为 |
| --- | --- |
| Sync kernel config from upstream | 编译前自动执行同步工具（`sync_config` 为 true 时） |
| Verify kernel config | 校验 SCOPE 范围内的必需项是否真的生效；范围内缺配置文件则**直接失败** |
| Commit refreshed kernel config | 同步结果有变化时以 `github-actions[bot]` 提交并 push（消息 `chore(kernel): sync kernel config from upstream [skip ci]`） |

因此：仓库会自己产生配置提交；本地改动前先 `git fetch origin`，必要时 `git pull --rebase origin main`。

## 5. 新增一个内核版本的正确流程

1. 在 `required-options.conf` 的 `SCOPE` 中加入新版本（空格分隔，可多个）；
2. 生成配置模板：`FLAVOR=stable ./tools/sync-from-upstream.sh <新版本>`；
3. 按第 6 节逐项本地校验；
4. 提交并推送 `main`，再手动 dispatch stable 工作流验证；
5. 确认 Release 资产名仍为 `<内核版本>.tar.gz`（镜像侧契约，见第 7 节）。

## 6. 本地校验方法（等价 CI 的 Verify 步骤）

对 `required-options.conf` 中每一条 `CONFIG_X=Y`，在目标 `config-<版本>` 中查找 `CONFIG_X=`（或 `# CONFIG_X is not set`），两者必须**完全一致**；任一不符即视为失败。快速核对：

    while read -r line; do case "$line" in CONFIG_*) grep -qxF "$line" kernel-config/release/stable/config-6.18 || echo "缺失/不一致: $line";; esac; done < kernel-config/required-options.conf

## 7. 与镜像工程的契约

- 镜像工程默认 `kernel_repo=Woloong-DS/Woloong-kernel`、`kernel_usage=stable`，最终下载 `releases/download/kernel_stable/<内核版本>.tar.gz`；
- `CONFIG_LOCALVERSION="-Woloong"` 决定内核名后缀（产物形如 `6.18.56-Woloong`）；
- 改动以上两点时须同步镜像工程与内核工作流的 upload tag。

## 8. 当前状态与已知风险

1. `SCOPE=6.18` 只覆盖 6.18：其它版本的必需项仅告警，不强制。
2. `rk3588` / `rk35xx` 配置为**预留上游支持**，从未编译验证。
3. stable 工作流的 schedule 触发存在「空 inputs 未兜底」问题（详见工作区维护文档），尚未修复。

## English Summary

This directory holds the kernel configuration templates used by Woloong kernel builds. Besides upstream usage (`kernel_config: kernel-config/release/stable`), Woloong maintains `required-options.conf`: it declares the options required by Klipper (CAN/SocketCAN, USB serial, `CONFIG_LOCALVERSION="-Woloong"`, SPI/I2C/PWM/HWMON) and which kernel versions they are enforced for (`SCOPE`). `tools/sync-from-upstream.sh` takes the official ophub/kernel config as baseline and force-writes those options; the stable workflow syncs before compiling, verifies the result, and commits any change. Never edit the required options inside `config-*` directly - the next sync overwrites the file from the official baseline.
