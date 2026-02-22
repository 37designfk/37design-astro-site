import json, subprocess, sys, os
from datetime import datetime, timedelta

SITE_DIR = '/home/ken/37design-astro-site'
LOCK_FILE = f'{SITE_DIR}/.article-lock.json'
LOCK_DAYS = 7

try:
    with open(LOCK_FILE) as f:
        locks = json.load(f)
except:
    locks = {}

cutoff = datetime.now() - timedelta(days=LOCK_DAYS)
locks = {k: v for k, v in locks.items() if datetime.fromisoformat(v) > cutoff}
print(f'ロック中記事: {len(locks)}件')
for slug, ts in locks.items():
    unlock = (datetime.fromisoformat(ts) + timedelta(days=LOCK_DAYS)).strftime('%Y-%m-%d')
    print(f'  - {slug} (解除: {unlock})')
print()

def is_locked(slug):
    return slug in locks and datetime.fromisoformat(locks[slug]) > cutoff

def lock_article(slug):
    locks[slug] = datetime.now().isoformat()
    with open(LOCK_FILE, 'w') as f:
        json.dump(locks, f, indent=2)

with open('/tmp/daily-tasks.json') as f:
    plan = json.load(f)

tasks = plan.get('tasks', [])
print(f'タスク数: {len(tasks)}')
print(f'サマリー: {plan.get("summary","")}')
print()

env = os.environ.copy()
env['PATH'] = f'/home/ken/.local/bin:{env["PATH"]}'
env.pop('CLAUDECODE', None)

for i, task in enumerate(tasks):
    action = task.get('action')

    if action == 'rewrite':
        slug = task.get('slug', '')
        keyword = task.get('target_keyword', '')
        focus = task.get('focus', 'タイトル改善・meta改善・本文充実')
        reason = task.get('reason', '')
        print(f'[{i+1}] rewrite: {slug}')
        print(f'  キーワード: {keyword}')
        print(f'  理由: {reason[:80]}')
        if is_locked(slug):
            unlock = (datetime.fromisoformat(locks[slug]) + timedelta(days=LOCK_DAYS)).strftime('%Y-%m-%d')
            print(f'  スキップ: ロック中（解除: {unlock}）')
        else:
            r = subprocess.run(['bash', f'{SITE_DIR}/scripts/improve-article.sh', slug, keyword, focus], env=env)
            if r.returncode == 0:
                lock_article(slug)
                print(f'  完了 + {LOCK_DAYS}日間ロック設定')
            else:
                print(f'  エラー (code={r.returncode})')

    elif action == 'new_article':
        keyword = task.get('keyword', '')
        theme = task.get('theme', keyword)
        reason = task.get('reason', '')
        print(f'[{i+1}] new_article: {keyword}')
        print(f'  テーマ: {theme}')
        print(f'  理由: {reason[:80]}')
        r = subprocess.run(['bash', f'{SITE_DIR}/scripts/research-and-generate.sh', theme, '1'], env=env)
        print(f'  {"完了" if r.returncode == 0 else "エラー (code=" + str(r.returncode) + ")"}')

    print()

print('=== 全タスク実行完了 ===')
