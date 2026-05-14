#!/usr/bin/env node
// blog記事生成用のコンテキストファイル(_blog-context.json)を生成する。
// Mac側で実行 → git commit → サーバーで daily-loop.sh が pull して読み込む。
//
// 素材ソース:
//   - ~/customer-voices/voices.json (approval=approved のみ)
//   - ~/37design-astro-site/scripts/prompts/furuta_voice.md (古田さんの口調・スタンス)
// reflections は誤公開リスク回避のため現時点では含めない。
// blog_safe フラグ実装後に追加予定。

import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';

const HOME = os.homedir();
const VOICES_PATH = path.join(HOME, 'customer-voices', 'voices.json');
const FURUTA_VOICE_PATH = path.join(HOME, '37design-astro-site', 'scripts', 'prompts', 'furuta_voice.md');
const OUTPUT_PATH = path.join(HOME, '37design-astro-site', 'scripts', '_blog-context.json');

function loadVoices() {
  if (!fs.existsSync(VOICES_PATH)) return [];
  const raw = JSON.parse(fs.readFileSync(VOICES_PATH, 'utf-8'));
  const voices = raw.voices || [];
  return voices
    .filter(v => v.approval === 'approved')
    .map(v => ({
      id: v.id,
      public_label: v.public_label || v.client_label || '匿名のクライアント',
      industry: v.industry || '',
      before: v.before || '',
      solution: v.solution || '',
      after: v.after || '',
      quote: v.quote || '',
      numbers: v.numbers || [],
      tags: v.tags || []
    }));
}

function loadFurutaTone() {
  if (!fs.existsSync(FURUTA_VOICE_PATH)) {
    return '';
  }
  return fs.readFileSync(FURUTA_VOICE_PATH, 'utf-8').trim();
}

const voices = loadVoices();
const furutaTone = loadFurutaTone();

const context = {
  generated_at: new Date().toISOString(),
  voices,
  voices_count: voices.length,
  furuta_tone: furutaTone,
  has_furuta_tone: furutaTone.length > 0
};

fs.writeFileSync(OUTPUT_PATH, JSON.stringify(context, null, 2));
console.log(`[build-blog-context] voices=${voices.length} furuta_tone=${furutaTone.length}文字`);
console.log(`[build-blog-context] -> ${OUTPUT_PATH}`);
