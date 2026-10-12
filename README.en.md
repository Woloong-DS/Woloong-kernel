# Woloong Kernel

[中文说明](README.md) | [English](README.en.md) | Upstream: [ophub/kernel](https://github.com/ophub/kernel)

Custom kernel build repository for **Woloong OS**, forked from [ophub/kernel](https://github.com/ophub/kernel).
Artifacts are consumed by [Woloong-DS/Woloong-amlogic-s9xxx-armbian](https://github.com/Woloong-DS/Woloong-amlogic-s9xxx-armbian) when building images, and by installed devices through `armbian-update`.

Design goal: **keep receiving official kernel updates without losing local customizations.**

## What this repository changes

| # | Customization | Location |
|---|---------------|----------|
| 1 | **Branded signature**: kernel version carries `-Woloong` (e.g. `6.18.55-Woloong`) | `kernel_sign` default in `compile-mainline-stable-kernel.yml` |
| 2 | **Guaranteed features**: options required by Klipper / CAN are declared and force-written back after each upstream config sync | `kernel-config/required-options.conf`, `kernel-config/tools/sync-from-upstream.sh` |
| 3 | **Automation**: builds and publishes a mainline stable kernel on the 1st and 16th of every month (20:00 UTC) | `.github/workflows/compile-mainline-stable-kernel.yml` |

## Artifacts

Published under the **`kernel_stable`** release tag:

| Asset | Contents | Used for |
|-------|----------|----------|
| `<version>.tar.gz` (e.g. `6.18.55.tar.gz`) | kernel image + modules + dtbs | image builds, `armbian-update` |
| `deb-<version>.tar.gz` | `.deb` packages | manual `dpkg -i` install |

The kernel release string is `6.18.xx-Woloong`, so `uname -r` reveals its origin.

## Layout

```
.github/workflows/compile-mainline-stable-kernel.yml   # customized stable kernel build
kernel-config/required-options.conf                    # added: required-options declaration
kernel-config/tools/sync-from-upstream.sh              # added: upstream baseline + force-write options
kernel-config/release/stable/config-6.18               # customized: official baseline + CONFIG_LOCALVERSION="-Woloong"
```

## Automation

- **Schedule**: `0 20 1,16 * *` (UTC) → 04:00 Beijing time on the 2nd and 17th, offset by half a month from image builds (8th/23rd).
- **Manual**: `Actions → Compile mainline stable kernel → Run workflow`. Key inputs: `kernel_version` (`6.18.y`, or `all` for a six-version matrix), `kernel_sign` (`-Woloong`), `kernel_config` (`kernel-config/release/stable`), `sync_config` (`true`).
- Use `kernel_package=all` for test runs — `dtbs` produces a same-version, dtbs-only asset which would replace the kernel package needed by image builds.

Pipeline: Checkout → **Sync kernel config from upstream** → Initialize environment → Create virtual disk → Get source hash / cache ccache → **Verify kernel config** → Compile kernel → **Commit refreshed config** (`[skip ci]`) → Upload to Release.

GitHub disables scheduled workflows after 60 days without repository activity; re-enable them from the Actions tab if needed.

## Config sync: upstream baseline + enforced options

1. `kernel-config/required-options.conf` declares the required options, scoped by `SCOPE=6.18`.
2. `kernel-config/tools/sync-from-upstream.sh` clones upstream, replaces the local `config-<version>` with the official baseline, then edits the required options **in place** (replace if present, replace `# ... is not set`, else append) and self-checks.
3. The workflow verifies the options again right before compiling and fails if any are missing within scope.
4. Any resulting change is committed back, so the repository always holds an "official latest + our options" configuration for review.

Required options currently enforced: `CONFIG_CAN*` (SocketCAN + `CAN_GS_USB`, all `=m`), USB serial (`USB_ACM=m`, `USB_SERIAL=y`, CH341/CP210X/FTDI_SIO/PL2303 `=y`), `CONFIG_LOCALVERSION="-Woloong"`, `SPI_SPIDEV=m`, `I2C_CHARDEV=y`, `PWM=y`, `HWMON=y`.

```bash
cd kernel-config/tools
./sync-from-upstream.sh 6.18        # idempotent; review with git diff afterwards
FLAVOR=stable UPSTREAM_REF=main ./sync-from-upstream.sh 6.18   # optional overrides
```

## On-device usage

```bash
sudo armbian-update -k 6.18.y -u stable -r Woloong-DS/Woloong-kernel
uname -r        # 6.18.xx-Woloong
sudo modprobe gs_usb && ip -br link show can0
```

## Staying in sync with upstream

```bash
git fetch upstream && git merge upstream/main
```

- Avoid shallow/partial clones (`--depth=1`, `--filter=blob:none`) when you need to push: they fail with `did not receive expected object ... remote unpack failed`.
- Conflicts normally land in `compile-mainline-stable-kernel.yml` and `release/stable/config-6.18`; resolve by keeping the Woloong customizations.
- When upstream adds a new kernel branch, extend `SCOPE`, the workflow's `kernel_version` options, and add the corresponding `config-<version>` template.

## Notes

- A downloaded config showing `CONFIG_LOCALVERSION=""` is expected: the build script injects the signature via the make variable `LOCALVERSION` and blanks the config entry. The artifact version still ends in `-Woloong`.
- Builds run on `ubuntu-26.04-arm` (native arm64) with ccache caching.

## Documentation & License

- Upstream English documentation (original `README.md`, preserved): [`README.ophub.md`](README.ophub.md)
- Upstream Chinese documentation: [`README.cn.md`](README.cn.md)
- License: see [`LICENSE`](LICENSE) (inherited from upstream)
