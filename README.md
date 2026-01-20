# System Voice Memos Website

This is the official website for System Voice Memos, a native macOS app for recording system audio.

## Structure

```
website/
├── index.html          # Main landing page
├── privacy.html        # Privacy policy
├── 404.html            # Custom 404 page
├── css/
│   └── style.css       # Main stylesheet
├── js/
│   └── main.js         # JavaScript functionality
├── images/             # Image assets
├── CNAME               # Custom domain configuration
├── robots.txt          # Search engine directives
├── sitemap.xml         # Sitemap for SEO
└── .nojekyll           # Disable Jekyll processing
```

## Development

To preview the website locally, you can use any static file server:

```bash
# Using Python
cd website
python3 -m http.server 8000

# Using Node.js (npx)
npx serve website

# Using PHP
cd website
php -S localhost:8000
```

Then open http://localhost:8000 in your browser.

## Deployment

The website is automatically deployed to GitHub Pages when changes are pushed to the `website` branch. The deployment is handled by the GitHub Actions workflow at `.github/workflows/deploy-website.yml`.

## Adding Screenshots

To add app screenshots:

1. Take screenshots of the app
2. Optimize them for web (compress, resize to reasonable dimensions)
3. Add them to the `images/` directory
4. Update the `screenshot-placeholder` div in `index.html` with an `<img>` tag

## Customization

- **Colors**: Edit CSS variables in `css/style.css` under `:root`
- **Content**: Edit `index.html` for main page content
- **Domain**: Update `CNAME` file with your custom domain

## Technologies Used

- HTML5
- CSS3 (with CSS Variables)
- Vanilla JavaScript
- [Lucide Icons](https://lucide.dev/)
- [Inter Font](https://fonts.google.com/specimen/Inter)
