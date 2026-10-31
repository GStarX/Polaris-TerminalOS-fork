# 系统预装精简候选清单（方案甲 · 设备层 + 镜像层共同输入）

- 状态：v1（待复核官定级、待首席设备侧实测确认）
- 产出人：方案甲（C_O5）
- 归档：本地 `_reviews/SLIM_CANDIDATES_C_O5.md`，未提交、未推送；由 GITHUB 代写进 fork

## 0. 证据与口径

| 项 | 值 | 来源 |
| --- | --- | --- |
| 设备实测基线 | **228 个系统包**（另 2 个第三方、1 个已禁用） | 首席抓取，`C:\AiWork\tmp\slim\polaris_22.2_system_packages.txt` |
| 构建标识 | `lineage_polaris-userdebug 15 BP1A.250505.005 ce1f8d46c3` | 同上，文件首行 |
| 上游预装来源 | `config/common.mk`、`config/common_mobile.mk`（49 项） | GITHUB 从 `android_vendor_lineage` `lineage-22.2` 提取 |
| 设备实测补充 | HOME 解析到 `org.terminalos.terminalhome/.MainActivity`；**Recents 仍由 `com.android.launcher3` 提供**；删 launcher3 会同时断掉「按 Home 回终端」链路 | 首席设备实测，禁删坐实 |
| 设备有、源码清单未列 | `org.lineageos.aperture`（相机）、`org.lineageos.etar`（日历）、`org.lineageos.twelve`（音乐）、`org.lineageos.recorder`、`org.lineageos.camelot`（浏览器）、`org.lineageos.audiofx`、`org.lineageos.profiles` | 首席设备实测；本清单已逐条纳入 |

**基线结构分解（我按设备实测文件统计，不是上游清单）**

| 类别 | 数量 |
| --- | --- |
| `auto_generated_rro_*`（运行时资源覆盖） | 29 |
| `com.android.theme.*`（图标包/图标形状/字体 RRO） | 32 |
| `org.lineageos.overlay.*` | 3 |
| `cutout.emulation.*`（开发者选项刘海模拟） | 5 |
| 其余功能包 | 162 |
| **合计** | **231 行 = 228 系统 + 2 第三方 + 1 已禁用** |

**证据强度声明（必须先讲清）**：包名、数量、分层比例来自**设备实测**；每个包「作用/依赖/删了会坏什么」来自 Android 15 平台结构 + 上游 `mk` 交叉，**未逐包在设备上验证**。所以 B 档不是保守，是**尚未证伪**——A 档也必须过一遍 T 项才能记为完成。

**命名层必须分开，否则禁删名单会写错**（GITHUB 的红线更正只对了一半）：

| 上游模块名 | 设备实际包名 |
| --- | --- |
| `TrebuchetQuickStep` / `TrebuchetQuickStepGo` | **`com.android.launcher3`**（Trebuchet 沿用 Launcher3 包名） |
| `LineageSettingsProvider` | `org.lineageos.lineagesettings` + `lineageos.platform` |
| `LineageParts` | `org.lineageos.lineageparts` |
| `LineageBlackTheme` | `org.lineageos.overlay.customization.blacktheme` |
| `ThemePicker` / `ThemesStub` | `com.android.customization.themes` |

镜像层写模块名，设备层写包名。两边混写会让 `pm` / `filter-out` 都对不上。

## 1. 三档定义与执行方式

| 档 | 定义 | 执行 | 可逆性 |
| --- | --- | --- | --- |
| **A 安全删** | 无框架依赖、无其他应用依赖，删了不影响开机与系统功能 | 设备层 `pm uninstall --user 0 <pkg>` | `cmd package install-existing <pkg>`，用户级，可逆 |
| **B 需测** | 可删但有跨模块依赖或功能影响，必须逐条实测通过才可动 | 同上，但每次只动 1 个并跑回归 | 同上 |
| **C 禁删** | 框架/通信/安全/项目强相关/overlay 与 RRO | 不允许 | —— |

设备层统一回退命令（下文不再重复）：
```
cmd package install-existing <包名>     # 恢复 uninstall --user 0
pm enable <包名>                        # 恢复 disable-user
```

## 2. A 档 · 安全删（建议首批执行）

| 包名 | 作用 | 依赖 / 删了会坏什么 |
| --- | --- | --- |
| `com.android.egg` | 系统彩蛋 | 无（仅设置内连点入口失效） |
| `com.android.dreams.basic` | 基础屏保 | 无 |
| `com.android.dreams.phototable` | 照片屏保 | 无 |
| `com.android.printspooler` | 打印后台 | 打印功能整体失效 |
| `com.android.printservice.recommendation` | 打印服务推荐 | 同上 |
| `com.android.bips` | 内置打印服务 | 同上 |
| `com.android.hotwordenrollment.okgoogle` | 热词注册（OK Google） | 无 GMS 时本就不工作 |
| `com.android.hotwordenrollment.xgoogle` | 热词注册 | 同上 |
| `com.google.android.apps.googlecamera.fishfood` | GCam 测试包（vendor blobs 带入） | 与 Aperture 相机无关；若要 GCam 则删此包前先确认别处来源 |
| `com.android.gallery3d` | AOSP 旧图库 | 默认图库是 `org.lineageos.glimpse`，无依赖 |
| `com.android.cts.ctsshim` | CTS 测试 shim | 仅影响 CTS 认证，不影响日常 |
| `com.android.cts.priv.ctsshim` | CTS 特权 shim | 同上 |
| `com.android.DeviceAsWebcam` | 手机当 USB 摄像头 | 该功能失效 |
| `com.android.companiondevicemanager` | 配套设备管理（手表等） | 该功能失效 |
| `com.android.bluetoothmidiservice` | BLE MIDI | MIDI 设备失效 |
| `com.android.simappdialog` | SIM 应用对话框 | 极小的 UI 缺失 |
| `com.android.htmlviewer` | HTML 查看器 | 打开本地 html 的兜底消失 |
| `com.android.calllogbackup` | 通话记录备份 | 备份里少通话记录 |
| `com.android.backupconfirm` | 备份确认对话框 | `adb backup` 交互缺失 |
| `com.android.wallpaperbackup` | 壁纸备份 | 备份里少壁纸 |
| `com.android.avatarpicker` | 头像选择器 | 联系人头像选择退化 |
| `com.android.virtualmachine.res` | 虚拟化资源（AVF） | resource-only，无 AVF 场景无影响 |
| `com.android.uwb.resources` | UWB 资源 | polaris 无 UWB 硬件 |
| `com.android.devicelockcontroller` | DeviceLock 控制器 | **当前已禁用**；删除只是清理 |
| `com.android.systemui.plugin.globalactions.wallet` | 电源菜单钱包按钮 | 无 GMS 时该按钮本就无效 |
| `com.android.internal.display.cutout.emulation.double/hole/tall/waterfall/corner` | 开发者选项刘海模拟（5 个） | 仅开发者选项失效 |
| `com.android.deskclock` | 时钟（闹钟/计时） | 用户级功能与应用小组件消失 |
| `com.android.calculator2` | 计算器 | 用户级功能消失 |
| `org.lineageos.recorder` | 录音机 | 用户级功能消失 |
| `org.lineageos.audiofx` | 音效（AudioFX） | 音效调节消失 |
| `org.lineageos.twelve` | 音乐播放器 | 用户级功能消失 |
| `org.lineageos.etar` | 日历 | 用户级功能消失 |
| `org.lineageos.backgrounds` | Lineage 壁纸合集 | 壁纸选择里少一组 |
| `org.lineageos.glimpse` | Lineage 图库 | 看图应用消失（注意：删了要留 `com.android.gallery3d` 或新图库） |
| `org.lineageos.jelly` / `org.lineageos.camelot` | 浏览器（新旧两代） | **两者只删其一，先确认哪个是默认处理者** |
| `com.android.messaging` | AOSP 短信 | 短信功能消失——需用户明确不要短信才可进 A 档 |
| `com.stevesoltys.seedvault` | Seedvault 备份 | 备份功能消失 |
| `org.calyxos.backup.contacts` | 联系人备份 | 同上 |
| `com.android.sharedstoragebackup` | 共享存储备份 | 备份范围缩小 |

## 3. B 档 · 需测（每条单独动、单独回归）

| 包名 | 作用 | 风险点 / 测什么 |
| --- | --- | --- |
| `com.android.managedprovisioning` | 设备所有者配置（DO） | **删了 DO 流程与 `dpm set-device-owner` 可能失效 → 锁定模式依赖它**；测 DO 设置与重启后保持 |
| `org.lineageos.setupwizard` | 首次开机向导 | 恢复出厂后是否卡在 SetupWizard；DO 预置场景是否需要禁用 |
| `org.lineageos.updater` | OTA 更新 | 删了没有系统更新入口（判据含 OTA，倾向保留） |
| `org.lineageos.profiles` | 系统配置文件 | 设置里配置文件入口是否崩 |
| `com.android.appsearch.apk` | 应用搜索（设置/桌面搜索） | 设置搜索、桌面搜索是否崩 |
| `com.android.rkpdapp` | 远程密钥配置（RKP/attestation） | 密钥证明是否仍工作（影响部分应用校验） |
| `com.android.sdksandbox` | SDK 沙盒宿主 | 若同时删 AdServices，需确认无框架引用 |
| `com.android.adservices.api` | 广告服务（隐私沙盒） | 无 GMS 场景应无用，但框架有引用，测开机与安装应用 |
| `com.android.federatedcompute.services` | 联邦计算 | 同上 |
| `com.android.ondevicepersonalization.services` | 端侧个性化 | 同上 |
| `com.android.healthconnect.controller` | 健康连接 | 无健康应用，测开机 |
| `com.android.health.connect.backuprestore` | 健康数据备份 | 同上 |
| `com.android.modulemetadata` | 模块元数据 | 主干模块依赖，倾向保留，测开机 |
| `com.android.dynsystem` | 动态系统更新（DSU） | 该功能消失，测设置入口 |
| `com.android.storagemanager` | 存储管理器 | 设置「存储」入口是否正常 |
| `com.android.photopicker` | 系统照片选择器 | 第三方应用选图是否崩（Android 13+ 大量应用依赖） |
| `com.android.credentialmanager` | 凭据管理器 | 应用登录/通行密钥是否异常 |
| `com.android.nfc` + `com.android.apps.tag` | NFC 与标签读写 | polaris 有 NFC；支付/门禁/标签功能消失 |
| `com.android.se` | Secure Element | 与 NFC 支付强相关，倾向保留 |
| `com.android.stk` / `com.android.smspush` / `com.android.ons` | SIM 工具箱 / WAP push / 运营商网络服务 | 运营商相关功能，测插卡与彩信 |
| `com.android.emergency` | 紧急信息 | 紧急拨号界面中的医疗信息，测拨号 |
| `com.android.cellbroadcastreceiver` + `.module` + `com.android.cellbroadcastservice` | 应急广播（地震/警报） | **法律与安全相关，倾向移入 C 档** |
| `com.android.bookmarkprovider` | 浏览器书签 provider | 与 Jelly/Camelot 联动，删浏览器再删它 |
| `com.android.wallpaper` / `com.android.wallpaper.livepicker` / `com.android.customization.themes` | 壁纸选择器 / 动态壁纸 / 主题选择器 | 设置壁纸与主题入口，测桌面 |
| `com.android.theme.*`（32 个） | 图标包/图标形状/字体 RRO | 主题选择器选项消失；测桌面图标与设置界面 |
| `org.lineageos.overlay.*`（3 个） | 字体、黑主题 RRO | 同上 |
| `com.android.internal.systemui.navbar.*`（gestural/threebutton/transparent） | 导航栏模式覆盖 | **项目要锁导航栏，动之前先问注入官** |
| `com.android.systemui.accessibility.accessibilitymenu` | 无障碍菜单 | 无障碍功能，倾向保留 |
| `com.android.cameraextensions` | 相机扩展控制 | Aperture 相机某些模式依赖 |
| `org.lineageos.aperture` | Lineage 相机 | 删了没有相机；终端优先设备可接受，但需用户确认 |
| `com.android.soundpicker` | 铃声选择器 | 设置铃声入口 |
| `com.android.localtransport` | 本地备份传输 | 备份/恢复流程 |
| `com.android.hotspot2.osulogin` | Passpoint 热点登录 | 公共 WiFi 场景 |
| `com.android.devicediagnostics` | 设备诊断 | 设置诊断入口 |
| `com.android.bluetooth` 之外的外设类无 | —— | —— |

## 3A. RRO / 主题覆盖专组（独立成组，不与普通应用混删）

**为什么单列**：这 64 个包不是应用，是**运行时资源覆盖（RRO）**，删错不会「少一个 App」，而是主题/图标/系统界面**直接崩或回退成默认样式**，且症状与包名不直观对应。设备实测占 228 个系统包的 **28%**，是体积与界面风险的主要来源，必须单独一组、单独判据。

| 子组 | 包 | 数量 | 档 | 判据 |
| --- | --- | --- | --- | --- |
| 图标包 RRO | `com.android.theme.icon_pack.{filled,rounded,circular,kai,sam,victor}.{android,launcher,settings,systemui}` | 24 | **B** | 主题选择器/桌面图标是否退回默认；逐个删 |
| 图标形状 RRO | `com.android.theme.icon.{teardrop,vessel,pebble,roundedrect,square,squircle,taperedrect}` | 7 | **B** | 桌面图标形状设置是否崩 |
| 字体 RRO | `com.android.theme.font.notoserifsource`、`org.lineageos.overlay.font.{rubik,lato}` | 3 | **B** | 字体切换是否崩；系统界面字体是否回默认 |
| 黑主题 | `org.lineageos.overlay.customization.blacktheme` | 1 | **B** | 深色主题是否仍可用 |
| 刘海模拟 | `com.android.internal.display.cutout.emulation.{double,hole,tall,waterfall,corner}` | 5 | **A** | 仅开发者选项失效，前面 A 档已列 |
| **自动生成 RRO** | 所有 `*.auto_generated_rro_product__` / `*.auto_generated_rro_vendor__` | **29** | **C 禁删** | 是产品/厂商配置覆盖，删了会丢 WiFi 资源、设置默认值、launcher3 配置等，**一律不动** |

RRO 专组统一回退：`cmd package install-existing <包名>`。**每次只删 1 个 RRO**，删完切一次主题、重启一次、看一次桌面与系统界面，再动下一个。



**框架与核心**：`android`、`android.ext.shared`、`android.ext.services`、`lineageos.platform`、`com.android.systemui`、`com.android.settings`、`com.android.settings.intelligence`、`com.android.webview`、`com.android.shell`、`com.android.packageinstaller`、`com.android.permissioncontroller`、`com.android.keychain`、`com.android.certinstaller`、`com.android.inputdevices`、`com.android.location.fused`、`com.android.statementservice`、`com.android.role.notes.enabled`、`com.android.modulemetadata`（暂列）

**桌面与 Recents**：`com.android.launcher3`、`com.android.launcher3.overlay`、`com.android.launcher3.auto_generated_rro_product__`——设备实测 Recents 由 `com.android.launcher3` 提供，且锁任务模式下「按 Home 回终端」依赖它；**删了坐实破坏锁定模式链路**。

**存储与文件**：`com.android.externalstorage`、`com.android.providers.media`、`com.android.providers.media.module`、`com.android.providers.downloads`、`com.android.providers.downloads.ui`、`com.android.documentsui`、`com.android.mtp`、`com.android.intentresolver`

**通信**：`com.android.phone`、`com.android.server.telecom`、`com.android.providers.telephony`、`com.android.mms.service`、`com.android.carrierconfig`、`com.android.carrierdefaultapp`、`com.android.imsserviceentitlement`、`org.codeaurora.ims`、`vendor.qti.iwlan`、`com.qualcomm.qti.telephonyservice`、`com.qualcomm.qcrilmsgtunnel`、`com.qualcomm.qti.cne`、`com.qualcomm.qti.uceShimService`、`com.qualcomm.wfd.service`、`com.qualcomm.timeservice`、`com.qti.dpmserviceapp`、`com.qualcomm.qti.poweroffalarm`

**网络**：`com.android.networkstack`、`com.android.networkstack.tethering`、`com.android.networkstack.overlay`、`com.android.connectivity.resources`、`com.android.wifi.resources`、`com.android.wifi.resources.polaris`、`com.android.wifi.resources.xiaomi_sdm845`、`com.android.wifi.dialog`、`com.android.vpndialogs`、`com.android.pacprocessor`、`com.android.proxyhandler`、`com.android.captiveportallogin`

**联系人/日历 provider**：`com.android.providers.contacts`、`com.android.providers.calendar`、`com.android.providers.blockednumber`、`com.android.providers.userdictionary`、`com.android.providers.contactkeys`、`com.android.providers.settings`

**生物识别/认证**：`com.tencent.soter.soterserver`、`org.ifaa.aidl.manager`（指纹支付与认证）

**设置集成**：`org.lineageos.lineageparts`、`org.lineageos.lineagesettings`、`org.lineageos.settings`、`org.lineageos.settingsconfig`、`org.protonaosp.deviceconfig`、`com.android.server.deviceconfig.resources`、`com.android.safetycenter.resources`

**输入法**：`com.android.inputmethod.latin`（Termux/proot 的输入依赖）

**项目相关**：`com.android.managedprovisioning`（DO/锁定模式，从 B 档上移的建议见 §6）、`org.terminalos.terminalhome`、`com.termux`（第三方，红线）

**RRO/overlay（29 + 全部 `auto_generated_rro_*`）**：所有 `*.auto_generated_rro_product__` / `_vendor__` 一律禁删

## 5. 判据（二值，可复跑）

**设备层（每条候选单独过一次）**

1. 执行后：`pm list packages --user 0 | grep <pkg>` 为空；`pm list packages -u -s | grep <pkg>` 仍有 → 证明「对用户移除、系统分区在」，可回退。
2. 重启后重复第 1 条，仍成立（只当场生效不算）。
3. 回退演练：`cmd package install-existing <pkg>` 后包在 `--user 0` 重新可见。
4. 回归通过：T01/T02/T03/T04/T09/T11 + 通知 + Recents + OTA 入口；每删一个跑一次，不允许批量删再跑。
5. 记录：包名 + 删除时间 + 回退命令 + 回归结果，进 `evidence/`。

**RRO 专组追加判据（与普通应用不同，必须单跑）**

1. 每次只删 **1 个** RRO；删后切换一次主题、重启一次、看桌面与系统界面各一次。
2. 30 秒内 `logcat` 无 `Resources$NotFoundException` 与主题/资源相关的 `FATAL EXCEPTION`。
3. 主题选择器仍能打开、能切回默认、能再切回去。
4. 全部 RRO 处理完后**重跑一遍 T 项**——RRO 的问题常延迟到切换主题或重启才暴露，删的当下不报。
5. `*.auto_generated_rro_*` 一个都不进候选，发现被删立即 `install-existing` 并记为违规。

**镜像层（等 runner 与 build-rom 首次产物）**

1. `filter-out` 后产物内无该包：`unzip -l` 产物或解包 `system/` 下搜 apk。
2. 产物包清单 diff 与候选清单**逐条一致**，不允许「顺手多删」。
3. 首次可启动 + 上述回归项通过 + OTA 可装。
4. 回滚：`filter-out` 提交必须单独 commit，可 `git revert`；不得与其它改动混提。

## 6. 未闭口（需他人决策）

1. **`filter-out` 技术路线**：`terminalos.mk` 现写明「不使用 PRODUCT_PACKAGES 的移除技巧」，要改这个约定 → 复核官裁决。
2. **`com.android.managedprovisioning` 归属**：我倾向从 B 档上移 C 档（DO 依赖），请复核官定。
3. **`com.android.cellbroadcast*` 归属**：我倾向 C 档（法律/安全），请复核官定。
4. **默认浏览器二选一**：`org.lineageos.jelly` 与 `org.lineageos.camelot` 哪个是 22.2 默认处理者，需设备实测确认后再删另一个（首席侧一条 `cmd package resolve-activity` 即可判定）。
5. **短信是否保留**：`com.android.messaging` 删除属于产品决策，不是技术风险。
6. **A 档也不是零风险**：本清单的「作用/依赖」未逐包设备验证，A 档只是「理论上无依赖」，仍需按 §5 逐条回归。
7. **RRO 专组由谁执行**：设备操作只能首席做；64 个 RRO 若逐个「删-切主题-重启」，按每个 3 分钟估算 ≈ 3 小时，需要机动窗口，或者分两批（图标包 24 个先做，形状/字体/黑主题 11 个后做）。
