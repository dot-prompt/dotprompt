# SEO Audit Report: dot-prompt

## Executive Summary

The dot-prompt website has a **solid foundation** with proper meta tags, Open Graph, Twitter cards, and structured data. However, there are several critical issues that need addressing to maximize organic search visibility.

---

## ✅ What's Working Well

### 1. SEO Component Quality
- ✅ Proper `<title>` and `<meta name="description">` tags
- ✅ Open Graph tags for Facebook/Meta
- ✅ Twitter Card tags
- ✅ Canonical URLs properly set
- ✅ JSON-LD structured data (WebSite/Article schema)
- ✅ Robots meta tags (index, follow)

### 2. Technical SEO
- ✅ Sitemap configured (`@astrojs/sitemap`)
- ✅ robots.txt properly configured
- ✅ Clean URL structure (`/docs/`, `/use-cases/`, `/why/`)
- ✅ Static site output (fast loading)

### 3. Content Structure
- ✅ Logical hierarchy with docs, use-cases, and why sections
- ✅ Internal linking through navigation

---

## ❌ Issues Found & Recommendations

### 🔴 Critical (Fix Immediately)

#### 1. Missing OG Image
**Issue**: The SEO component references `/og-image.png` but this file doesn't exist in the `/public` folder.

**Impact**: Social sharing will fail or show broken images.

**Fix**:
```
Create public/og-image.png (recommended: 1200x630px)
```

#### 2. No Schema Markup for Organization
**Issue**: Only basic WebSite/Article schema is implemented. Missing Organization schema for brand authority.

**Fix**: Add Organization schema to SEO component or create separate component.

```javascript
// Add to SEO.astro
{
  "@context": "https://schema.org",
  "@type": "Organization",
  "name": "dot-prompt",
  "url": "https://prompt.so",
  "logo": "https://prompt.so/logo.png",
  "sameAs": [
    "https://github.com/dot-prompt/dot-prompt"
  ]
}
```

#### 3. Documentation Pages Missing Structured Data
**Issue**: Docs pages use `type: 'article'` but don't include BreadcrumbList schema for navigation context.

**Fix**: Add breadcrumb structured data to DocsLayout.

---

### 🟠 High Priority

#### 4. No FAQ Schema
**Issue**: The site has FAQ content but no structured data to capture featured snippets.

**Fix**: Add FAQPage schema to relevant pages.

#### 5. Missing Hreflang for International SEO
**Issue**: No language/region tags for international visitors.

**Fix** (if international targeting is needed):
```html
<link rel="alternate" hreflang="en" href="https://prompt.so/" />
```

#### 6. Docs Pages Have Weak Meta Descriptions
**Issue**: Some doc pages rely on default description.

**Example**: `/docs/getting-started` → "Learn how to set up and use .prompt in your project" (too generic)

**Fix**: Add unique descriptions to each docs page frontmatter.

---

### 🟡 Medium Priority

#### 7. No Canonical HTTPS/www Consistency
**Issue**: Verify that all internal links use consistent domain (prompt.so vs www.prompt.so)

**Fix**: Ensure all links in content match the canonical domain.

#### 8. Missing Viewport Warning
**Issue**: Verify all pages have proper viewport meta tag (appears OK in layouts).

#### 9. No Pagination Schema
**Issue**: If docs have pagination, needs proper rel/rel-next implementation.

---

### 🟢 Low Priority / Enhancements

#### 10. Add BreadcrumbNav microdata
**Implementation**: Use Schema.org BreadcrumbList on all pages with parent sections.

#### 11. Add VideoSchema if demos are added
**Implementation**: If video tutorials are added, implement VideoObject schema.

#### 12. Consider adding Product schema
**Note**: If dot-prompt is commercial, add SoftwareApplication or Product schema.

---

## 📋 Implementation Priority

| Priority | Task | Effort |
|----------|------|--------|
| 1 | Create OG Image | Low |
| 2 | Add Organization schema | Medium |
| 3 | Add FAQ schema | Medium |
| 4 | Enhance docs meta descriptions | Low |
| 5 | Add breadcrumb schema | Medium |
| 6 | Verify internal link consistency | Low |

---

## 📊 Estimated SEO Impact

- **Quick wins**: +15-25% SERP visibility (OG image, org schema)
- **Featured snippets**: +5-10% CTR potential (FAQ schema)
- **Brand authority**: Improved E-E-A-T signals

---

## 🎯 Next Steps

1. Create `public/og-image.png` (1200x630px)
2. Update SEO component with Organization schema
3. Add unique descriptions to all doc pages
4. Consider FAQ schema for key pages
5. Deploy and submit updated sitemap to Google Search Console