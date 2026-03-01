export interface NewsItem {
  date: string;
  text: string;
}

export interface FAQ {
  q: string;
  a: string;
}

export interface InquiryType {
  label: string;
  value: string;
}

export interface PlanStarter {
  name: string;
  subtitle: string;
  price: string;
  unit: string;
  period: string;
  features: string[];
  cta: string;
  popular: boolean;
}

export interface PlanAiConsultant {
  name: string;
  description: string;
  price: string;
  roi: string;
  included: string[];
  excluded: string[];
  recommended: boolean;
}

export interface Capability {
  title: string;
  description: string;
  icon: string;
}

export interface Step {
  title: string;
  description: string;
}

export interface Feature {
  icon: string;
  title: string;
  description: string;
}

export interface ComparisonRow {
  label: string;
  online: boolean;
  dedicated: boolean;
}

export interface CaseStudyMetric {
  label: string;
  value: string;
  width: string;
}

export interface CaseStudy {
  industry: string;
  employeeCount: string;
  gradientClass: string;
  iconBgClass: string;
  iconTextClass: string;
  iconPath: string;
  problem: string;
  solution: string;
  metrics: CaseStudyMetric[];
  quote: string;
  quoteAuthor: string;
  planBadge: string;
}

export interface ServiceItem {
  name: string;
  description: string;
}

export interface ServiceCategory {
  category: string;
  icon: string;
  color: string;
  services: ServiceItem[];
}
