-- ============================================================
-- 37Design Marketing OS - PostgreSQL Schema
-- Created: 2026-02-21
-- ============================================================

BEGIN;

-- ============================================================
-- 1. clients - Client configuration
-- ============================================================
CREATE TABLE clients (
  id VARCHAR(50) PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  site_url VARCHAR(255) NOT NULL,
  astro_project_path VARCHAR(255) NOT NULL,
  ga4_property_id VARCHAR(50),
  gsc_site_url VARCHAR(255),
  clarity_project_id VARCHAR(50),
  growthbook_project_key VARCHAR(100),
  mautic_segment_ids JSONB,
  sns_accounts JSONB,
  competitor_urls TEXT[],
  notification_channel VARCHAR(100),
  plan VARCHAR(20) DEFAULT 'standard',
  monthly_task_limit INT DEFAULT 100,
  claude_md_path VARCHAR(255),
  config JSONB,
  active BOOLEAN DEFAULT true,
  last_processed_at TIMESTAMP DEFAULT '1970-01-01',
  created_at TIMESTAMP DEFAULT NOW()
);

-- ============================================================
-- 2. task_queue - Task queue
-- ============================================================
CREATE TABLE task_queue (
  id SERIAL PRIMARY KEY,
  client_id VARCHAR(50) NOT NULL,
  task_type VARCHAR(50) NOT NULL,
  content_type VARCHAR(20),
  priority INT DEFAULT 5,
  status VARCHAR(20) DEFAULT 'pending',
  assigned_to VARCHAR(30),
  payload JSONB NOT NULL,
  result JSONB,
  kpi_trigger VARCHAR(50),
  task_key TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  started_at TIMESTAMP,
  completed_at TIMESTAMP,
  heartbeat_at TIMESTAMP,
  execution_seconds INT,
  depends_on INT[],
  retry_count INT DEFAULT 0,
  max_retries INT DEFAULT 3,
  max_fix_iterations INT DEFAULT 3,
  fix_iteration_count INT DEFAULT 0,
  error_log TEXT
);
CREATE INDEX idx_task_status ON task_queue(status);
CREATE INDEX idx_task_client ON task_queue(client_id);
CREATE INDEX idx_task_priority ON task_queue(priority, created_at);
CREATE INDEX idx_task_content_type ON task_queue(content_type);

-- ============================================================
-- 3. schedule_policy - Time slot scheduling
-- ============================================================
CREATE TABLE schedule_policy (
  id SERIAL PRIMARY KEY,
  time_slot VARCHAR(20) NOT NULL,
  hour_start INT NOT NULL,
  hour_end INT NOT NULL,
  allowed_task_types TEXT[],
  blocked_task_types TEXT[],
  max_concurrent JSONB NOT NULL,
  description TEXT
);
INSERT INTO schedule_policy VALUES
(1, 'night_heavy', 0, 9, NULL, NULL, '{"qwen3_8b":3,"qwen3_30b":1,"claude_api":5,"claude_code":1}', '深夜〜早朝: 重タスク集中'),
(2, 'day_light', 9, 18, ARRAY['meta_optimize','data_format','quality_check','report_generate','sns_post','image_generate'], NULL, '{"qwen3_8b":3,"qwen3_30b":1,"claude_api":3,"claude_code":0}', '昼間: 軽タスク中心'),
(3, 'evening_medium', 18, 24, NULL, NULL, '{"qwen3_8b":3,"qwen3_30b":1,"claude_api":5,"claude_code":1}', '夕方〜夜: 中〜重タスク');

-- ============================================================
-- 4. active_task_keys - Deduplication
-- ============================================================
CREATE TABLE active_task_keys (
  task_key TEXT PRIMARY KEY,
  client_id VARCHAR(50) NOT NULL,
  task_id INT,
  status VARCHAR(10) DEFAULT 'reserved',
  created_at TIMESTAMP DEFAULT NOW()
);

-- ============================================================
-- 5. page_locks - Page edit locks
-- ============================================================
CREATE TABLE page_locks (
  client_id VARCHAR(50) NOT NULL,
  page_slug VARCHAR(255) NOT NULL,
  lock_until TIMESTAMP NOT NULL,
  reason VARCHAR(50) NOT NULL,
  locked_by_task_id INT,
  created_at TIMESTAMP DEFAULT NOW(),
  PRIMARY KEY (client_id, page_slug)
);
CREATE INDEX idx_page_locks_active ON page_locks(client_id, lock_until);

-- ============================================================
-- 6. observation_lock_policy - Lock duration per content type
-- ============================================================
CREATE TABLE observation_lock_policy (
  id SERIAL PRIMARY KEY,
  content_type VARCHAR(20) NOT NULL UNIQUE,
  lock_days INT NOT NULL
);
INSERT INTO observation_lock_policy VALUES (1, 'blog', 7), (2, 'page', 14), (3, 'lp', 14);

-- ============================================================
-- 7. daily_limits - Per-client daily action limits
-- ============================================================
CREATE TABLE daily_limits (
  id SERIAL PRIMARY KEY,
  client_id VARCHAR(50) REFERENCES clients(id),
  action_category VARCHAR(20) NOT NULL,
  max_per_day INT NOT NULL,
  current_today INT DEFAULT 0,
  reset_at DATE DEFAULT CURRENT_DATE
);

-- ============================================================
-- 8. kpi_targets - KPI targets and gaps
-- ============================================================
CREATE TABLE kpi_targets (
  id SERIAL PRIMARY KEY,
  client_id VARCHAR(50) REFERENCES clients(id),
  metric VARCHAR(50) NOT NULL,
  target_value DECIMAL NOT NULL,
  current_value DECIMAL,
  gap DECIMAL,
  priority_weight DECIMAL DEFAULT 1.0,
  last_updated TIMESTAMP,
  trend VARCHAR(20)
);

-- ============================================================
-- 9. kpi_history - Historical KPI values
-- ============================================================
CREATE TABLE kpi_history (
  id SERIAL PRIMARY KEY,
  client_id VARCHAR(50) REFERENCES clients(id),
  metric VARCHAR(50) NOT NULL,
  value DECIMAL NOT NULL,
  recorded_at DATE NOT NULL,
  source VARCHAR(20)
);
CREATE INDEX idx_kpi_history_client_date ON kpi_history(client_id, recorded_at DESC);

-- ============================================================
-- 10. kpi_breakdown - Per-page KPI breakdown
-- ============================================================
CREATE TABLE kpi_breakdown (
  id SERIAL PRIMARY KEY,
  client_id VARCHAR(50) REFERENCES clients(id),
  page_path VARCHAR(255) NOT NULL,
  recorded_at DATE NOT NULL,
  mobile_sessions INT, mobile_bounce_rate DECIMAL, mobile_cvr DECIMAL,
  desktop_sessions INT, desktop_bounce_rate DECIMAL, desktop_cvr DECIMAL,
  organic_sessions INT, organic_cvr DECIMAL,
  ads_sessions INT, ads_cvr DECIMAL,
  referral_sessions INT, referral_cvr DECIMAL,
  direct_sessions INT, direct_cvr DECIMAL,
  new_user_sessions INT, new_user_cvr DECIMAL,
  returning_user_sessions INT, returning_user_cvr DECIMAL,
  clarity_scroll_depth_avg DECIMAL, clarity_dead_click_count INT,
  clarity_rage_click_count INT, clarity_top_exit_section VARCHAR(100),
  CONSTRAINT uq_kpi_breakdown_unique UNIQUE (client_id, page_path, recorded_at)
);
CREATE INDEX idx_breakdown_client_page ON kpi_breakdown(client_id, page_path, recorded_at DESC);

-- ============================================================
-- 11. keyword_clusters - Keyword grouping
-- ============================================================
CREATE TABLE keyword_clusters (
  id SERIAL PRIMARY KEY,
  client_id VARCHAR(50) REFERENCES clients(id),
  cluster_name VARCHAR(100) NOT NULL,
  main_keyword VARCHAR(200) NOT NULL,
  search_intent VARCHAR(20),
  related_keywords TEXT[],
  target_lp VARCHAR(255),
  created_at TIMESTAMP DEFAULT NOW()
);
CREATE INDEX idx_cluster_client ON keyword_clusters(client_id);

-- ============================================================
-- 12. content_keywords - Per-page keyword assignments
-- ============================================================
CREATE TABLE content_keywords (
  id SERIAL PRIMARY KEY,
  client_id VARCHAR(50) REFERENCES clients(id),
  page_slug VARCHAR(255) NOT NULL,
  content_type VARCHAR(20) NOT NULL,
  keyword VARCHAR(200) NOT NULL,
  cluster_id INT REFERENCES keyword_clusters(id),
  intent VARCHAR(20),
  is_primary BOOLEAN DEFAULT false,
  created_at TIMESTAMP DEFAULT NOW()
);
CREATE INDEX idx_content_kw_cluster ON content_keywords(cluster_id);
CREATE INDEX idx_content_kw_client_slug ON content_keywords(client_id, page_slug);

-- ============================================================
-- 13. page_freshness - Content freshness tracking
-- ============================================================
CREATE TABLE page_freshness (
  id SERIAL PRIMARY KEY,
  client_id VARCHAR(50) REFERENCES clients(id),
  page_slug VARCHAR(255) NOT NULL,
  content_type VARCHAR(20) NOT NULL,
  published_at TIMESTAMP, last_modified_at TIMESTAMP, last_improved_at TIMESTAMP,
  days_since_update INT, ctr_trend VARCHAR(20), position_trend VARCHAR(20),
  bounce_trend VARCHAR(20), freshness_score DECIMAL, needs_refresh BOOLEAN DEFAULT false,
  updated_at TIMESTAMP DEFAULT NOW(),
  CONSTRAINT uq_page_freshness_unique UNIQUE (client_id, page_slug)
);
CREATE INDEX idx_freshness_client ON page_freshness(client_id, needs_refresh) WHERE needs_refresh = true;

-- ============================================================
-- 14. quality_rules - Content quality checks
-- ============================================================
CREATE TABLE quality_rules (
  id SERIAL PRIMARY KEY,
  content_type VARCHAR(20) NOT NULL,
  rule_name VARCHAR(100) NOT NULL,
  rule_type VARCHAR(20) NOT NULL,
  check_query TEXT NOT NULL,
  enabled BOOLEAN DEFAULT true
);
INSERT INTO quality_rules (content_type, rule_name, rule_type, check_query) VALUES
('blog', 'min_word_count', 'required', '本文3000字以上'),
('blog', 'min_h2_count', 'required', 'h2が5個以上'),
('blog', 'min_internal_links', 'required', '内部リンク3本以上'),
('blog', 'has_meta_description', 'required', 'meta descriptionが設定されている'),
('blog', 'all_images_have_alt', 'required', '全画像にalt属性あり'),
('blog', 'has_structured_data', 'required', 'Article構造化データあり'),
('blog', 'no_prohibited_terms', 'required', '禁止表現なし（誇大広告・断定・薬機法リスク）'),
('lp', 'min_cta_count', 'required', 'CTAが3箇所以上'),
('lp', 'has_social_proof', 'required', 'お客様の声/実績セクションあり'),
('lp', 'mobile_first_check', 'required', 'モバイルファースト構造'),
('lp', 'has_structured_data', 'required', '構造化データあり'),
('lp', 'no_prohibited_terms', 'required', '禁止表現なし'),
('lp', 'all_images_have_alt', 'required', '全画像にalt属性あり'),
('page', 'has_internal_links', 'required', '回遊リンク2本以上'),
('page', 'has_structured_data', 'warning', '構造化データの有無'),
('page', 'all_images_have_alt', 'required', '全画像にalt属性あり');

-- ============================================================
-- 15. task_performance - Task execution metrics
-- ============================================================
CREATE TABLE task_performance (
  id SERIAL PRIMARY KEY,
  task_type VARCHAR(50) NOT NULL,
  content_type VARCHAR(20),
  assigned_to VARCHAR(30) NOT NULL,
  execution_time_seconds INT,
  quality_score DECIMAL,
  kpi_impact JSONB,
  created_at TIMESTAMP DEFAULT NOW()
);

-- ============================================================
-- 16. ab_tests - A/B test tracking
-- ============================================================
CREATE TABLE ab_tests (
  id SERIAL PRIMARY KEY,
  client_id VARCHAR(50) REFERENCES clients(id),
  growthbook_experiment_id VARCHAR(100),
  target_page VARCHAR(255),
  hypothesis TEXT,
  variations JSONB,
  metrics TEXT[],
  status VARCHAR(20) DEFAULT 'running',
  min_sample_size INT DEFAULT 500,
  min_duration_days INT DEFAULT 7,
  max_duration_days INT DEFAULT 21,
  total_samples INT DEFAULT 0,
  started_at TIMESTAMP DEFAULT NOW(),
  ended_at TIMESTAMP,
  result JSONB
);
CREATE UNIQUE INDEX idx_ab_one_per_page ON ab_tests(client_id, target_page) WHERE status = 'running';

-- ============================================================
-- 17. competitor_pages - Competitor monitoring
-- ============================================================
CREATE TABLE competitor_pages (
  id SERIAL PRIMARY KEY,
  client_id VARCHAR(50) REFERENCES clients(id),
  competitor_url VARCHAR(255) NOT NULL,
  page_url VARCHAR(500) NOT NULL,
  page_title TEXT,
  first_seen DATE NOT NULL,
  last_seen DATE NOT NULL,
  status VARCHAR(20) DEFAULT 'active',
  summary TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);
CREATE INDEX idx_competitor_client ON competitor_pages(client_id, competitor_url);

-- ============================================================
-- 18. sns_posts - Social media post tracking
-- ============================================================
CREATE TABLE sns_posts (
  id SERIAL PRIMARY KEY,
  client_id VARCHAR(50) REFERENCES clients(id),
  platform VARCHAR(20) NOT NULL,
  content_source VARCHAR(255),
  post_text TEXT NOT NULL,
  post_url VARCHAR(500),
  posted_at TIMESTAMP,
  engagement JSONB,
  engagement_updated_at TIMESTAMP
);

-- ============================================================
-- Initial data: Self-client record
-- ============================================================
INSERT INTO clients (id, name, site_url, astro_project_path, ga4_property_id, gsc_site_url, plan, claude_md_path) VALUES
('37design', '株式会社37Design', 'https://37design.co.jp', '/home/ken/37design-astro-site', '339140925', 'https://37design.co.jp', 'premium', '/home/ken/37design-astro-site/CLAUDE.md');

-- ============================================================
-- Initial data: Daily limits for self-client
-- ============================================================
INSERT INTO daily_limits (client_id, action_category, max_per_day) VALUES
('37design', 'generate', 2),
('37design', 'improve', 3),
('37design', 'ab_test', 1);

COMMIT;
