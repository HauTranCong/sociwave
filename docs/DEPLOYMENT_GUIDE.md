# SociWave - Deployment Instructions

**Date:** November 20, 2025  
**Build Status:** ✅ Complete  
**Build Size:** 31MB (2.7MB main app)

---

## 🎉 Build Complete!

Your SociWave web app is ready for deployment. The optimized build is in:
```
/home/worker/sociwave/webwebapp/build/web/
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
   - Wait for deployment (1-2 minutes)

3. **Get Your URL:**
   - Netlify provides: `https://random-name-12345.netlify.app`
   - You can customize: Site settings → Change site name

4. **Custom Domain (Optional):**
   - Site settings → Domain management
   - Add your own domain
   - Update DNS records

#### **Method B: Git Integration (Automatic Deploys)**

1. **Push to GitHub:**
   ```bash
   cd /home/worker/sociwave
   git add .
   git commit -m "Phase 7: Web deployment ready"
   git push origin main
   ```

2. **Connect Netlify:**
   - Netlify → "Add new site" → "Import an existing project"
   - Choose GitHub → Select `sociwave` repo
   - Configure:
     - Base directory: `app`
     - Build command: `flutter build web --release --tree-shake-icons`
     - Publish directory: `webapp/build/web`

3. **Deploy:**
   - Click "Deploy site"
   - Auto-deploys on every push to main!

**Netlify URL Format:**
```
https://sociwave.netlify.app
(or your custom domain)
```

---

### Option 2: Vercel (Great Performance) 🚀

**Why Vercel:**
- ✅ Free tier (100GB bandwidth/month)
- ✅ Excellent performance (CDN)
- ✅ Easy Git integration
- ✅ Preview deployments

#### **Deployment Steps:**

1. **Create Account:**
   - Visit: https://vercel.com
   - Sign up with GitHub

2. **Import Project:**
   - Dashboard → "Add New" → "Project"
   - Import `sociwave` repository from GitHub

3. **Configure:**
   - Framework Preset: **Other**
   - Root Directory: `app`
   - Build Command: `flutter build web --release --tree-shake-icons`
   - Output Directory: `webapp/build/web`

4. **Deploy:**
   - Click "Deploy"
   - Wait 2-3 minutes
   - Get URL: `https://sociwave.vercel.app`

5. **Auto-Deploy:**
   - Every push to main branch auto-deploys
   - Pull requests get preview URLs

**Vercel URL Format:**
```
https://sociwave.vercel.app
https://sociwave-git-main.vercel.app (main branch)
https://sociwave-pr-123.vercel.app (PR preview)
```

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
   cd /home/worker/sociwave/webapp
   flutter build web --release --base-href "/sociwave/"
   ```

2. **Create gh-pages Branch:**
   ```bash
   cd /home/worker/sociwave
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
cd /home/worker/sociwave/webwebapp/web
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
