# SociWave - Deployment Instructions

**Date:** November 20, 2025  
**Build Status:** ✅ Complete  
**Build Size:** 31MB (2.7MB main app)

---

## 🎉 Build Complete!

Your SociWave web app is ready for deployment. The optimized build is in:
```
webapp/build/web/
```

---

## 🚀 Deployment Options

Choose one of the following hosting platforms:

---

### Option 1: Netlify (Recommended - Easiest) ⭐

**Why Netlify:**
- ✅ Free tier (100GB bandwidth/month)
- ✅ Automatic HTTPS
- ✅ Easy drag-and-drop deployment
- ✅ Git integration
- ✅ Instant rollback

#### **Method A: Drag & Drop (Fastest)**

1. **Go to Netlify:**
   - Visit: https://netlify.com
   - Click "Sign Up" (use GitHub account)

2. **Deploy Site:**
   - Click "Add new site" → "Deploy manually"
   - Drag the `build/web` folder into the upload zone
   Your SociWave web app is ready for deployment. The optimized build is in:
   ```
   webapp/build/web/
   ```
   - You can customize: Site settings → Change site name

4. **Custom Domain (Optional):**
   - Site settings → Domain management
   - Add your own domain
   - Update DNS records

#### **Method B: Git Integration (Automatic Deploys)**

1. **Push to GitHub:**
   ```bash
   cd <path-to-repo-root>
   git add .
   git commit -m "Phase 7: Web deployment ready"
   git push origin main
   ```
   - Configure:
     - Base directory: `app`
     - Build command: `flutter build web --release --tree-shake-icons`
     - Publish directory: `webapp/build/web`

3. **Deploy:**
      ```bash
      cd webapp
      flutter build web --release --base-href "/sociwave/"
      ```

   Netlify will provide a temporary site URL (or your custom domain after configuration).

---

2. **Build with Correct Base Href:**
   ```bash
   cd webapp
   flutter build web --release --base-href "/sociwave/"
   ```

3. **Create gh-pages Branch (optional):**
   ```bash
   cd <path-to-repo-root>
   git checkout --orphan gh-pages
   git rm -rf .
   cp -r webapp/build/web/* .
   git add .
   git commit -m "Deploy to GitHub Pages"
   git push origin gh-pages
   ```

For Vercel, Netlify, and other hosts, set the publish/output directory to `webapp/build/web` and use `flutter build web --release --tree-shake-icons` as the build command.

---

### Option 3: GitHub Pages (Free Forever) 🎁

**Why GitHub Pages:**
- ✅ 100% free (no limits)
- ✅ Integrated with GitHub
- ✅ Custom domain support
- ✅ HTTPS included

#### **Deployment Steps:**

1. **Build with Correct Base Href:**
   ```bash
   cd webapp
   flutter build web --release --base-href "/sociwave/"
   ```

2. **Create gh-pages Branch:**
   ```bash
   cd <path-to-repo-root>
   git checkout --orphan gh-pages
   git rm -rf .
   ```

3. **Copy Build Files:**
   ```bash
   cp -r webapp/build/web/* .
   git add .
   git commit -m "Deploy to GitHub Pages"
   git push origin gh-pages
   ```

4. **Enable GitHub Pages:**
   - Go to: https://github.com/HauTranCong/sociwave/settings/pages
   - Source: **gh-pages** branch
   - Folder: **/ (root)**
   - Save

5. **Wait & Access:**
   - Wait 1-2 minutes
   - Visit: `https://hautracong.github.io/sociwave/`

**GitHub Pages URL:**
```
https://hautracong.github.io/sociwave/
```

---

## 📝 Post-Deployment Checklist

After deploying, verify:

### Functionality Tests
- [ ] Login works
- [ ] API configuration saves
- [ ] Can fetch reels
- [ ] Can create/edit rules
- [ ] Can view comments
- [ ] Background monitoring toggles on/off
- [ ] Logout works

### Browser Compatibility
- [ ] Chrome (latest)
- [ ] Firefox (latest)
- [ ] Safari (latest, if available)
- [ ] Edge (latest)

### Mobile Responsiveness
- [ ] Works on mobile browser (Chrome Mobile)
- [ ] Navigation is usable
- [ ] Forms are accessible
- [ ] Buttons are tappable

### Performance
- [ ] Page loads in < 5 seconds
- [ ] No console errors
- [ ] Navigation is smooth
- [ ] API calls work

---

## 🌐 Update URLs in Code (Optional)

If you want to update Open Graph URLs in index.html:

```bash
cd webapp/web
```

Edit `index.html` and replace:
```html
<meta property="og:url" content="https://sociwave.webapp/">
```

With your actual URL:
```html
<meta property="og:url" content="https://sociwave.netlify.webapp/">
```

Then rebuild:
```bash
flutter build web --release --tree-shake-icons
```

---

## 🔧 Custom Domain Setup

### For Netlify:
1. Site settings → Domain management
2. Add custom domain
3. Update DNS:
   ```
   Type: CNAME
   Name: @ or www
   Value: your-site.netlify.app
   ```

### For Vercel:
1. Project settings → Domains
2. Add domain
3. Update DNS:
   ```
   Type: CNAME
   Name: @ or www
   Value: cname.vercel-dns.com
   ```

### For GitHub Pages:
1. Add `CNAME` file to gh-pages branch:
   ```bash
   echo "yourdomain.com" > CNAME
   git add CNAME
   git commit -m "Add custom domain"
   git push
   ```
2. Update DNS:
   ```
   Type: A
   Name: @
   Value: 185.199.108.153
   Value: 185.199.109.153
   Value: 185.199.110.153
   Value: 185.199.111.153
   ```

---

## 📊 Performance Optimization Tips

### If App is Slow:
1. **Enable Gzip Compression:**
   - Netlify/Vercel: Automatic
   - GitHub Pages: Automatic
   - Custom server: Configure nginx/apache

2. **Use CDN:**
   - Netlify/Vercel: Built-in CDN
   - GitHub Pages: GitHub CDN

3. **Cache Static Assets:**
   - Configure cache headers
   - Service worker handles this automatically

---

## ⚠️ Important Reminders

### Browser Must Stay Open
The web version requires the browser to remain open for:
- Background monitoring (5-minute intervals)
- Auto-refresh (30-second comments)
- API calls

**To close browser:** Stop monitoring first, or monitoring will pause.

**For 24/7 operation:** Proceed with Phase 8 (Backend Server)

---

## 🐛 Troubleshooting

### Issue: White screen after deployment
**Solution:** 
- Check browser console for errors
- Verify `base href` matches deployment path
- Clear browser cache

### Issue: API calls fail (CORS error)
**Solution:**
- Check Facebook API CORS settings
- Use mock mode for testing
- Consider CORS proxy for development

### Issue: Service worker not updating
**Solution:**
- Hard refresh: Ctrl+Shift+R (Windows) or Cmd+Shift+R (Mac)
- Clear application cache in DevTools
- Unregister service worker and reload

### Issue: Icons not showing
**Solution:**
- Check icons exist in `build/web/icons/`
- Verify manifest.json paths are correct
- Hard refresh browser

---

## 📈 Next Steps

### After Deployment:
1. ✅ Test all features on deployed site
2. ✅ Share URL with team/testers
3. ✅ Monitor for issues
4. ✅ Gather feedback

### Consider Phase 8 If:
- ❌ Need 24/7 monitoring without browser
- ❌ Multiple users will use the app
- ❌ Want commercial/production deployment
- ❌ Need scalable architecture

---

## 🎉 Congratulations!

Your SociWave web app is now live! 🚀

**Share your deployed URL:**
- Netlify: `https://sociwave.netlify.app`
- Vercel: `https://sociwave.vercel.app`
- GitHub Pages: `https://hautracong.github.io/sociwave/`

---

*Deployment Guide*  
*Phase 7 Complete*  
*Generated: November 20, 2025*
