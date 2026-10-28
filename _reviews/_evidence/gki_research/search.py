import sys, os, re, ssl, json, urllib.parse, urllib.request

PROXY = "http://127.0.0.1:7897"
OUT = os.path.dirname(os.path.abspath(__file__))


def opener(verify=True):
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
        ("Accept", "text/html,application/xhtml+xml,*/*"),
        ("Accept-Language", "en-US,en;q=0.9"),
    ]
    return op


def ddg(q):
    url = "https://html.duckduckgo.com/html/?q=" + urllib.parse.quote(q)
    for verify in (True, False):
        try:
            html = opener(verify).open(url, timeout=50).read().decode("utf-8", "replace")
            break
        except Exception as e:
            err = e
    else:
        return {"query": q, "error": str(err)}
    out = []
    for m in re.finditer(r'<a[^>]+class="result__a"[^>]*href="([^"]+)"[^>]*>(.*?)</a>', html, re.S):
        href, title = m.group(1), re.sub(r"<[^>]+>", "", m.group(2))
        if href.startswith("//duckduckgo.com/l/?uddg="):
            href = urllib.parse.unquote(href.split("uddg=")[1].split("&")[0])
        out.append({"url": href, "title": title.strip()})
        if len(out) >= 12:
            break
    return {"query": q, "results": out}


if __name__ == "__main__":
    res = [ddg(q) for q in sys.argv[1:]]
    print(json.dumps(res, ensure_ascii=False, indent=2))
