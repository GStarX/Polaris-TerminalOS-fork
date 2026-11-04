# ASR 模型 + VAD 分段选型（方案甲 v1）

- 状态：v1（等待 复核官 定案、首席 设备实测）
- 产出人：方案甲（C_O5）
- 现状输入（首席实测）：现用 **流式 zipformer-zh-14M**（74,004,050 B），6s 固定分段、无 VAD；中文识别乱码、唤醒词「大肥鱼」0 命中。

## 0. 证据：候选模型的真实体积（GitHub Release API 实测，非估算）

来源：`api.github.com/repos/k2-fsa/sherpa-onnx/releases/tags/asr-models`（2026-11-04 读取），下载基址：
`https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/<文件名>`

| 模型 | 文件 | 字节数（API 实测） | 说明 |
| --- | --- | --- | --- |
| 现用流式 | `sherpa-onnx-streaming-zipformer-zh-14M-2023-02-23.tar.bz2` | **74,004,050** | 与首席报的「14M 流式」一致，作基线对照 |
| **候选 A（小）** | `sherpa-onnx-paraformer-zh-small-2024-03-09.tar.bz2` | **77,920,048** | 非流式中文 paraformer small |
| **候选 B（准）** | `sherpa-onnx-paraformer-zh-2023-09-14.tar.bz2` | **234,051,698** | 非流式中文 paraformer，准确率优先 |
| 候选 C（多语） | `sherpa-onnx-zipformer-multi-zh-hans-2023-9-2.tar.bz2` | **309,195,644** | 非流式 zipformer，多语种 |
| 参考（勿选） | `sherpa-onnx-paraformer-zh-2024-03-09.tar.bz2` | 996,591,364 | 近 1 GB，手机 proot 不划算 |
| 参考（勿选） | `sherpa-onnx-whisper-*` | 116 MB ~ 1.93 GB | 中文不是最优，且大 |
| **VAD** | `silero_vad_v5.onnx` | **2,313,101** | 2.2 MB，配合非流式分段 |

**体积这条是硬证据**：以上字节数直接来自 GitHub API 的 asset `size` 字段，下载后可用 `stat -c %s` 逐位核对。

## 1. 推荐路径（两步，不要一次全换）

**第 1 步（当晚可做，零新依赖）**：保留现模型，只把「6s 固定切段」换成 **ffmpeg silencedetect 分段**。
- 现有 worker 已经在用 ffmpeg，`-af silencedetect=noise=-35dB:d=0.6` 就是 VAD 的 80% 效果，零下载、零新依赖。
- 判据：同一批 wav，分段后识别文本的字符数显著变长且不再全乱码（与本轮 `NOTE 为什么我找你一直在你公司的任务` 对比）。

**第 2 步（复用上面已落的 2.2MB）**：换 **候选 A paraformer-zh-small（78 MB）** + silero VAD。
- 体积只比现模型多 4 MB，内存压力可控，先验证「换模型是否真提升」。
- 若 A 仍不够（唤醒词命中率低于 8/10），再上 **候选 B（234 MB）**；B 的 tar.bz2 234MB、解包后更大，**proot 里的磁盘与内存要先确认**（未实测，见 §6）。

**不选 C**：多语种 309MB，我们只做中文，属于白付费。

## 2. 下载脚本（带用户要求的 10s 低速门限）

存为 `~/asr-model-fetch.sh`，`bash ~/asr-model-fetch.sh` 执行。**连续 10 秒 < 1MB/s 就中止并打印外部下载所需信息**，符合「低于 1MB/s 要报给用户外部下载」。

```bash
#!/usr/bin/env bash
set -u
GH_PROXY="${GH_PROXY:-https://gh-proxy.com}"
BASE="https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models"
DEST="${1:-$HOME/asr-models}"; mkdir -p "$DEST"

fetch() {
  local name="$1" expect="$2" url="$BASE/$1" out="$DEST/$1"
  if [ -f "$out" ] && [ "$(stat -c %s "$out")" = "$expect" ]; then
    echo "OK   already: $name ($expect B)"; return 0
  fi
  echo "GET  $GH_PROXY/$url"
  curl -fL --retry 2 -o "$out.part" "$GH_PROXY/$url" &
  local pid=$! last=0 slow=0 size=0
  while kill -0 $pid 2>/dev/null; do
    sleep 1
    size=$(stat -c %s "$out.part" 2>/dev/null || echo 0)
    if [ $((size - last)) -lt 1000000 ]; then slow=$((slow+1)); else slow=0; fi
    last=$size
    if [ "$slow" -ge 10 ]; then
      kill $pid 2>/dev/null; wait $pid 2>/dev/null; rm -f "$out.part"
      echo "SLOW  $name  <- 连续10s <1MB/s，需用户外部下载后放入 $DEST"
      echo "      URL: $url"
      echo "      EXPECT_BYTES: $expect"
      return 2
    fi
  done
  wait $pid; local rc=$?
  [ $rc -ne 0 ] && { echo "FAIL curl $name rc=$rc"; rm -f "$out.part"; return 1; }
  local got; got=$(stat -c %s "$out.part")
  [ "$got" != "$expect" ] && { echo "SIZE_MISMATCH $name got=$got expect=$expect"; rm -f "$out.part"; return 1; }
  mv "$out.part" "$out"; echo "OK   $name ($got B)"
}

fetch sherpa-onnx-paraformer-zh-small-2024-03-09.tar.bz2 77920048
fetch silero_vad_v5.onnx 2313101
# 需要候选 B 时再放开下一行（234MB）
# fetch sherpa-onnx-paraformer-zh-2023-09-14.tar.bz2 234051698
```

解包与放置：

```bash
cd "$HOME/asr-models"
tar -jxf sherpa-onnx-paraformer-zh-small-2024-03-09.tar.bz2
ls sherpa-onnx-paraformer-zh-small-2024-03-09/   # 应见 model.onnx tokens.txt 等
```

## 3. 替换与回退

**替换**（不删旧模型，便于回退）：worker 里把模型目录变量指向新目录，例如
`ASR_MODEL_DIR=$HOME/asr-models/sherpa-onnx-paraformer-zh-small-2024-03-09`，
非流式解码命令：
```bash
./sherpa-onnx-offline \
  --tokens=$ASR_MODEL_DIR/tokens.txt \
  --paraformer=$ASR_MODEL_DIR/model.onnx \
  --num-threads=2 \
  seg.wav
```
（`--paraformer` 这个参数名以本机 `sherpa-onnx-offline --help` 输出为准；若版本不同会提示未识别参数，按 help 改。）

**回退**：把 `ASR_MODEL_DIR` 改回旧目录、保留旧 streaming 模型不删，一次变量切换即可；旧模型文件全程不动。

## 4. 验收（一条命令一个 PASS/FAIL）

| # | 验收 | 命令 | 通过标准 |
| --- | --- | --- | --- |
| V1 | 下载完整性 | `stat -c %s ~/asr-models/sherpa-onnx-paraformer-zh-small-2024-03-09.tar.bz2` | `77920048` |
| V2 | VAD 文件 | `stat -c %s ~/asr-models/silero_vad_v5.onnx` | `2313101` |
| V3 | 解包成功 | `tar -tjf …tar.bz2 >/dev/null && echo PASS` | PASS |
| V4 | 单条解码可跑 | 用**同一条** `seg.wav` 分别用旧模型与新模型解码 | 新模型输出字符合理、非乱码 |
| V5 | **唤醒词命中率** | 对「大肥鱼」录 10 条，逐条解码，`grep -c 大肥鱼` | **≥8/10 才判通过**（现状 0 命中） |

## 5. 未闭口（不给结论的地方）

1. **内存占用未实测**：候选 A/B 的运行时内存我只能给方向（A 明显小于 B），真实 PSS 需要换上去用 `dumpsys meminfo` 量。
2. **解包后体积未算**：tar.bz2 78 MB / 234 MB 是压缩包，解包后更大，`~/asr-models` 所在分区剩余空间要先 `df -h`。
3. **gh-proxy 可用性未在本机验证**：脚本里的 `GH_PROXY` 可换，我没有在本机对代理做连通性测试（本机到 github.com:443 不通是已知事实）。
4. **worker 的模型目录变量名**：需要主机官确认实际配置位置，我只给替换方法，不猜文件名。
5. **准确率没有基准集**：V5 的「10 条唤醒词」是能立刻执行的判据，但不是 WER 评测；要做 WER 得另建测试集，属后续。
