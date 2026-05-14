#!/usr/bin/env python3
"""ブログ全記事のGSCインデックス状態を診断し、ナレッジJSONに蓄積する。

入力:
  - src/content/blog/*.md（全記事のメタ情報を抽出）
  - .google-credentials.json（GSC URL Inspection APIへの認証）

出力:
  - docs/_indexing-history.json: スナップショット配列を追記。各スナップショットは記事ごとの
    特徴量（字数・h2数・内部被リンク数）とGSC状態（coverageState・lastCrawled）を含む
  - stdout: サマリ（インデックス済/未掲載の件数、状態変化があった記事）

運用:
  - daily-loop.sh から毎日呼ばれる
  - 状態変化（NEUTRAL→PASS や PASS→excluded 等）があったらDiscord通知用にstdoutへ出力
"""
import json
import urllib.request
import urllib.parse
import urllib.error
from datetime import datetime
import os
import re
import sys
import glob
import time

SITE_DIR = os.path.expanduser('~/37design-astro-site')
BLOG_DIR = f'{SITE_DIR}/src/content/blog'
CREDS_FILE = f'{SITE_DIR}/.google-credentials.json'
HISTORY_FILE = f'{SITE_DIR}/docs/_indexing-history.json'
GSC_SITE = 'sc-domain:37design.co.jp'
SITE_BASE = 'https://37design.co.jp'

def get_access_token(creds):
    params = {
        'client_id': creds['client_id'],
        'client_secret': creds['client_secret'],
        'refresh_token': creds['refresh_token'],
        'grant_type': 'refresh_token'
    }
    data = urllib.parse.urlencode(params).encode()
    req = urllib.request.Request(creds['token_uri'], data=data, method='POST')
    with urllib.request.urlopen(req) as res:
        return json.load(res)['access_token']

def inspect_url(token, page_url):
    body = json.dumps({'inspectionUrl': page_url, 'siteUrl': GSC_SITE}).encode()
    req = urllib.request.Request(
        'https://searchconsole.googleapis.com/v1/urlInspection/index:inspect',
        data=body,
        headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'}
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as res:
            return json.load(res).get('inspectionResult', {})
    except urllib.error.HTTPError as e:
        return {'error': f'HTTP {e.code}: {e.read().decode()[:200]}'}
    except Exception as e:
        return {'error': str(e)[:200]}

def parse_article(md_path):
    """1記事のメタ情報を抽出"""
    slug = os.path.basename(md_path).replace('.md', '')
    with open(md_path) as f:
        raw = f.read()
    # frontmatter抽出
    m = re.match(r'^---\n(.*?)\n---\n(.*)', raw, re.DOTALL)
    if m:
        frontmatter = m.group(1)
        body = m.group(2)
    else:
        frontmatter = ''
        body = raw
    publish_date = ''
    pd_match = re.search(r'^publishDate:\s*(\S+)', frontmatter, re.MULTILINE)
    if pd_match:
        publish_date = pd_match.group(1).strip('"\'')
    category = ''
    cat_match = re.search(r'^category:\s*"?([^"\n]+)"?', frontmatter, re.MULTILINE)
    if cat_match:
        category = cat_match.group(1).strip()
    h2_count = len(re.findall(r'^##\s+[^#]', body, re.MULTILINE))
    h3_count = len(re.findall(r'^###\s+[^#]', body, re.MULTILINE))
    char_count = len(body)
    return {
        'slug': slug,
        'publish_date': publish_date,
        'category': category,
        'char_count': char_count,
        'h2_count': h2_count,
        'h3_count': h3_count,
        'body': body
    }

def count_inbound_links(target_slug, all_articles):
    """target_slug への他記事からの被リンク数を数える"""
    pattern = f'/blog/{target_slug}/'
    count = 0
    refs = []
    for art in all_articles:
        if art['slug'] == target_slug:
            continue
        if pattern in art['body']:
            count += 1
            refs.append(art['slug'])
    return count, refs

def main():
    # 全記事のメタ情報
    md_files = sorted(glob.glob(f'{BLOG_DIR}/*.md'))
    articles = [parse_article(p) for p in md_files]
    print(f'[check-indexing] 記事数: {len(articles)}', file=sys.stderr)

    # 被リンク数集計
    for art in articles:
        n, refs = count_inbound_links(art['slug'], articles)
        art['inbound_links'] = n
        art['inbound_from'] = refs

    # GSC認証
    with open(CREDS_FILE) as f:
        creds = json.load(f)
    token = get_access_token(creds)

    # 各記事のGSC状態
    today = datetime.now().strftime('%Y-%m-%d')
    snapshot_articles = []
    for i, art in enumerate(articles):
        url = f"{SITE_BASE}/blog/{art['slug']}/"
        result = inspect_url(token, url)
        idx = result.get('indexStatusResult', {})
        snapshot_articles.append({
            'slug': art['slug'],
            'url': url,
            'publish_date': art['publish_date'],
            'category': art['category'],
            'char_count': art['char_count'],
            'h2_count': art['h2_count'],
            'h3_count': art['h3_count'],
            'inbound_links': art['inbound_links'],
            'inbound_from': art['inbound_from'],
            'verdict': idx.get('verdict', 'UNKNOWN'),
            'coverage_state': idx.get('coverageState', ''),
            'indexing_state': idx.get('indexingState', ''),
            'last_crawl_time': idx.get('lastCrawlTime', ''),
            'page_fetch_state': idx.get('pageFetchState', ''),
            'robots_txt_state': idx.get('robotsTxtState', ''),
            'google_canonical': idx.get('googleCanonical', ''),
            'user_canonical': idx.get('userCanonical', ''),
            'error': result.get('error', '')
        })
        time.sleep(0.2)  # レート制限対策
        if (i + 1) % 10 == 0:
            print(f'[check-indexing] {i+1}/{len(articles)}件診断完了', file=sys.stderr)

    # 履歴に追記
    os.makedirs(os.path.dirname(HISTORY_FILE), exist_ok=True)
    if os.path.exists(HISTORY_FILE):
        with open(HISTORY_FILE) as f:
            history = json.load(f)
    else:
        history = {'snapshots': [], 'actions': []}

    new_snapshot = {
        'date': today,
        'taken_at': datetime.now().isoformat(),
        'total': len(snapshot_articles),
        'indexed': sum(1 for a in snapshot_articles if a['verdict'] == 'PASS'),
        'not_indexed': sum(1 for a in snapshot_articles if a['verdict'] != 'PASS'),
        'articles': snapshot_articles
    }
    history['snapshots'].append(new_snapshot)
    # 古いスナップショット圧縮: 30日以上前は記事リスト捨ててサマリだけ残す
    cutoff = datetime.now().timestamp() - 30 * 86400
    for snap in history['snapshots'][:-1]:
        try:
            ts = datetime.fromisoformat(snap['taken_at']).timestamp()
            if ts < cutoff and 'articles' in snap:
                snap['articles_summary'] = {
                    'not_indexed_slugs': [a['slug'] for a in snap['articles'] if a.get('verdict') != 'PASS']
                }
                del snap['articles']
        except: pass

    with open(HISTORY_FILE, 'w') as f:
        json.dump(history, f, ensure_ascii=False, indent=2)

    # 状態変化検出（前回スナップショットと比較）
    prev = None
    if len(history['snapshots']) >= 2:
        prev = history['snapshots'][-2]
    changes = []
    if prev and 'articles' in prev:
        prev_map = {a['slug']: a for a in prev['articles']}
        for a in snapshot_articles:
            p = prev_map.get(a['slug'])
            if p and p.get('verdict') != a.get('verdict'):
                changes.append({
                    'slug': a['slug'],
                    'from': p.get('verdict'),
                    'to': a.get('verdict'),
                    'coverage_state': a.get('coverage_state')
                })

    # サマリ出力
    not_indexed = [a for a in snapshot_articles if a['verdict'] != 'PASS']
    summary = {
        'date': today,
        'total': new_snapshot['total'],
        'indexed': new_snapshot['indexed'],
        'not_indexed': new_snapshot['not_indexed'],
        'not_indexed_slugs': [a['slug'] for a in not_indexed],
        'changes': changes
    }
    print(json.dumps(summary, ensure_ascii=False, indent=2))

if __name__ == '__main__':
    main()
