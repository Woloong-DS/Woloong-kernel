# 内核补丁使用说明（Woloong）

> 本文档由 Woloong 维护，替代上游同名说明：保留上游目录约定与用法，并记录本项目补丁的实际状态。

## 1. 目录约定与作用范围

    kernel-patch/
    ├── beta/
    │   ├── common-kernel-patches/   固定名：适用于所有内核系列的通用补丁
    │   ├── linux-<版本>.y/           与内核源码仓库同名：该系列专用补丁
    │   └── deprecated-patches/       已弃用补丁留档：编译时**被跳过**，不会应用

- 目录名称必须与内核源码仓库同名（如 `linux-6.1.y`、`linux-5.10.y-rk35xx`）才会被匹配；
- 其它自定义名称的目录一律跳过（`deprecated-patches` 依赖这一规则实现「只留档不生效」）；
- 编译时先应用 `common-kernel-patches` 下的全部 `.patch`，再应用当前编译系列的专用补丁。

## 2. 现有补丁（共 21 个）

| 目录 | 数量 | 内容 |
| --- | --- | --- |
| `beta/common-kernel-patches` | 1 | RK3399 mpc1903 设备树（通用） |
| `beta/deprecated-patches` | 16 | 历史补丁留档 16 个：arm64 text_offset、ssv6051 wifi 驱动、按 SoC 拆分的 dts 补丁（6.18.y-301~309）、alark35-3500 dts 等 |
| `beta/linux-5.15.y` | 2 | meson venc 支持 ws7.9、RK3399 cdhx-rb30 设备树 |
| `beta/linux-6.1.y` | 1 | 修复 i2ca/i2cb 引脚缺失 |
| `beta/linux-6.6.y` | 1 | 修复 i2ca/i2cb 引脚缺失 |

命名约定：现行补丁用 `NNN-描述.patch`（观察到的前缀分类：`2xx` 驱动、`3xx` 设备树）；`deprecated-patches` 内的历史补丁带版本前缀（如 `6.18.y-101-arm64-add-text_offset.patch`）。

## 3. 用法（目前只有 beta 工作流会传补丁）

`compile-mainline-beta-kernel.yml` 的编译步骤（第 221-238 行）：

    kernel_config: ${{ inputs.kernel_config }}
    kernel_patch:  ${{ inputs.kernel_patch }}      # 默认 kernel-patch/beta
    auto_patch:    ${{ inputs.auto_patch }}        # 默认 true

**stable / rk3588 / rk35xx 三条流水线不传 `kernel_patch`**（它们与上游逐字节相同），因此改补丁不影响主线内核，只在 beta 流水线验证。

## 4. 新增 / 弃用补丁的规范

1. 放对目录：通用补丁 → `common-kernel-patches/`；某系列专用 → `linux-<版本>.y/`；
2. 命名带序号与简短说明（`NNN-描述.patch`），便于定位；
3. 提交前自检格式：`git -C . apply --stat -- kernel-patch/.../xxx.patch`（不需内核树，仅校验补丁可解析）；
4. 弃用补丁：移入 `deprecated-patches/` 并在提交信息中说明原因——该目录编译时被跳过，天然「留档不生效」。

## 5. 当前状态与风险

1. **beta 流水线从未运行过**（预留上游支持），因此现有 21 个补丁均**未经实战编译验证**；本次仅完成格式校验（21/21 通过 `git apply --stat`）。
2. `deprecated-patches` 中 `6.18.y-304/305/306-*.patch` 三个文件是**混合行尾**（上游遗留）。**不要「修复」它们**，否则产生无意义 diff，并可能影响补丁应用。
3. beta 的 `kernel_source` 形如 `xxx@branch`（带分支），与 stable 的写法不同，跨流水线复用补丁时注意。

## English Summary

Patch directories are matched by name: `common-kernel-patches` applies to every kernel series, `linux-<version>.y` only to that series, and any other directory name (such as `deprecated-patches`) is skipped during compilation. Only the beta workflow passes `kernel_patch`/`auto_patch`, so patches never affect the stable kernel used by the image project. The beta workflow has never been run, so the current patches are format-checked but not compile-tested.
