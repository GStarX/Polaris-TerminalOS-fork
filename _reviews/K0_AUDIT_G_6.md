# K0-01 内核现状独立审计（方案乙）

- 时间：2026-10-28（Asia/Shanghai）；方法：只读本地 Git/设备树、GitHub 固定提交及代码索引；未执行 adb、boot、刷写或构建。
- 范围：K0-01 与 K0-02 的证据边界。K2 候选裁决不在此报告中。

## 已确证

| 检查项 | 证据 | 结论 |
| --- | --- | --- |
| 本地输入版本 | `git -C C:\AiWork\Polaris-TerminalOS-repos\android_device_xiaomi_polaris rev-parse HEAD` → `d124800354524d2fd9660a757f11656404a13ea6`；本地主仓 `f02df16de1541d0cfe76fee9153385ec83bfc33a` | 审计对应这些本地版本；本地未拉取内核/公共设备树/blobs 全量仓库 |
| 内核、blobs HEAD | GitHub `get_commit` 对各仓 `lineage-22.2` 分支解析：内核 [`aa8adfe9bf212c6e93238a86980b4024da4f819a`](https://github.com/LineageOS/android_kernel_xiaomi_sdm845/commit/aa8adfe9bf212c6e93238a86980b4024da4f819a)；polaris blobs [`9e9707959acceea4b990cba733d259aab64c183e`](https://github.com/TheMuppets/proprietary_vendor_xiaomi_polaris/commit/9e9707959acceea4b990cba733d259aab64c183e)；common blobs [`b971b2ccd4cf66dede975cf645d01f4cbc203150`](https://github.com/TheMuppets/proprietary_vendor_xiaomi_sdm845-common/commit/b971b2ccd4cf66dede975cf645d01f4cbc203150) | 2026-10-28 查询仍与 `docs/00:30-33` 的 SHA 一致；**只能作为查询时快照** |
| 配置叠加 | 本地 `BoardConfig.mk:8,18-19,35` 先包含 common 配置，再追加 `vendor/xiaomi/polaris.config`，最后包含 blobs 的 `BoardConfigVendor.mk`；公共树 [`BoardConfigCommon.mk` @ `35cf356`](https://github.com/LineageOS/android_device_xiaomi_sdm845-common/blob/35cf356b095e033e71261b16c7fa319faac12cb3/BoardConfigCommon.mk) 的 GitHub 代码索引 blob `a8502d8cce27a54de16600e958b239ad0933d76e` 含 `TARGET_KERNEL_CONFIG := vendor/xiaomi/mi845_defconfig` 与 `TARGET_KERNEL_SOURCE := kernel/xiaomi/sdm845` | 配置是基础 defconfig + polaris 片段；还不是最终展开 `.config` |
| boot 构建声明 | 上述固定提交含 `BOARD_BOOT_HEADER_VERSION := 1`、`BOARD_KERNEL_BASE := 0x00000000`、`BOARD_KERNEL_IMAGE_NAME := Image.gz-dtb`、`BOARD_KERNEL_PAGESIZE := 4096`、`BOARD_MKBOOTIMG_ARGS += --header_version $(BOARD_BOOT_HEADER_VERSION)`；`BOARD_BOOTIMAGE_PARTITION_SIZE := 67092480` | 这是构建变量，不能直接宣称实际 boot 镜像 header、DTB 偏移与镜像内容。`Image.gz-dtb` 是 DTB 连接命名约定，不等于确认独立 dtbo.img |
| 非 A/B 声明 | 公共树 `AB_OTA_UPDATER := false`；本地 `device.mk:7` 继承 `non_ab_device.mk`；`BoardConfig.mk:25` recovery partition size `67108864` | 仅证明预期构建布局，不证明当前设备分区/活动槽 |
| manifest 版本界限 | `local_manifests/terminalos.xml:40-49` 将内核与两个 blobs 的 `revision` 写作 `lineage-22.2` | **分支级锁定，不是 commit pin**；需要构建时 `repo manifest -r` 和 `git rev-parse HEAD` 才可复现实际输入 |

## 待证 / 否证

- 待证：内核仓库中的 DTS/DTBO 规则、是否产出独立 `dtbo.img`、模块实际列表与 `vermagic`、编译器具体版本、vendor blob 的 `.ko`/ioctl/sysfs 绑定、`build/build.sh` 及镜像打包路径。当前没有完整源码 checkout、blobs 文件清单和构建输出；不能把搜索无结果当作“不存在”。
- 待证：运行内核版本与配置。官方 wiki 所称 Linux 4.9 仅指官方支持基线；当前机器可能运行不同系统，不能用源码 defconfig 代替 `/proc/config.gz`。Phase 0 设备证据只由首席采集。
- 已否证的表述：“`revision=lineage-22.2` 已锁到 `aa8adfe9…` 等固定 commit”；三个 revision 都是分支名。
- 设计与实现间的风险：`docs/09:26` 原先把 boot/dtbo 产物和构建参数列为未审，源码现可静态确定部分构建变量，但实际产物仍未证实。`docs/09` 已据此分开记录，避免错误地把构建配置视为硬件实测。

## K0-02 后续判定输入

1. Linux 构建机保留同一次构建的 `repo manifest -r`、内核 `.config`、编译器 `--version`、编译/打包日志、boot/dtbo/模块文件及 SHA-256。
2. 首席完成 Phase 0 后，确认设备及镜像来源；仅由首席读取 `uname -a`、`/proc/config.gz`（若不存在则记为不可用）及已验证来源的镜像头。不得在 Phase 0 前刷写。
3. 在**相同构建基线**比较源码展开 `.config` 与设备 config，再逐项核对 DTB/DTBO 和模块 `vermagic`；不同系统或不同 commit 的差异不得归因于内核升级。

验证：复读本地上述两份文件与 manifest，GitHub `get_commit(lineage-22.2)` 三次返回完整 SHA，GitHub 代码索引返回固定 blob 的关键变量；`git diff -- docs/09_内核升级评估_K0.md` 确认只变更 K0 部分。限制：GitHub 原文件下载接口在本环境只返回嵌入资源提示，raw HTTP 连接失败；故未声称完成公共树全部变量、内核全源码或 blobs 内容审计。
