#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""TerminalOS 验收静态预检（无设备、无构建产物、无 JDK 依赖）。

用途
====
在 Phase 0 / 构建机就绪之前，对"能在仓库层证明"的验收前置做**可执行**检查，
把"构建通过了才算"里的结构性缺陷（组件声明缺失、限流参数被改大、PIN 明文落盘、
资源引用拼错导致编译失败等）在仓库阶段就暴露出来。

定位（必须诚实）
================
本脚本只做 static precondition checks。它**不能**替代实物判定：
  - 不能证明 Android 系统会按预期解析 manifest（需 aapt2/构建 + 实机）；
  - 不能证明锁任务/快捷设置/Device Owner 的真实运行行为（需实机，T01-T20）；
  - 检查是"文本结构断言"，对重构敏感；若实现重构，应同步更新断言而不是删断言。

用法
====
  python acceptance/static_checks.py --root C:\\AiWork\\Polaris-TerminalOS-repos
  python acceptance/static_checks.py --root <repos> --mutation-test
  python acceptance/static_checks.py --root <repos> --check S05 --verbose

退出码：0 = 全部通过（或变异全部被检出一致）；1 = 有失败。

变异自检（--mutation-test）
===========================
把三个仓库复制到临时目录，逐个注入"历史缺陷/常见缺陷"，断言对应检查必须
由 PASS 变 FAIL。若某个变异没被检出，说明该断言没有牙齿，按失败处理。
这样"检查通过"才有意义：我们证明过它会红。
"""

import argparse
import os
import re
import shutil
import sys
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path

HOME_REPO = "android_packages_apps_TerminalHome"
VENDOR_REPO = "android_vendor_terminalos"
DEVICE_REPO = "android_device_xiaomi_polaris"
REPOS = [HOME_REPO, VENDOR_REPO, DEVICE_REPO]

# ---------------------------------------------------------------------------
# 基础设施
# ---------------------------------------------------------------------------


class Ctx:
    def __init__(self, root: Path):
        self.root = root
        self.home = root / HOME_REPO
        self.vendor = root / VENDOR_REPO
        self.device = root / DEVICE_REPO

    def p(self, rel: str) -> Path:
        """home 仓库内相对路径。"""
        return self.home / rel

    def v(self, rel: str) -> Path:
        return self.vendor / rel

    def d(self, rel: str) -> Path:
        return self.device / rel


def read_text(path: Path) -> str:
    if not path.is_file():
        raise FileNotFoundError("文件不存在: %s" % path)
    return path.read_text(encoding="utf-8", errors="replace")


def read_java(ctx: Ctx, name: str) -> str:
    return read_text(ctx.p("src/org/terminalos/terminalhome/%s.java" % name))


def extract_body(text: str, sig_regex: str):
    """按 '{' '}' 配对取出方法体；找不到返回 None。"""
    m = re.search(sig_regex, text, re.S)
    if not m:
        return None
    start = text.find("{", m.start())
    if start < 0:
        return None
    depth = 0
    for i in range(start, len(text)):
        c = text[i]
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return text[start:i + 1]
    return None


def java_int_const(text: str, name: str):
    """解析 Java 数值常量，支持 10L * 60L * 1000L 与下划线。"""
    m = re.search(r"\b%s\s*=\s*([^;]+);" % re.escape(name), text)
    if not m:
        return None
    expr = m.group(1)
    try:
        total = 1
        for part in expr.split("*"):
            token = part.strip().replace("_", "").rstrip("Ll")
            total *= int(token)
        return total
    except ValueError:
        return None


def call_args_count(text: str, open_paren: int):
    """从 '(' 起配对，返回顶层逗号数（=参数个数-1）；括号不闭合返回 None。"""
    depth = 0
    commas = 0
    for i in range(open_paren, len(text)):
        c = text[i]
        if c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
            if depth == 0:
                return commas
        elif c == "," and depth == 1:
            commas += 1
    return None


def find_open_paren(text: str, start_hint: int) -> int:
    for i in range(start_hint, len(text)):
        if text[i] == "(":
            return i
    return -1


def strip_java_comments(text: str) -> str:
    """粗暴去掉 // 行注释与 /* */ 块注释，用于"注释里提到某 API"不算调用的断言。"""
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    return re.sub(r"//[^\n]*", "", text)


class Result:
    def __init__(self):
        self.rows = []  # (assertion_name, ok, detail)
        self.notes = []

    def ok(self, name, detail=""):
        self.rows.append((name, True, detail))

    def fail(self, name, detail=""):
        self.rows.append((name, False, detail))

    def check(self, name, condition, detail=""):
        if condition:
            self.ok(name, detail)
        else:
            self.fail(name, detail)
        return bool(condition)

    def note(self, text):
        self.notes.append(text)

    @property
    def passed(self):
        return all(ok for _, ok, _ in self.rows)


# ---------------------------------------------------------------------------
# 检查项：每项对应验收矩阵里的用例前置/替代验证
# ---------------------------------------------------------------------------


def s01_home_manifest(ctx: Ctx, r: Result):
    """T01/T02/T03/T13：HOME 组件与维护组件声明契约。"""
    text = read_text(ctx.p("AndroidManifest.xml"))
    blocks = re.findall(r"<activity\b(?:[^>]*/>|[^>]*>.*?</activity>)", text, re.S)

    def activity_block(simple_name):
        for b in blocks:
            if 'android:name=".%s"' % simple_name in b:
                return b
        return None

    main = activity_block("MainActivity")
    r.check("manifest.MainActivity 存在", main is not None)
    if main:
        r.check("HOME 过滤: ACTION_MAIN", "android.intent.action.MAIN" in main)
        r.check("HOME 过滤: CATEGORY_HOME",
                "android.intent.category.HOME" in main,
                "缺 HOME 类别会导致系统不把 TerminalHome 当桌面候选")
        r.check("HOME 过滤: CATEGORY_DEFAULT",
                "android.intent.category.DEFAULT" in main)
        r.check("exported=true", 'android:exported="true"' in main)
        r.check("launchMode=singleTask",
                'android:launchMode="singleTask"' in main)
        r.check("excludeFromRecents=true",
                'android:excludeFromRecents="true"' in main)

    maint = activity_block("MaintenanceActivity")
    r.check("manifest.MaintenanceActivity 存在", maint is not None)
    if maint:
        r.check("维护界面 exported=false", 'android:exported="false"' in maint,
                "维护入口必须只能应用内打开")

    r.check("AdminReceiver 声明",
            '<receiver' in text and "AdminReceiver" in text)
    r.check("AdminReceiver 绑定 BIND_DEVICE_ADMIN",
            'android.permission.BIND_DEVICE_ADMIN' in text)
    r.check("AdminReceiver 声明 device_admin 元数据",
            'android.app.device_admin' in text and "@xml/device_admin" in text)
    r.check("BootReceiver 声明 BOOT_COMPLETED",
            "BOOT_COMPLETED" in text)
    r.check("BootReceiver directBootAware=false",
            'android:directBootAware="false"' in text)
    r.check("只申请 RECEIVE_BOOT_COMPLETED（无 INTERNET）",
            "RECEIVE_BOOT_COMPLETED" in text and "android.permission.INTERNET" not in text)
    r.check("Termux 包可见性 <queries>",
            "<queries>" in text and 'android:name="com.termux"' in text)
    r.check("targetSdkVersion 已声明",
            "android:targetSdkVersion=" in text)


def s02_limiter_constants(ctx: Ctx, r: Result):
    """T10 判据：10 分钟 / 5 次 / 4 秒 / 8 秒，参数被改大或改小都必须报警。"""
    text = read_java(ctx, "TerminalOsConfig")
    expect = {
        "RESTART_WINDOW_MS": 10 * 60 * 1000,
        "RESTART_MAX_FAILURES_IN_WINDOW": 5,
        "RESTART_MIN_INTERVAL_MS": 4000,
        "RESTART_QUICK_RETURN_THRESHOLD_MS": 8000,
        "TITLE_TAPS_TO_MAINTENANCE": 7,
        "TITLE_TAP_TIMEOUT_MS": 1500,
    }
    for name, want in expect.items():
        got = java_int_const(text, name)
        r.check("%s == %s" % (name, want), got == want, "实际=%r" % (got,))


def s03_limiter_logic(ctx: Ctx, r: Result):
    """T10 判据：失败窗口、冷静期、精确计数、重启/手动重置语义。"""
    text = read_java(ctx, "RestartLimiter")
    begin = extract_body(text, r"Decision beginAutomaticAttempt\s*\(\s*\)")
    r.check("beginAutomaticAttempt 可解析", begin is not None)
    if begin:
        r.check("窗口上限按 RESTART_MAX_FAILURES_IN_WINDOW 判定",
                "failures.size() >= TerminalOsConfig.RESTART_MAX_FAILURES_IN_WINDOW" in begin)
        r.check("窗口耗尽返回 windowExhausted=true",
                re.search(r"new Decision\(\s*false\s*,\s*true\s*,", begin) is not None)
        r.check("冷静期按 RESTART_MIN_INTERVAL_MS 计算",
                "RESTART_MIN_INTERVAL_MS - elapsed" in begin)
        r.check("冷静期返回可重试决策(windowExhausted=false)",
                re.search(r"new Decision\(\s*false\s*,\s*false\s*,", begin) is not None)
        r.check("时钟回拨被处理", "elapsed < 0L" in begin)
        r.check("允许时才写 lastAttempt", "putLong(KEY_LAST_ATTEMPT_AT, now)" in begin)

    failed = extract_body(text, r"void recordLaunchFailed\s*\(\s*String reason\s*\)")
    r.check("recordLaunchFailed 可解析", failed is not None)
    if failed:
        r.check("失败时间被追加", "failures.add(now)" in failed)
        r.check("失败窗口被持久化", "saveFailureTimes(failures)" in failed)
        r.check("失败原因被记录", "KEY_LAST_FAILURE_REASON" in failed)

    boot = extract_body(text, r"void resetForBoot\s*\(\s*\)")
    r.check("resetForBoot 清空失败窗口",
            boot is not None and "remove(KEY_FAILURE_TIMES)" in boot)

    manual = extract_body(text, r"void resetForManualRetry\s*\(\s*\)")
    r.check("resetForManualRetry 清空失败窗口",
            manual is not None and "remove(KEY_FAILURE_TIMES)" in manual)
    r.check("手动重试保留冷静期（不立即连发）",
            manual is not None and "putLong(KEY_LAST_ATTEMPT_AT, now)" in manual)

    trim = extract_body(text, r"void trimFailureTimes\s*\(.*?\)")
    r.check("窗口按 RESTART_WINDOW_MS 裁剪",
            trim is not None and "RESTART_WINDOW_MS" in trim and "failures.get(0) < windowStart" in trim)

    status = extract_body(text, r"Status getStatus\s*\(\s*\)")
    r.check("getStatus 的 lockedOut 与上限一致",
            status is not None
            and "failures.size() >= TerminalOsConfig.RESTART_MAX_FAILURES_IN_WINDOW" in status)


def s04_quick_return_wiring(ctx: Ctx, r: Result):
    """T10 判据：8 秒快速返回必须真的接入限流，否则"只判成功不判崩溃"=无限重启。"""
    text = read_java(ctx, "MainActivity")
    on_resume = extract_body(text, r"void onResume\s*\(\s*\)")
    r.check("onResume 调用 evaluateTermuxReturnIfNeeded",
            on_resume is not None and "evaluateTermuxReturnIfNeeded()" in on_resume)
    evaluate = extract_body(text, r"void evaluateTermuxReturnIfNeeded\s*\(\s*\)")
    r.check("evaluateTermuxReturnIfNeeded 可解析", evaluate is not None)
    if evaluate:
        ev = strip_java_comments(evaluate)
        r.check("按 8 秒阈值判断",
                "elapsedMs >= TerminalOsConfig.RESTART_QUICK_RETURN_THRESHOLD_MS" in ev)
        r.check("快速返回记为失败重启（else 分支真实调用）",
                "restartLimiter.recordLaunchFailed(" in ev
                and ev.find("} else {") < ev.find("restartLimiter.recordLaunchFailed("))
        r.check("停留足够久不计数",
                "本次返回不消耗重启额度" in evaluate or "elapsedMs >=" in ev)
    attempt = extract_body(text, r"void attemptTermuxLaunch\s*\(\s*\)")
    r.check("启动成功记录起点时间",
            attempt is not None
            and "termuxLaunchStartedAtElapsedRealtime = SystemClock.elapsedRealtime()" in attempt)
    r.check("启动前必须经限流许可",
            attempt is not None and "beginAutomaticAttempt()" in attempt)
    r.check("未许可时不再启动（windowExhausted 分支 return）",
            attempt is not None
            and re.search(r"windowExhausted", attempt) is not None
            and attempt.find("beginAutomaticAttempt()") < attempt.find("terminalLauncher.launchTermux")
            if attempt else False)


def s05_pin_security(ctx: Ctx, r: Result):
    """T13 判据：PIN 只存 PBKDF2 派生值，随机 salt，定长比较，不落明文。"""
    text = read_java(ctx, "AdminPinManager")
    r.check("使用 PBKDF2WithHmacSHA256", "PBKDF2WithHmacSHA256" in text)
    r.check("SALT_LENGTH_BYTES == 16", java_int_const(text, "SALT_LENGTH_BYTES") == 16)
    r.check("PBKDF2_ITERATIONS == 120000", java_int_const(text, "PBKDF2_ITERATIONS") == 120000)
    r.check("定长比较用 MessageDigest.isEqual",
            "MessageDigest.isEqual(expectedHash, actualHash)" in text)
    r.check("PIN 格式 4-12 位纯数字",
            java_int_const(text, "PIN_MIN_LENGTH") == 4
            and java_int_const(text, "PIN_MAX_LENGTH") == 12
            and "^[0-9]{" in text)
    r.check("未把 PIN 明文写入 SharedPreferences",
            re.search(r"putString\([^;]*,\s*pin\s*\)", text) is None)
    r.check("派生结果用后清零", "Arrays.fill(derivedHash" in text and "Arrays.fill(actualHash" in text)
    r.check("PIN 存储用 commit() 同步落盘",
            "commit()" in text)
    r.check("未设置 PIN 时不允许据此退出锁定",
            "NOT_SET" in text)


def s06_maintenance_gate(ctx: Ctx, r: Result):
    """T13/T19 判据：退出锁定必须过 PIN；重试不清冷静期；入口 7 击。"""
    text = read_java(ctx, "MaintenanceActivity")
    exit_req = extract_body(text, r"void onExitLockRequested\s*\(\s*\)")
    r.check("onExitLockRequested 可解析", exit_req is not None)
    if exit_req:
        r.check("退出锁定先要求已设置 PIN", "isPinSet()" in exit_req)
        r.check("退出锁定先验证 PIN", "showVerifyPinDialog" in exit_req)
        if "performExitLock()" in exit_req:
            r.check("PIN 回调里才执行退出",
                    exit_req.find("showVerifyPinDialog") < exit_req.find("performExitLock()"))
    perform = extract_body(text, r"void performExitLock\s*\(\s*\)")
    r.check("performExitLock 退出锁任务",
            perform is not None and "exitLockTask(" in perform)
    r.check("performExitLock 进入维护模式",
            perform is not None and "setMaintenanceMode(this, true)" in perform)

    retry = extract_body(text, r"void onRetryTermuxRequested\s*\(\s*\)")
    r.check("重新打开 Termux 重置限流窗口",
            retry is not None and "resetForManualRetry()" in retry)
    r.check("重新打开 Termux 清除维护模式",
            retry is not None and "setMaintenanceMode(this, false)" in retry)

    setpin = extract_body(text, r"void onSetPinRequested\s*\(\s*\)")
    r.check("改 PIN 前验证旧 PIN",
            setpin is not None and "showVerifyPinDialog" in setpin)

    main = read_java(ctx, "MainActivity")
    tap = extract_body(main, r"void setupTitleTapEntry\s*\(\s*\)")
    r.check("7 击进入维护入口",
            tap is not None and "TITLE_TAPS_TO_MAINTENANCE" in tap)
    r.check("点击超时重新计数",
            tap is not None and "TITLE_TAP_TIMEOUT_MS" in tap)


def s07_kiosk_contract(ctx: Ctx, r: Result):
    """T03/T04/T06/T18 前置：DO 门禁、白名单、特性位、非 DO 不伪装。"""
    text = read_java(ctx, "KioskController")
    enter = extract_body(text, r"LockResult enterLockTask\s*\(\s*Activity activity\s*\)")
    r.check("enterLockTask 可解析", enter is not None)
    if enter:
        r.check("非 DO 直接返回、不调用 startLockTask",
                "if (!isDeviceOwner())" in enter
                and enter.find("if (!isDeviceOwner())") < enter.find("activity.startLockTask()"))
        r.check("非 DO 时 attempted=false（不伪装已锁定）",
                re.search(r"new LockResult\(\s*false\s*,\s*false\s*,", enter) is not None)
    configure = extract_body(text, r"boolean configureLockTask\s*\(\s*\)")
    r.check("白名单包含自身包", configure is not None and "add(appContext.getPackageName())" in configure)
    r.check("白名单包含 Termux", configure is not None and "add(TerminalOsConfig.TERMUX_PACKAGE)" in configure)
    r.check("调用 setLockTaskPackages", configure is not None and "setLockTaskPackages(" in configure)
    features = extract_body(text, r"void applyLockTaskFeatures\s*\(\s*\)")
    for flag in ("LOCK_TASK_FEATURE_SYSTEM_INFO", "LOCK_TASK_FEATURE_NOTIFICATIONS",
                 "LOCK_TASK_FEATURE_HOME"):
        r.check("特性位 %s" % flag, features is not None and flag in features)
    r.check("QUICK_SETTINGS 位经反射探测",
            "LOCK_TASK_FEATURE_QUICK_SETTINGS" in text and "getField(" in text)
    r.check("QUICK_SETTINGS 被拒时回退 baseFeatures",
            features is not None
            and "quickSettingsFeatureRejected = true" in features
            and features.count("setLockTaskFeatures(") >= 2)
    takeover = extract_body(text, r"boolean applyPersistentPreferredHome\s*\(\s*\)")
    r.check("HOME 接管用 addPersistentPreferredActivity",
            takeover is not None and "addPersistentPreferredActivity(" in takeover)
    r.check("HOME 过滤器带 CATEGORY_HOME",
            takeover is not None and "Intent.CATEGORY_HOME" in takeover)
    ensure = extract_body(text, r"void ensureDefaultHome\s*\(.*?\)")
    r.check("非 DO 不尝试接管 HOME",
            ensure is not None
            and "if (!isDeviceOwner())" in ensure
            and "HOME_STATE_NOT_DEVICE_OWNER" in ensure)


def s08_product_overlay(ctx: Ctx, r: Result):
    """T05/T06 前置：导航栏 overlay 与产品继承；23.2 分支的监督角色白名单。"""
    cfg = read_text(ctx.v("overlay/frameworks/base/core/res/res/values/config.xml"))
    r.check("config_showNavigationBar=false",
            re.search(r'<bool name="config_showNavigationBar">\s*false\s*</bool>', cfg) is not None,
            "T05 的 overlay 前置")
    m = re.search(
        r'<string name="config_allowedSupervisionRolePackages"[^>]*>([^<]*)</string>', cfg)
    if m is not None:
        r.check("监督角色白名单含 TerminalHome",
                "org.terminalos.terminalhome" in m.group(1),
                "D-11 标准路径前置")
    else:
        r.note("SKIP: 当前 overlay 无 config_allowedSupervisionRolePackages。"
               "这是 22.2 分支的预期形态（该资源只存在于 23.2）；"
               "23.2 分支（vendor@9a5d532）已带该条，需在 23.2 树上复查 S08。")

    mk = read_text(ctx.v("terminalos.mk"))
    r.check("PRODUCT_PACKAGES 含 TerminalHome", re.search(r"PRODUCT_PACKAGES\s*\+?=", mk) is not None and "TerminalHome" in mk)
    r.check("PRODUCT_PACKAGES 含 Termux", "Termux" in mk)
    r.check("PRODUCT_PACKAGE_OVERLAYS 指向 vendor/terminalos/overlay",
            "PRODUCT_PACKAGE_OVERLAYS" in mk and "vendor/terminalos/overlay" in mk)

    dev = read_text(ctx.d("terminalos_polaris.mk"))
    r.check("产品继承 vendor/terminalos/terminalos.mk",
            "inherit-product, vendor/terminalos/terminalos.mk" in dev)
    r.check("PRODUCT_NAME := terminalos_polaris",
            re.search(r"PRODUCT_NAME\s*:=\s*terminalos_polaris", dev) is not None)


def s09_boot_and_prebuilt(ctx: Ctx, r: Result):
    """T02/T20 前置：开机重置、首次初始化幂等、Termux presigned 锁定。"""
    boot = read_java(ctx, "BootReceiver")
    r.check("BOOT_COMPLETED 重置限流", "resetForBoot()" in boot)
    r.check("BOOT_COMPLETED 清除维护模式", "setMaintenanceMode(context, false)" in boot)
    r.check("BOOT_COMPLETED 记录启动时间", "KEY_LAST_BOOT_AT" in boot)
    r.check("广播里不启动 Activity（避免竞态）",
            "startActivity(" not in strip_java_comments(boot))

    fb = read_text(ctx.v("scripts/first_boot.sh"))
    r.check("首次初始化有标记文件幂等检查", '[ -e "${MARKER_FILE}" ]' in fb)
    r.check("先建目录再写标志", "mkdir -p" in fb)
    r.check("标记文件用 tmp+rename 原子写入",
            "${MARKER_FILE}.tmp" in fb and 'mv -f "${tmp_marker}"' in fb)
    r.check("不删除用户/系统数据", "rm -rf" not in fb)
    r.check("不调用 pm/am/cmd 安装组件",
            not re.search(r"\b(pm|am|cmd)\s+(install|start|set-)", fb))
    r.check("失败不阻塞开机（始终 exit 0）", fb.count("exit 0") >= 4)

    bp = read_text(ctx.v("Android.bp"))
    r.check("Termux 模块 presigned:true", "presigned: true" in bp)
    r.check("Termux 模块名与产品契约一致", 'name: "Termux"' in bp)
    r.check("Termux APK 路径 prebuilt/Termux.apk", 'apk: "prebuilt/Termux.apk"' in bp)
    r.check("跳过 dex 预优化（保持原始字节）", "dex_preopt" in bp)

    fetch = read_text(ctx.v("scripts/fetch-termux.sh"))
    r.check("fetch 脚本做 SHA256 校验",
            "sha256sum" in fetch and "shasum" in fetch and "TERMUX_SHA256" in fetch)
    r.check("fetch 脚本做大小校验", "TERMUX_SIZE_BYTES" in fetch)
    sha_const = re.search(r'TERMUX_SHA256="([0-9a-f]{64})"', fetch)
    sha_file = read_text(ctx.v("prebuilt/Termux.apk.sha256")).strip()
    r.check("脚本 SHA256 与 prebuilt 校验文件一致",
            sha_const is not None and sha_file.startswith(sha_const.group(1)))


def _collect_resources(ctx: Ctx, r: Result):
    res = ctx.p("res")
    strings = set()
    for f in (res / "values").glob("*.xml"):
        try:
            root = ET.parse(f).getroot()
        except ET.ParseError as e:
            r.fail("XML 可解析: values/%s" % f.name, str(e))
            continue
        if f.name == "strings.xml":
            for el in root.iter():
                if el.tag == "string" and "name" in el.attrib:
                    strings.add(el.attrib["name"])
    ids = set()
    for f in (res / "layout").glob("*.xml"):
        try:
            text = read_text(f)
        except Exception as e:  # noqa: BLE001
            r.fail("layout 可读: %s" % f.name, str(e))
            continue
        ids.update(re.findall(r'@\+id/([A-Za-z0-9_]+)', text))
    layouts = {f.stem for f in (res / "layout").glob("*.xml")}
    drawables = {f.stem for f in (res / "drawable").glob("*") if f.suffix in (".xml", ".png")}
    defs = {"string": strings, "id": ids, "layout": layouts, "drawable": drawables}
    # style / color
    for kind, fname in (("style", "styles.xml"), ("color", "colors.xml")):
        names = set()
        f = res / "values" / fname
        if f.is_file():
            try:
                root = ET.parse(f).getroot()
                for el in root.iter():
                    if el.tag == kind and "name" in el.attrib:
                        names.add(el.attrib["name"])
            except ET.ParseError as e:
                r.fail("XML 可解析: values/%s" % fname, str(e))
        defs[kind] = names
    return defs


def s10_resource_refs(ctx: Ctx, r: Result):
    """构建前置：Java/manifest 引用的 R.* 与 @xxx/yyy 必须真实存在（抓拼写错误）。"""
    defs = _collect_resources(ctx, r)
    missing = []
    for java in (ctx.p("src")).rglob("*.java"):
        text = java.read_text(encoding="utf-8", errors="replace")
        for kind, name in re.findall(r"(?<!android\.)R\.([a-z]+)\.([A-Za-z0-9_]+)", text):
            if kind in defs and name not in defs[kind]:
                missing.append("%s: R.%s.%s" % (java.name, kind, name))
    manifest = read_text(ctx.p("AndroidManifest.xml"))
    for kind, name in set(re.findall(r"@(string|drawable|style|layout|xml)/([A-Za-z0-9_.]+)", manifest)):
        if kind in defs and name not in defs[kind]:
            missing.append("AndroidManifest.xml: @%s/%s" % (kind, name))
    r.check("Java/manifest 资源引用全部存在", not missing,
            "; ".join(sorted(set(missing))[:10]))
    # XML 语法（构建前置）
    bad_xml = []
    for f in list((ctx.p("res")).rglob("*.xml")) + [ctx.p("AndroidManifest.xml")]:
        try:
            ET.parse(f)
        except ET.ParseError as e:
            bad_xml.append("%s: %s" % (f.name, e))
    r.check("全部 XML 语法合法", not bad_xml, "; ".join(bad_xml[:5]))


def s11_format_args(ctx: Ctx, r: Result):
    """构建/运行前置：带占位符的文案与调用参数个数必须匹配（否则实机崩溃）。"""
    strings_text = read_text(ctx.p("res/values/strings.xml"))
    root = ET.parse(ctx.p("res/values/strings.xml")).getroot()
    ph = {}
    for el in root.iter():
        if el.tag != "string" or "name" not in el.attrib:
            continue
        s = "".join(el.itertext())
        idx = [int(x) for x in re.findall(r"%(\d+)\$[a-zA-Z]", s)]
        if idx:
            ph[el.attrib["name"]] = idx
            r.check("占位符索引连续 1..N: %s" % el.attrib["name"],
                    sorted(set(idx)) == list(range(1, max(idx) + 1)),
                    "实际 %s" % idx)
            # 混用位置参数与裸 %s/%d 在 String.format 下会错位
            r.check("占位符全部为位置参数: %s" % el.attrib["name"],
                    len(re.findall(r"%(?!\d+\$)[a-zA-Z]", s)) == 0)

    # getString(R.string.X, ...) 的实参个数
    problems = []
    for java in (ctx.p("src")).rglob("*.java"):
        text = java.read_text(encoding="utf-8", errors="replace")
        for m in re.finditer(r"getString\(R\.string\.([A-Za-z0-9_]+)", text):
            name = m.group(1)
            # 作为 String.format 的格式串时由下面的 format 检查统一核对，跳过
            stmt_start = text.rfind(";", 0, m.start()) + 1
            if "String.format(" in text[stmt_start:m.start()]:
                continue
            open_paren = text.find("(", m.start())
            if open_paren < 0:
                continue
            n_extra = call_args_count(text, open_paren)
            if n_extra is None or name not in ph:
                continue
            want = max(ph[name])
            if n_extra != want:
                problems.append("%s: getString(%s) 传 %d 参，占位符 %d 个"
                                % (java.name, name, n_extra, want))
    r.check("getString 实参个数与占位符匹配", not problems, "; ".join(problems[:8]))

    # String.format(..., getString(R.string.X), args...) 的实参个数
    fmts = []
    for java in (ctx.p("src")).rglob("*.java"):
        text = java.read_text(encoding="utf-8", errors="replace")
        for m in re.finditer(r"String\.format\(", text):
            open_paren = m.end() - 1
            n = call_args_count(text, open_paren)
            if n is None:
                continue
            call = text[m.start():]
            gm = re.search(r"getString\(R\.string\.([A-Za-z0-9_]+)\)", call[:400])
            if not gm or gm.group(1) not in ph:
                continue
            want = max(ph[gm.group(1)])
            have = n - 1  # 顶层逗号数 n -> 参数数 n+1，再去掉 Locale 与格式串本身
            if have != want:
                fmts.append("%s: String.format(%s) 传 %d 参，占位符 %d 个"
                            % (java.name, gm.group(1), have, want))
    r.check("String.format 实参个数与占位符匹配", not fmts, "; ".join(fmts[:8]))


CHECKS = [
    ("S01", "T01/T02/T03/T13", "HOME/维护组件声明契约", s01_home_manifest,
     "不能证明 aapt2 编译通过与系统解析结果；需构建产物 aapt2 dump + 实机"),
    ("S02", "T10", "限流参数常量 (10min/5/4s/8s)", s02_limiter_constants,
     "常量对但逻辑可错；逻辑由 S03/S04 覆盖，运行行为仍需实机"),
    ("S03", "T10", "限流窗口/冷静期/重置逻辑", s03_limiter_logic,
     "文本结构证明；时钟边界与 SharedPreferences 行为需 Robolectric/实机"),
    ("S04", "T10", "8 秒快速返回接入限流", s04_quick_return_wiring,
     "不能证明 onResume 时序与 Termux 崩溃路径，需实机 force-stop 演练"),
    ("S05", "T13", "PIN 只存 PBKDF2 派生值", s05_pin_security,
     "未证明 PBKDF2 在目标 ROM 可用；需实机首次设置/校验/重启后校验"),
    ("S06", "T13/T19", "维护入口门禁与退出锁定流程", s06_maintenance_gate,
     "界面交互、PIN 对话框、锁任务下能否打开维护页需实机"),
    ("S07", "T03/T04/T06/T18", "DO 门禁/白名单/特性位/非 DO 不伪装", s07_kiosk_contract,
     "DPM 真实授权、SYSTEM_SUPERVISION 角色、反射隐藏 API 是否可用需实机"),
    ("S08", "T05/T06", "导航栏 overlay 与产品继承", s08_product_overlay,
     "overlay 是否被链接、手势提示条表现需构建产物 + 实机"),
    ("S09", "T02/T20", "开机重置/初始化幂等/Termux presigned", s09_boot_and_prebuilt,
     "first_boot.sh 未接入系统；Termux 首次启动与数据幂等需实机"),
    ("S10", "构建前置", "资源引用与 XML 语法", s10_resource_refs,
     "不能替代 Soong 编译；只抓引用级错误"),
    ("S11", "构建前置", "文案占位符与实参匹配", s11_format_args,
     "不能替代 lint/编译；只抓数目/位置参数错配"),
]


# ---------------------------------------------------------------------------
# 变异自检：证明每条断言"会红"
# ---------------------------------------------------------------------------

MUTATIONS = [
    ("M01", "S01", HOME_REPO, "AndroidManifest.xml",
     '                <category android:name="android.intent.category.HOME" />\n', "",
     "删掉 HOME 类别（系统不再把 TerminalHome 当桌面）"),
    ("M02", "S02", HOME_REPO, "src/org/terminalos/terminalhome/TerminalOsConfig.java",
     "RESTART_MAX_FAILURES_IN_WINDOW = 5;", "RESTART_MAX_FAILURES_IN_WINDOW = 50;",
     "把 10 分钟 5 次放宽到 50 次（无限重启风险回归）"),
    ("M03", "S03", HOME_REPO, "src/org/terminalos/terminalhome/RestartLimiter.java",
     "failures.add(now);", "",
     "失败重启不再计入窗口（限流形同虚设）"),
    ("M04", "S04", HOME_REPO, "src/org/terminalos/terminalhome/MainActivity.java",
     '            restartLimiter.recordLaunchFailed("Termux 启动后 " + elapsedMs',
     '            // restartLimiter.recordLaunchFailed("Termux 启动后 " + elapsedMs',
     "8 秒快速返回不再接入限流（只判成功）"),
    ("M05", "S05", HOME_REPO, "src/org/terminalos/terminalhome/AdminPinManager.java",
     "MessageDigest.isEqual(expectedHash, actualHash)",
     "expectedHash.equals(actualHash)",
     "定长比较退化为普通 equals（时序侧信道）"),
    ("M06", "S07", HOME_REPO, "src/org/terminalos/terminalhome/KioskController.java",
     "        if (!isDeviceOwner()) {\n            Log.i(TAG, \"非 Device Owner：不进入锁任务模式（按降级策略不锁定）\");",
     "        if (false) {\n            Log.i(TAG, \"非 Device Owner：不进入锁任务模式（按降级策略不锁定）\");",
     "非 DO 也尝试锁任务（伪装/异常路径回归）"),
    ("M07", "S08", VENDOR_REPO, "overlay/frameworks/base/core/res/res/values/config.xml",
     '<bool name="config_showNavigationBar">false</bool>',
     '<bool name="config_showNavigationBar">true</bool>',
     "导航栏重新显示（T05 目标丢失）"),
    ("M08", "S09", VENDOR_REPO, "scripts/first_boot.sh",
     'if [ -e "${MARKER_FILE}" ]; then',
     'if false; then',
     "首次初始化失去幂等检查（重复执行副作用）"),
    ("M09", "S10", HOME_REPO, "src/org/terminalos/terminalhome/MainActivity.java",
     "R.string.status_lock_active", "R.string.status_lock_actve",
     "资源名拼错（构建失败级缺陷）"),
    ("M10", "S11", HOME_REPO, "src/org/terminalos/terminalhome/MaintenanceActivity.java",
     "                describeSupervisionRole());",
     "                describeSupervisionRole(), \"extra\");",
     "诊断文案多传一个格式参数（运行时 IllegalFormat 崩溃）"),
    ("M11", "S09", VENDOR_REPO, "scripts/fetch-termux.sh",
     'TERMUX_SHA256="72fdb596045116bf5ba1b5bdf5b26fddb9acc0bd074ad9f2da9eb0ae85e83a4e"',
     'TERMUX_SHA256="72fdb596045116bf5ba1b5bdf5b26fddb9acc0bd074ad9f2da9eb0ae85e83a4f"',
     "校验值错一位（下载校验失效/误报）"),
]


def apply_mutation(work: Path, repo: str, rel: str, old: str, new: str):
    path = work / repo / rel
    text = path.read_text(encoding="utf-8")
    if old not in text:
        raise RuntimeError("变异锚点未找到: %s :: %r" % (path, old[:60]))
    path.write_text(text.replace(old, new, 1), encoding="utf-8")


def run_checks(root: Path, only=None):
    ctx = Ctx(root)
    results = {}
    for cid, tcase, title, fn, blind in CHECKS:
        if only and cid not in only:
            continue
        r = Result()
        try:
            fn(ctx, r)
        except Exception as e:  # noqa: BLE001
            r.fail("检查执行异常", "%s: %s" % (type(e).__name__, e))
        results[cid] = (tcase, title, r, blind)
    return results


def print_results(results, verbose):
    total = 0
    failed = 0
    for cid, (tcase, title, r, blind) in results.items():
        asserts = r.rows
        bad = [x for x in asserts if not x[1]]
        total += 1
        if not r.passed:
            failed += 1
        print("[%s] %s %-8s %s" % ("PASS" if r.passed else "FAIL", cid, tcase, title))
        print("       断言 %d 条，失败 %d 条" % (len(asserts), len(bad)))
        for name, ok, detail in bad:
            print("       FAIL %s %s" % (name, ("- " + detail) if detail else ""))
        if verbose:
            for name, ok, detail in asserts:
                print("       %s %s" % ("ok " if ok else "X  ", name))
        for note in r.notes:
            print("       NOTE %s" % note)
        print("       替代验证盲区：%s" % blind)
    print("")
    print("汇总：%d 项检查，%d 项失败" % (total, failed))
    return failed


def rmtree_force(path: Path):
    """删除目录树；.git 里的只读文件在 Windows 上需要先去掉只读位。"""
    def _onerr(func, p, exc):
        try:
            os.chmod(p, 0o700)
            func(p)
        except Exception:  # noqa: BLE001
            pass
    try:
        shutil.rmtree(path, onexc=_onerr)
    except FileNotFoundError:
        pass
    except Exception:  # noqa: BLE001
        pass


def make_mutation_dir(work_root: Path, mid: str) -> Path:
    """在证据目录里建一个干净的可写目录（沙箱下 tempfile.mkdtemp 目录不可写子项）。"""
    attempt = 0
    while True:
        name = "mut_%s" % mid if attempt == 0 else "mut_%s_%d" % (mid, attempt)
        tmp = work_root / name
        if tmp.exists():
            rmtree_force(tmp)
        try:
            tmp.mkdir(parents=True, exist_ok=False)
            return tmp
        except FileExistsError:
            attempt += 1
            if attempt > 5:
                raise
        # 父目录之外的错误（不可写等）直接抛出


def mutation_test(root: Path, keep_tmp: bool):
    # 变异副本放系统临时目录，避免把 .git 对象灌进项目证据目录
    work_root = Path(tempfile.gettempdir()) / "terminalos_static_mutation"
    if work_root.exists():
        for child in work_root.iterdir():
            rmtree_force(child)
    work_root.mkdir(parents=True, exist_ok=True)
    detected = 0
    not_detected = []
    errors = []
    print("== 变异自检：每条注入一个真实缺陷，要求对应检查由 PASS 变 FAIL ==")
    print("")
    for mid, check_id, repo, rel, old, new, why in MUTATIONS:
        tmp = make_mutation_dir(work_root, mid)
        try:
            for rp in REPOS:
                shutil.copytree(root / rp, tmp / rp)
            apply_mutation(tmp, repo, rel, old, new)
            results = run_checks(tmp, only=[check_id])
            ok = results[check_id][2].passed
            if ok:
                not_detected.append(mid)
                print("[MISS] %s -> %s 未检出：%s" % (mid, check_id, why))
            else:
                detected += 1
                print("[KILL] %s -> %s 已检出：%s" % (mid, check_id, why))
                if "--verbose" in sys.argv:
                    for name, aok, detail in results[check_id][2].rows:
                        if not aok:
                            print("        触发断言: %s" % name)
        except Exception as e:  # noqa: BLE001
            errors.append("%s: %s" % (mid, e))
            print("[ERR ] %s: %s" % (mid, e))
        finally:
            if not keep_tmp:
                rmtree_force(tmp)
    print("")
    print("变异自检汇总：%d 个变异，检出 %d 个，漏检 %d 个，异常 %d 个"
          % (len(MUTATIONS), detected, len(not_detected), len(errors)))
    if not_detected:
        print("漏检项（断言没有牙齿，必须补断言）：%s" % ",".join(not_detected))
    return 0 if detected == len(MUTATIONS) else 1


class _Tee:
    """把 stdout 同时写入 UTF-8 证据文件（Windows 控制台编码不可靠，日志一律由脚本自己写）。"""

    def __init__(self, path: Path):
        self._orig = sys.__stdout__
        self._file = open(path, "w", encoding="utf-8", newline="\n")

    def write(self, text):
        self._orig.write(text)
        self._file.write(text)

    def flush(self):
        try:
            self._orig.flush()
        finally:
            self._file.flush()

    def close(self):
        try:
            self._file.close()
        finally:
            pass


def main(argv=None):
    try:  # 统一 UTF-8 输出，避免 Windows 控制台/日志编码把中文写成乱码
        sys.stdout.reconfigure(encoding="utf-8")
        sys.stderr.reconfigure(encoding="utf-8")
    except Exception:  # noqa: BLE001
        pass
    ap = argparse.ArgumentParser(description="TerminalOS acceptance static checks")
    ap.add_argument("--log", default=None,
                    help="同时把输出写入该文件（UTF-8），用于保存验收证据")
    ap.add_argument("--root", default=r"C:\AiWork\Polaris-TerminalOS-repos",
                    help="包含三个仓库的目录")
    ap.add_argument("--check", action="append", default=None,
                    help="只跑指定检查，如 --check S05（可重复）")
    ap.add_argument("--mutation-test", action="store_true",
                    help="运行变异自检，证明断言会红")
    ap.add_argument("--keep-tmp", action="store_true")
    ap.add_argument("--verbose", action="store_true")
    args = ap.parse_args(argv)

    root = Path(args.root)
    if not root.is_dir():
        print("仓库根目录不存在: %s" % root)
        return 2
    missing = [rp for rp in REPOS if not (root / rp).is_dir()]
    if missing:
        print("缺少仓库目录: %s" % missing)
        return 2

    tee = None
    if args.log:
        tee = _Tee(Path(args.log).resolve())
        sys.stdout = tee

    try:
        print("TerminalOS 验收静态预检（static precondition checks）")
        print("仓库根: %s" % root)
        print("时间: %s" % __import__("datetime").datetime.now().isoformat(timespec="seconds"))
        for rp in REPOS:
            head = ""
            try:
                gd = (root / rp / ".git" / "HEAD").read_text(encoding="utf-8").strip()
                if gd.startswith("ref: "):
                    ref = gd[5:]
                    head = (root / rp / ".git" / ref).read_text(encoding="utf-8").strip()
                else:
                    head = gd
            except Exception:  # noqa: BLE001
                pass
            print("  %-40s HEAD=%s" % (rp, head or "(未读取)"))
        print("")

        results = run_checks(root, only=args.check)
        failed = print_results(results, args.verbose)
        rc = 0 if failed == 0 else 1

        if args.mutation_test:
            print("")
            mrc = mutation_test(root, args.keep_tmp)
            rc = rc or mrc
        return rc
    finally:
        if tee is not None:
            sys.stdout = sys.__stdout__
            tee.flush()
            tee.close()


if __name__ == "__main__":
    sys.exit(main())
