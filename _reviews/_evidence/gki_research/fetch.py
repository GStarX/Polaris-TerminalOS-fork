import os, sys, ssl, json, re, urllib.request

PROXY = "http://127.0.0.1:7897"
OUT = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(OUT, "raw")
os.makedirs(RAW, exist_ok=True)

def mk_opener(verify=True):
    ctx = ssl.create_default_context()
    if not verify:
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
    op = urllib.request.build_opener(
        urllib.request.ProxyHandler({"http": PROXY, "https": PROXY}),
        urllib.request.HTTPSHandler(context=ctx),
    )
    op.addheaders = [
        ("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/122 Safari/537.36"),
        ("Accept", "text/html,application/xhtml+xml,application/json,*/*"),
        ("Accept-Language", "en-US,en;q=0.9"),
    ]
    return op

def html_to_text(html):
    try:
        import lxml.html
        doc = lxml.html.fromstring(html)
        for bad in doc.xpath("//script|//style|//noscript|//svg"):
            bad.getparent().remove(bad)
        txt = doc.text_content()
    except Exception:
        txt = re.sub(r"<[^>]+>", " ", html)
    txt = re.sub(r"[ \t\r\f\v]+", " ", txt)
    txt = re.sub(r"\n\s*\n\s*\n+", "\n\n", txt)
    return txt.strip()

def fetch(url, name):
    last = None
    for verify in (True, False):
        try:
            r = mk_opener(verify).open(url, timeout=60)
            body = r.read()
            enc = r.headers.get_content_charset() or "utf-8"
            try:
                s = body.decode(enc, errors="replace")
            except Exception:
                s = body.decode("utf-8", errors="replace")
            with open(os.path.join(RAW, name + ".html"), "w", encoding="utf-8") as f:
                f.write(s)
            ct = r.headers.get("Content-Type", "")
            if "json" in ct or url.rstrip("/").endswith(("format=JSON", ".json")) or "api.github.com" in url:
                text = s
            else:
                text = html_to_text(s)
            with open(os.path.join(RAW, name + ".txt"), "w", encoding="utf-8") as f:
                f.write(text)
            return {"url": url, "name": name, "status": r.status, "bytes": len(body),
                    "text_len": len(text), "verified_tls": verify}
        except Exception as e:
            last = f"{type(e).__name__}: {e}"
    return {"url": url, "name": name, "error": last}

if __name__ == "__main__":
    targets = json.load(open(os.path.join(OUT, "targets.json"), encoding="utf-8"))
    results = []
    for name, url in targets:
        res = fetch(url, name)
        results.append(res)
        print(json.dumps(res, ensure_ascii=False), flush=True)
    with open(os.path.join(OUT, "fetch_log.json"), "w", encoding="utf-8") as f:
        json.dump(results, f, ensure_ascii=False, indent=2)
