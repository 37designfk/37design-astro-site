#!/usr/bin/env python3
"""GA4 + Search Console データを取得してJSONに保存"""
import json
import urllib.request
import urllib.parse
import urllib.error
from datetime import datetime, timedelta
import os

CREDS_FILE = os.path.expanduser('~/37design-astro-site/.google-credentials.json')
OUTPUT_FILE = os.path.expanduser('~/37design-astro-site/.analytics-cache.json')
GA4_PROPERTY = '339140925'
GSC_SITE = 'sc-domain:37design.co.jp'

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

def ga4_report(token, body):
    data = json.dumps(body).encode()
    req = urllib.request.Request(
        f'https://analyticsdata.googleapis.com/v1beta/properties/{GA4_PROPERTY}:runReport',
        data=data,
        headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'}
    )
    with urllib.request.urlopen(req) as res:
        return json.load(res)

def gsc_query(token, body):
    site = urllib.parse.quote(GSC_SITE, safe='')
    data = json.dumps(body).encode()
    req = urllib.request.Request(
        f'https://www.googleapis.com/webmasters/v3/sites/{site}/searchAnalytics/query',
        data=data,
        headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'}
    )
    try:
        with urllib.request.urlopen(req) as res:
            return json.load(res)
    except urllib.error.HTTPError:
        return {'rows': []}

def main():
    with open(CREDS_FILE) as f:
        creds = json.load(f)
    token = get_access_token(creds)

    # GA4: サマリー（28日）
    summary = ga4_report(token, {
        'dateRanges': [{'startDate': '28daysAgo', 'endDate': 'today'}],
        'metrics': [
            {'name': 'sessions'},
            {'name': 'activeUsers'},
            {'name': 'screenPageViews'},
            {'name': 'bounceRate'},
            {'name': 'averageSessionDuration'}
        ]
    })
    metrics = {}
    if summary.get('rows'):
        for i, h in enumerate(summary.get('metricHeaders', [])):
            metrics[h['name']] = summary['rows'][0]['metricValues'][i]['value']

    # GA4: 前28日比較
    prev = ga4_report(token, {
        'dateRanges': [{'startDate': '56daysAgo', 'endDate': '29daysAgo'}],
        'metrics': [{'name': 'sessions'}, {'name': 'activeUsers'}]
    })
    prev_metrics = {}
    if prev.get('rows'):
        for i, h in enumerate(prev.get('metricHeaders', [])):
            prev_metrics[h['name']] = prev['rows'][0]['metricValues'][i]['value']

    # GA4: ページ別PV Top10
    pages = ga4_report(token, {
        'dateRanges': [{'startDate': '28daysAgo', 'endDate': 'today'}],
        'dimensions': [{'name': 'pagePath'}],
        'metrics': [{'name': 'screenPageViews'}],
        'limit': 10,
        'orderBys': [{'metric': {'metricName': 'screenPageViews'}, 'desc': True}]
    })
    top_pages = []
    for row in pages.get('rows', []):
        top_pages.append({
            'path': row['dimensionValues'][0]['value'],
            'pv': int(row['metricValues'][0]['value'])
        })

    # GSC: トップキーワード
    end = datetime.now().strftime('%Y-%m-%d')
    start = (datetime.now() - timedelta(days=28)).strftime('%Y-%m-%d')
    gsc_data = gsc_query(token, {
        'startDate': start,
        'endDate': end,
        'dimensions': ['query'],
        'rowLimit': 10,
        'orderBy': [{'fieldName': 'clicks', 'sortOrder': 'DESCENDING'}]
    })
    top_queries = []
    for row in gsc_data.get('rows', []):
        top_queries.append({
            'query': row['keys'][0],
            'clicks': int(row['clicks']),
            'impressions': int(row['impressions']),
            'ctr': round(row['ctr'] * 100, 1),
            'position': round(row['position'], 1)
        })

    # GSC: ページ別
    gsc_pages = gsc_query(token, {
        'startDate': start,
        'endDate': end,
        'dimensions': ['page'],
        'rowLimit': 10,
        'orderBy': [{'fieldName': 'clicks', 'sortOrder': 'DESCENDING'}]
    })
    top_gsc_pages = []
    for row in gsc_pages.get('rows', []):
        top_gsc_pages.append({
            'page': row['keys'][0],
            'clicks': int(row['clicks']),
            'impressions': int(row['impressions']),
            'ctr': round(row['ctr'] * 100, 1),
            'position': round(row['position'], 1)
        })

    result = {
        'updated_at': datetime.now().isoformat(),
        'period': {'start': start, 'end': end},
        'ga4': {
            'sessions': int(metrics.get('sessions', 0)),
            'users': int(metrics.get('activeUsers', 0)),
            'pageviews': int(metrics.get('screenPageViews', 0)),
            'bounce_rate': round(float(metrics.get('bounceRate', 0)) * 100, 1),
            'avg_session_sec': round(float(metrics.get('averageSessionDuration', 0))),
            'prev_sessions': int(prev_metrics.get('sessions', 0)),
            'prev_users': int(prev_metrics.get('activeUsers', 0)),
            'top_pages': top_pages
        },
        'gsc': {
            'top_queries': top_queries,
            'top_pages': top_gsc_pages
        }
    }

    with open(OUTPUT_FILE, 'w') as f:
        json.dump(result, f, ensure_ascii=False, indent=2)

    # n8nコンテナ内にもコピー
    import subprocess
    subprocess.run(["docker", "cp", OUTPUT_FILE, "n8n:/home/node/.n8n/analytics-cache.json"], capture_output=True)

    print(json.dumps(result, ensure_ascii=False, indent=2))

if __name__ == '__main__':
    main()
