# K2-03 模块 ABI 与 vendor 接口评估（方案乙）

- 时间：2026-10-28（Asia/Shanghai）
- 输入（一手）：`C:\AiWork\Polaris-TerminalOS-repos\android_device_xiaomi_polaris\proprietary-files.txt`（263 条，MIUI V12.0.3.0.QDGMIXM）、同仓 `manifest.xml`、`init/fstab.qcom`；`TheMuppets/proprietary_vendor_xiaomi_sdm845-common` @ `b971b2ccd4cf66dede975cf645d01f4cbc203150` 的 `sdm845-common-vendor.mk`；两棵只读稀疏克隆——4.9 下游 `LineageOS/android_kernel_xiaomi_sdm845` @ `aa8adfe9bf212c6e93238a86980b4024da4f819a`，mainline `torvalds/linux` @ `v5.10` = `2c85ebc57b3e1817b6ce1a6b703928e113a90442`
- 范围：只做「内核接口 ↔ 闭源 HAL」的 ABI 对照与失效判定。不裁决版本（K2-04 属复核官）、不建构建、不碰设备、不刷写。
- 方法：只读源码与清单；每条结论给「文件 + 符号」定位。无法判定的一律标 `待证`，**全文不写「应该兼容」**。

---

## 0. 可判定问题的答案（复核官 §4.1 第 3 条）

**问题**：假设 5.10 树可用，哪几个闭源 HAL 会因接口不匹配而失效？逐一点名并计数。

**答：点名 5 类，5 类全部失效（5/5）。** 不是「部分风险」，是**整体不可用**：每一类的内核接口在 5.10 侧都不存在，或虽同名但 ioctl 编号/结构体完全不同。

| # | 闭源 HAL | 失效根因（一句话） | 判定级 |
| --- | --- | --- | --- |
| 1 | FastRPC / ADSP（`libSuperSensor_skel.so`、`libarcsoft_dualcam_refocus_skel.so`、`adsprpcd`/`libadsprpc`） | `/dev/adsprpc-smd` 不存在；5.10 是 `/dev/fastrpc-*`，且 `'R'` 1–8 号 ioctl 与 4.9 的 1–15 号**同号不同义** | 确证 |
| 2 | SSC 传感器（`sensors.ssc.so` + `libqmi_cci`/`libqmi_client_qmux`） | QMI 承载的 `smd_pkt`/`glink_pkt` 字符设备在 5.10 无对应物，只有 `rpmsg_char`（不同 ABI） | 确证（传输具体为哪条标待证，见 §3） |
| 3 | CamX 相机（`camera.qcom.so`、`com.qti.chi.override.so`、`com.qti.sensor.*.so`） | `include/uapi/media/cam_*.h`、`cam_sync_device`、req_mgr 全部无对应；mainline CAMSS 是另一套 V4L2 驱动 | 确证 |
| 4 | QSEECOM（`keymaster@3.0-service-qti`、`secure_element@1.0-service`、`qseecomd`/`libQSEEComAPI`） | `/dev/qseecom` 与 `QSEECOM_IOCTL_*` 在 5.10 完全不存在 | 确证 |
| 5 | ICE（`fstab.qcom` 的 `fileencryption=ice`） | `iceufs`/`icesdcc` 字符设备与 `qseecomi.h` 的 TZ syscall 路径不存在 | 确证 |

**前提限定（重要，防止过度外推）**：这里的「5.10 树」只能是 mainline/GKI 5.10——无公开 SDM845 5.10 下游树。若有人主张「高通 CAF msm-5.10 里这些 ABI 还在」，那是**另一个未被公开证据支持的假设**，须先给出可访问仓库 + commit 再谈，本文不为其背书。

> **⚠ 适用范围修正（2026-10-28 追加，见 §6）**：本节 5/5 结论**只适用于 mainline/GKI 5.10**。方案甲发现的 `meuira/android_kernel_xiaomi_sdm845_419`（Linux 4.19.325）是**Android 下游树**，我独立核到它保留了同一套 QTI 驱动与同名节点，**因此「换内核 = 闭源 HAL 全废」不能外推到 4.19**。4.19 的逐项判定见 §6。

---

## 1. 主表（列固定为复核官 §4.1 第 4 条要求）

| HAL 文件 | 依赖的内核接口 | 4.9 现状 | 5.10 目标 | 差异 | 闭源? | 结论 |
| --- | --- | --- | --- | --- | --- | --- |
| `vendor/lib/rfsa/adsp/libSuperSensor_skel.so`（polaris:21）、`libarcsoft_dualcam_refocus_skel.so`（:22）、`libHalSuperSensorServer.so`（:120）；common blobs `libadsprpc`/`libcdsprpc`/`adsprpcd`/`cdsprpcd` | FastRPC 字符设备 + ioctl + ION 共享内存 | `/dev/adsprpc-smd`（`adsprpc_shared.h` `DEVICE_NAME "adsprpc-smd"`，另有 `-secure`）；ioctl `FASTRPC_IOCTL_INVOKE`=`_IOWR('R',1,…)`、MMAP=2、MUNMAP=3、INVOKE_FD=4、SETMODE=5、INIT=6、INVOKE_ATTRS=7、GETINFO=8、GETPERF=9、INIT_ATTRS=10、INVOKE_CRC=11、CONTROL=12、MUNMAP_FD=13、MMAP_64=14、MUNMAP_64=15；`adsprpc.c` include `<linux/msm_ion.h>`、调 `ion_import_dma_buf_fd`/`ion_handle_get_flags` | `drivers/misc/fastrpc.c` + `include/uapi/misc/fastrpc.h`：`FASTRPC_DEVICE_NAME "fastrpc"`，miscdev 名 `fastrpc-%s`；ioctl ALLOC_DMA_BUFF=`'R',1`、FREE_DMA_BUFF=2、INVOKE=3、INIT_ATTACH=4、INIT_CREATE=5、MMAP=6、MUNMAP=7、INIT_ATTACH_SNS=8 | **设备节点名不同**；**同一 `'R'` 魔数下 1–8 号语义被整体重排**（4.9 的 INVOKE 在 5.10 是 ALLOC_DMA_BUFF），旧 `libadsprpc` 不会得到干净 ENOTTY，而是**错配到别的 handler**；无 `msm_ion`（5.10 只有通用 staging ion，无 `linux/msm_ion.h`） | 是 | **失效**。改 HAL 不成立：这是节点+ioctl+内存模型三处同时断，需换整套 QTI FastRPC 用户态，而 SDM845 无公开 5.10 版本可换 |
| `vendor/lib64/sensors.ssc.so`（polaris:247）、`sensors.elliptic.so`、`sensors.touch.so`；common blobs `libqmi_cci`、`libqmi_client_qmux`、`libqmi_common_so`、`libsns_fastRPC_util` | QMI/QMUX 承载的 SMD 或 GLINK 字符设备 | 下游同时存在两条候选承载：`drivers/char/msm_smd_pkt.c`（`DEVICE_NAME "smdpkt"`，class `smd_pkt`）与 `drivers/soc/qcom/msm_glink_pkt.c`；另有 `drivers/soc/qcom/smd.c`、`glink.c` | 无 `msm_smd_pkt`、无 `msm_glink_pkt`；只有 `drivers/rpmsg/qcom_glink_native.c`/`qcom_smd.c` + `drivers/rpmsg/rpmsg_char.c`（`/dev/rpmsg*` 另一套字符 ABI） | 承载层整体被 rpmsg 框架替换，字符设备名与读写语义均不同；`libqmi_cci` 的 QMUX 传输打不开原节点 | 是 | **失效**。具体走 smd_pkt 还是 glink_pkt 需 blobs `strings` 确认（见 §3），但**两条在 5.10 都不存在**，结论不受影响 |
| `vendor/lib/hw/camera.qcom.so`、`com.qti.chi.override.so`、`vendor/lib/camera/com.qti.sensor.{imx363,ov5675,s5k3m3}.so`、`com.qti.stats.*`、`com.arcsoft.node.*` | msm camera UAPI：req_mgr + cam_sync + V4L2 扩展 ioctl | `drivers/media/platform/msm/camera/`（`cam_req_mgr/`、`cam_sync/` 等）；UAPI `include/uapi/media/cam_*.h`、`msm_camera.h`（`MSM_CAM_IOCTL_MAGIC 'm'`，含 `MSM_CAM_IOCTL_GET_SENSOR_INFO`/`CONFIG_VFE` 等）；`cam_sync.h` 定义 `CAM_SYNC_DEVICE_NAME "cam_sync_device"` + `V4L2_EVENT_PRIVATE_START` 私有事件 | `include/uapi/media/` **文件数 0**，无任何 `cam_*`/`msm_camera.h`；`drivers/media/platform/qcom/camss/*` 是 mainline V4L2 子设备驱动，不实现 CamX 的 ioctl/事件 | CamX 依赖的私有 ioctl 号、同步对象、私有 V4L2 事件**全部消失**；CAMSS 是「另一种相机驱动」，不是「兼容实现」 | 是 | **失效**。CamX 无任何 fallback，除非重写相机 HAL（等于换相机栈） |
| `vendor/bin/hw/android.hardware.keymaster@3.0-service-qti`（polaris:226）、`android.hardware.keymaster@3.0-impl-qti.so`（:228）、`vendor/bin/hw/vendor.qti.secure_element@1.0-service`（:239）、`android.hardware.secure_element@1.0-impl.so`（:241）；common blobs `libQSEEComAPI`、`qseecomd`、`qseecomd.rc` | QSEECom 字符设备 + ioctl；TZ（SCM）调用 | `drivers/misc/qseecom.c`（`QSEECOM_DEV "qseecom"`）；UAPI `include/uapi/linux/qseecom.h`：`QSEECOM_IOCTL_REGISTER_LISTENER_REQ`、`SEND_CMD_REQ`、`SEND_MODFD_CMD_REQ`、`RECEIVE_REQ`、`SEND_RESP_REQ`、`LOAD_APP_REQ`、`SET_MEM_PARAM_REQ`、`UNLOAD_APP_REQ`、`GET_QSEOS_VERSION_REQ` 等 | 全树无 `qseecom`（`git ls-tree | grep qseecom` 0 命中） | 设备节点、ioctl 集合、`qseecomd` 守护进程依赖的 TZ 通信全部不存在 | 是 | **失效**。Keymaster 3.0 与 Secure Element 1.0 两个 HIDL 服务都起不来（`manifest.xml:3-20` 声明的正是这两个） |
| `fstab.qcom` userdata 行 `fileencryption=ice`；内核 `drivers/crypto/msm/ice.c` | ICE 字符设备 + TZ key 编程 | `ice.c` 定义 `QCOM_UFS_ICE_DEV "iceufs"`、`QCOM_SDCC_ICE_DEV "icesdcc"`，含 `struct cdev`；include `<soc/qcom/qseecomi.h>`，走 `TZ_SYSCALL_CREATE_SMC_ID(TZ_OWNER_QSEE_OS, TZ_SVC_KEYSTORE, …)` | 无 `iceufs`/`icesdcc`、无 `drivers/crypto/msm/ice.c`；5.10 的块层加密是 blk-crypto/`ufshcd` 路径，与本设备 4.9 的 ICE 实现不同源 | 加密密钥下发路径（QSEE TZ syscall）+ 字符设备双断；`fileencryption=ice` 在 5.10 无对应实现 | 否（内核侧） | **失效**（影响的是 `/data` 加密启动，等于开不了机到可用状态）。此条「闭源」列填否：断的是内核实现，但用户态 `vold`/keymaster 仍依赖它 |

> 「闭源?」一列严格按 blobs 清单判：`.so`/`.bin`/服务端二进制 = 是；`ice` 属内核源码 = 否。**不把「0 个 `.ko`」当作不需要评估的理由**——见 §2，恰恰相反。

---

## 2. 「模块 ABI」这一项到底是什么（回应复核官 §4.1 第 5 条）

我自己复算了 E9：polaris `proprietary-files.txt` 中 `.ko$` = **0**；common blobs 的 `sdm845-common-vendor.mk` 里 `lib/modules`/`.ko` = **0**。

由此得到 K2-03 的关键结构判断，而不是「无需评估」：

1. **本项目不存在「内核模块 ABI」这个东西**：厂商驱动全部编译进内核镜像本体（`Image.gz-dtb`），没有任何 `.ko` 供 `insmod`，也就没有 `vermagic`/符号版本可谈。**K2-03 的「模块 ABI」部分结论是 N/A（0 个模块）**，但这不是免检理由。
2. 真正的 ABI 面只有两层：**(a) 内核内置驱动源码本身**（换树即全部重编，等价于全部重写/重移植）；**(b) 用户态 ↔ 内核的字符设备/ioctl**——这正是 §1 五类失效所在。
3. 因此「换 5.10」不是「把驱动编译一下」，而是「内核内置驱动 + 闭源 HAL 用户态必须同时替换」。而 SDM845 的 5.10 用户态闭源 HAL 没有公开来源，这就是 5/5 失效不可修的根因。

---

## 3. 未确证 / 待证（不得当成已确认）

| 项 | 状态 | 需要什么证据 |
| --- | --- | --- |
| SSC 走 `smd_pkt` 还是 `glink_pkt` | **待证**（不影响失效结论：两条 5.10 都没有） | 需 blobs 实仓（本地未 checkout）对 `sensors.ssc.so`/`libqmi_cci` 做 `strings`，找 `/dev/smd_pkt*` 或 `/dev/glink*` 字面量 |
| `keymaster@3.0`/`secure_element@1.0` 与 `/dev/qseecom` 的调用链 | **强证据但未到指令级**：`libQSEEComAPI` + `qseecomd` 与两个 HIDL 服务同属 QTI 闭源栈，`qseecomd` 即 QSEE 通道守护进程 | 需 blobs `readelf -d`/`strings` 证明 `*-impl-qti.so` 动态链接 `libQSEEComAPI` |
| CAF `msm-5.10` 是否存在且保留上述 ABI | **未确证，且无公开入口**。K2-01 已证公开 SDM845 4.19 是空壳、无 5.10 下游树 | 可访问仓库 URL + 分支 + commit；无此三项不得写入裁决 |
| 5.10 上是否有等价替代实现（如 dma-buf heaps 版 fastrpc、rpmsg_char 版 QMI 客户端） | **存在「另一种实现」，但都不兼容 4.9 闭源 HAL** | 需厂商侧给出 SDM845 5.10 版 HAL；目前无公开来源 |

---

## 4. 对 K2-04 的作用（交复核官）

`K2_04_VERDICT_GC.md` §5.4 原先把「换内核 = 整套闭源 HAL 报废」建立在 `0 个 .ko` + 面板无驱动两条上。K2-03 现在把它升级为**逐项可点名的失效清单**：

- 5 类依赖内核接口的闭源 HAL，**5 类全部失效**，每类给出节点名/ioctl 集/差异类型；
- 失效不是因为「没适配」，而是 5.10 上**接口本体不存在**（`/dev/qseecom`、`/dev/adsprpc-smd`、`cam_*` UAPI、`smd_pkt`/`glink_pkt`、`iceufs`），且无公开的 SDM845 5.10 闭源 HAL 可替换；
- 这与 E8（面板无驱动）互相独立：即使面板问题被解决，本表 5 项仍全部成立。

**结论**：K2-04「维持 4.9.337」的 §5.4 理由可据此改写为「E8 + K2-03 五类 HAL 接口 5/5 失效」。本报告不改变裁决方向，只补齐它的 ABI 依据。

---

## 5. 复现入口

```powershell
# 两棵只读树（blobless + sparse，约几分钟）
git clone --filter=blob:none --sparse --depth 1 -b lineage-22.2 `
  https://github.com/LineageOS/android_kernel_xiaomi_sdm845 C:\AiWork\tmp\k49
git -C C:\AiWork\tmp\k49 rev-parse HEAD      # aa8adfe9bf212c6e93238a86980b4024da4f819a
git clone --filter=blob:none --sparse --depth 1 -b v5.10 `
  https://github.com/torvalds/linux C:\AiWork\tmp\k510
git -C C:\AiWork\tmp\k510 rev-parse HEAD     # 2c85ebc57b3e1817b6ce1a6b703928e113a90442

# 4.9 侧接口
git -C C:\AiWork\tmp\k49 show HEAD:drivers/char/adsprpc_shared.h | Select-String 'FASTRPC_IOCTL|DEVICE_NAME'
git -C C:\AiWork\tmp\k49 show HEAD:drivers/char/adsprpc.c       | Select-String 'msm_ion|ion_import'
git -C C:\AiWork\tmp\k49 show HEAD:drivers/misc/qseecom.c       | Select-String 'QSEECOM_DEV'
git -C C:\AiWork\tmp\k49 show HEAD:include/uapi/linux/qseecom.h | Select-String 'QSEECOM_IOCTL'
git -C C:\AiWork\tmp\k49 show HEAD:drivers/crypto/msm/ice.c     | Select-String 'ICE_DEV|qseecomi'
git -C C:\AiWork\tmp\k49 ls-tree -r HEAD --name-only | Select-String 'camera/cam_req_mgr|camera/cam_sync|msm_smd_pkt|msm_glink_pkt'

# 5.10 对照
git -C C:\AiWork\tmp\k510 show HEAD:include/uapi/misc/fastrpc.h | Select-String 'FASTRPC_IOCTL|DEVICE'
git -C C:\AiWork\tmp\k510 ls-tree -r HEAD --name-only | Select-String 'qseecom|msm_ion|smd_pkt|glink_pkt|soc/qcom/ice'
(git -C C:\AiWork\tmp\k510 ls-tree -r HEAD --name-only -- include/uapi/media | Measure-Object).Count   # 0

# 本地 blobs 计数（我复算 E9）
$d='C:\AiWork\Polaris-TerminalOS-repos\android_device_xiaomi_polaris\proprietary-files.txt'
(Select-String -LiteralPath $d -Pattern '\.ko$').Count    # 0
```

写入范围：本文件。未跑构建、未碰设备、未改任何实现或其他人的文档。

---

## 6. 4.19 下游附录（meuira 树，复核官 §4.1 扩展要求）

- 核验对象：`meuira/android_kernel_xiaomi_sdm845_419`，分支 `lineage-23.2_xiaomi`，HEAD `5cd18f0867338fb22a497bd8e8c881b13a7d857e`（blobless/no-checkout 克隆，`git show` 按需取 blob）
- 我独立复现：`Makefile` = `VERSION 4 / PATCHLEVEL 19 / SUBLEVEL 325`；`arch/arm64/boot/dts/xiaomi/polaris/` 下 **43 个 DTS**。与方案甲一致。
- **判定方法**：按复核官要求比「HAL 引用的常量/结构体/节点名是否仍在且语义一致」，不比「文件是否存在」。

### 6.1 五类 HAL 在 4.19 上的接口身份

| HAL 文件 | 依赖的内核接口 | 4.9 现状 | 4.19 目标(meuira) | 差异 | 闭源? | 结论 |
| --- | --- | --- | --- | --- | --- | --- |
| FastRPC/ADSP（`libSuperSensor_skel.so`、`libarcsoft_dualcam_refocus_skel.so`、`adsprpcd`） | `/dev/adsprpc-smd` + `FASTRPC_IOCTL_*` | `DEVICE_NAME "adsprpc-smd"`/`-secure`；`INVOKE`=`'R',1`、`MMAP`=2、`MUNMAP`=3、`INVOKE_FD`=4、`SETMODE`=5、`INIT`=6 | **全部 16 条 `FASTRPC_IOCTL_*` 宏两树逐条相同（16 vs 16，差集为空）**；`fastrpc_ioctl_invoke`、`_init` 逐字段相同；`fastrpc_ioctl_control` union 成员有变（去 `smmu`、加 `wakelock`/`pm`），但 **union 仍 8 B、结构体仍 12 B → ioctl 号不变**；`fastrpc_ctrl_latency` 字段名 `level`→`latency`，**同尺寸** | 编号/尺寸级**全等**；语义级仅 CONTROL 的 SMMU 请求处理方式不同，不影响主数据路径 | 是 | **保持**（编号+尺寸级确证）。4.19 上 FastRPC 不构成失效理由 |
| SSC 传感器（`sensors.ssc.so` + `libqmi_cci`/`libqmi_client_qmux`） | QMI 承载：`smd_pkt` / `glink_pkt` | `msm_smd_pkt.c`：`DEVICE_NAME "smdpkt"`，`class_create(…, "smdpkt")` | **`drivers/char/msm_smd_pkt.c` 仍在，`DEVICE_NAME "smdpkt"` 相同** | 未发现节点级差异 | 是 | **保持**（节点名级）。QMI 读写语义未到字节级验证 |
| CamX 相机（`camera.qcom.so`、`com.qti.chi.override.so`、`com.qti.sensor.*`） | msm camera ioctl + techpack `cam_*` uapi | `include/uapi/media/msm_camera.h` 83 条 `MSM_CAM_IOCTL_*`；`cam_req_mgr.h` 34 条 `CAM_REQ_MGR_*` | `msm_camera.h` **83 条，与 4.9 宏集合差集为空**（逐条相同）；`techpack/camera/.../cam_req_mgr.h` 36 条，4.9 侧唯一缺少项为 `CAM_REQ_MGR_MAX_HANDLES`，其余为新增 | 旧 ioctl 层**全等**；`cam_*` techpack 层有新增/少量变动 | 是 | **大幅收窄风险，但未完全排除**：宏名级全等不等于结构体尺寸全等；需对 CamX 实际调用的 `cam_isp`/`cam_sensor` 结构体逐字段比对（待证） |
| QSEECOM（`keymaster@3.0-service-qti`、`vendor.qti.secure_element@1.0-service`、`qseecomd`） | `/dev/qseecom` + `QSEECOM_IOCTL_*` | `QSEECOM_DEV "qseecom"`；`include/uapi/linux/qseecom.h` 的 `REGISTER_LISTENER_REQ`/`SEND_CMD_REQ`/`SEND_MODFD_CMD_REQ`/`RECEIVE_REQ`/`SEND_RESP_REQ` 等 | **`drivers/misc/qseecom.c` 仍在，`QSEECOM_DEV "qseecom"` 相同；uapi 前 6 条关键 ioctl 宏名逐条一致** | 未发现节点/宏名差异 | 是 | **保持**（节点+宏名级；结构体尺寸未到字节级，未做全量宏差集） |
| ICE（`fileencryption=ice`） | `iceufs`/`icesdcc` + QSEE TZ syscall | `QCOM_UFS_ICE_DEV "iceufs"`、`QCOM_SDCC_ICE_DEV "icesdcc"` | **同名保留**，另**新增** `QCOM_UFS_CARD_ICE_DEV "iceufscard"` | 仅新增设备，不改旧设备名；TZ key 下发路径未逐行核对 | 否（内核侧） | **保持**（设备名级） |

### 6.2 可判定问题的答案（4.19 版本）

**问题**：假设 4.19 树可用，哪几个闭源 HAL 会因 uapi 不匹配而失效？逐一点名并计数。

**答：在已核到的证据范围内，5 类中 0 类「确证失效」。** 精确分层：

| 级别 | 数量 | 对象 |
| --- | --- | --- |
| 结构体字段级保持 | 1 | FastRPC/ADSP（`fastrpc_ioctl_invoke`/`_init` 逐字段相同） |
| 节点名/宏名级保持，数值未验 | 3 | SSC（`smdpkt`）、QSEECOM（`/dev/qseecom` + ioctl 名）、ICE（`iceufs`/`icesdcc`） |
| 有差异、风险未排除 | 1 | CamX（`msm_camera.h` 83 条全等，但 techpack `cam_*` 结构体未逐字段比对） |
| 确证失效 | **0** | — |

**再加上复核官点名的三项非五类接口（2026-10-28 追加核查，证据见 §6.3）**：

| 接口 | 结论 | 级别 |
| --- | --- | --- |
| `sde_drm`（Composer HAL 直接吃） | **结构性差异确证**：`sde_drm.h` 仅新增 57 行、删 1 行，但既有 `struct sde_drm_scaler_v2` **新增 8 个 `uint32_t` 字段（+32 B）**；`SDE_DRM_BLEND_OP_MAX` 4→5 并插入 `SDE_DRM_BLEND_OP_LAYER_COLOR=4`（既有枚举值未改）；新增 `SDE_DRM_QSEED3LITE`/`QSEED4`/`INLINE_PREDOWNSCALE` 等标志 | **条件失效**：HAL 若按 4.9 的 v2 尺寸传该属性 blob，4.19 侧尺寸校验会拒绝；HAL 是否使用 `scaler_v2` 待证（需 blobs 反汇编） |
| `techpack/audio` apr/slate | **不构成 HAL uapi**：APR 是内核内部 IPC（`techpack/audio/ipc/apr.c`、`include/ipc/apr.h`），音频 HAL 实际走 ALSA/tinyalsa（`/dev/snd/*`）；两棵树 `include/uapi/linux/msm_audio.h` 宏定义 **138 vs 138，4.9-only = 0**（全保留），4.19 另加 `ipc/aprv2_vm.h`（虚拟化，不改旧路径） | **保持**（并纠正：把 APR 当 HAL uapi 是层级错位） |
| `drivers/power/supply/qcom` 属性名 | **不是超集，有删除**：`POWER_SUPPLY_PROP_*` 4.9 有 185、4.19 有 220，其中 **7 个 4.9 属性在 4.19 不存在**：`ALLOW_HVDCP3`、`MAX_PULSE_ALLOWED`、`IGNORE_FALSE_NEGATIVE_ISENSE`、`BATTERY_INFO`、`BATTERY_INFO_ID`、`ENABLE_JEITA_DETECTION`、`QG_VBMS_MODE`；4.19 新增 42 个；`qcom` 电源驱动 56→63 文件 | **条件失效**：sysfs 按属性名访问，健康/充电 HAL 若读上述 7 个名字即失败；其余新增不影响旧名 |

**这是对我上一版口径的收窄，必须写清**：我在 §0 说「换内核 = 整套闭源 HAL 报废」，该结论只在 **mainline/GKI 5.10** 成立；在 **Android 下游 4.19** 上，五类接口的载体（节点名、ioctl 宏、关键结构体）基本原样保留，**K2-03 不能用来否 4.19 路线**。K2-04 若仍维持 4.9，理由必须换成别的东西（无构建/无启动证据、单点维护、Android 16 与 4.19 的其余配套），不能引用我这份 5/5。

### 6.3 复核官点名的四项接口：逐项核查结果（2026-10-28）

| 项 | 状态 | 证据 / 说明 |
| --- | --- | --- |
| `techpack/display` 的 `sde_drm` uapi | **已核，结构性差异确证** | 两棵树都是 `include/uapi/drm/sde_drm.h`（不是 techpack/display 下）；diff = +57/−1 行；12 个 `struct` 名称两树相同；唯一尺寸变化是 `struct sde_drm_scaler_v2` **尾部新增 8×`uint32_t`（dir_weight、unsharp_mask_blend、de_blend、flags、pre_downscale_x/y_0/1）= +32 B**；`SDE_DRM_BLEND_OP_MAX` 4→5。**结论：4.9 版 Composer HAL 若用 v2 属性，尺寸不匹配；HAL 实际调用待证** |
| `techpack/audio` 的 apr/slate | **已核，保持；且该问法层级错位** | APR 在内核内部（`techpack/audio/ipc/apr.c`、`include/ipc/apr.h`），`slate` 是 SLPI 子系统（4.19 有 `arch/arm64/boot/dts/vendor/bindings/pil/subsys-pil-slate.txt`），二者都不是 `vendor/lib64/hw/*.so` 直接吃的 uapi；音频 HAL 走 ALSA/tinyalsa。uapi 侧 `msm_audio.h` 宏 **138 vs 138、4.9-only=0** |
| `techpack/camera` 的 ioctl | **部分已核（宏名级保持）** | 4.9 `include/uapi/media/msm_camera.h` 与 4.19 同名文件：**83 条 `MSM_CAM_IOCTL_*`/`VIDIOC_MSM_*` 宏，差集为空**；`cam_req_mgr.h` 34→36，4.9 侧仅缺 `CAM_REQ_MGR_MAX_HANDLES`。**结构体尺寸（`cam_isp`/`cam_sensor`）未逐字段比对 → 仍为待证** |
| `drivers/power/supply/qcom` 属性名 | **已核，不是超集** | `POWER_SUPPLY_PROP_*`：4.9=185、4.19=220；**4.9-only 共 7 个**（点名见 §6.2）；4.19 新增 42 个；驱动文件 56→63。sysfs 按名访问 → 只有引用这 7 个名的 HAL 会失败 |

### 6.3b 4.19 上仍未验证、且不属于「五类 HAL」范围的风险

| 项 | 状态 | 说明 |
| --- | --- | --- |
| CamX 的 `cam_*` 结构体尺寸 | **待证** | 宏名已全等，但 `cam_isp`/`cam_sensor`/`cam_req_mgr` 结构体未逐字段比对；这是五类里唯一未闭合项 |
| 设备树 binding 与 4.9 DTS 迁移 | **未核（超出 K2-03）** | 43 个 polaris DTS 是搬进 4.19 的；binding 差异属 K2-01/K2-02 范畴 |
| 4.19 树能否为 polaris 编出可启动镜像 | **无任何证据** | K2-03 只判 uapi，不判能否构建/启动；这是 4.19 PoC 的真正门槛 |

### 6.4 复现

```powershell
git clone --filter=blob:none --no-checkout --depth 1 -b lineage-23.2_xiaomi `
  https://github.com/meuira/android_kernel_xiaomi_sdm845_419 C:\AiWork\tmp\k419
git -C C:\AiWork\tmp\k419 rev-parse HEAD        # 5cd18f0867338fb22a497bd8e8c881b13a7d857e
git -C C:\AiWork\tmp\k419 show HEAD:Makefile | Select-String '^VERSION|^PATCHLEVEL|^SUBLEVEL'
(git -C C:\AiWork\tmp\k419 ls-tree -r HEAD --name-only | Select-String 'boot/dts/xiaomi/polaris/').Count  # 43
git -C C:\AiWork\tmp\k419 show HEAD:drivers/char/adsprpc_shared.h | Select-String 'FASTRPC_IOCTL_|DEVICE_NAME'
git -C C:\AiWork\tmp\k419 show HEAD:drivers/char/msm_smd_pkt.c   | Select-String 'DEVICE_NAME'
git -C C:\AiWork\tmp\k419 show HEAD:drivers/misc/qseecom.c       | Select-String 'QSEECOM_DEV'
git -C C:\AiWork\tmp\k419 show HEAD:drivers/crypto/msm/ice.c     | Select-String 'ICE_DEV'
# 相机 ioctl 宏集合差集为空（83 vs 83）
# display：+57/-1 行，scaler_v2 +8×u32
git -C C:\AiWork\tmp\k419 diff --no-index C:\AiWork\tmp\cmp\sde49.h C:\AiWork\tmp\cmp\sde419.h
# power_supply：4.9-only 7 个属性
git -C C:\AiWork\tmp\k419 show HEAD:include/linux/power_supply.h | Select-String 'POWER_SUPPLY_PROP_'
# audio：msm_audio.h 宏 138 vs 138
git -C C:\AiWork\tmp\k419 show HEAD:techpack/audio/include/uapi/linux/msm_audio.h | Select-String '^#define'
```

