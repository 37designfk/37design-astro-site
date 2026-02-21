import { defineCollection, z } from 'astro:content';

const blog = defineCollection({
  type: 'content',
  schema: z.object({
    title: z.string(),
    description: z.string(),
    publishDate: z.date(),
    author: z.string().default('古田 健'),
    category: z.enum(['AI', '業務自動化', 'マーケティング', 'CRM', 'お知らせ', 'SEO', 'LP制作']),
    tags: z.array(z.string()).optional(),
    image: z.string().optional(),
    targetKeyword: z.string().optional(),
    relatedArticles: z.array(z.string()).optional(),
    targetLP: z.string().optional(),
    structuredDataType: z.enum(['Article', 'HowTo', 'FAQPage']).default('Article'),
    lastModified: z.date().optional(),
    noIndex: z.boolean().default(false),
  }),
});

export const collections = {
  blog,
};
