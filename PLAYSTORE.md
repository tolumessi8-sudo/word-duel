# Publishing Word Duel on Google Play

1. **Play Console**: pay the one-time $25 developer fee at play.google.com/console, create app "Word Duel" (Game, Free).
2. **Upload key** (one time): in the repo, Settings > Secrets and variables > Actions > *Secrets*, add
   `ANDROID_KEYSTORE_BASE64` (contents of keystore.b64.txt), `ANDROID_KEY_ALIAS` (`wordduel`), `ANDROID_KEYSTORE_PASSWORD`.
   Keep `word-duel-upload.keystore` backed up safely.
3. **AdMob** (when ready): add *Variables* `ADMOB_APP_ID`, `ADMOB_BANNER`, `ADMOB_INTERSTITIAL`, `ADMOB_REWARDED`. Without them Google test ads are used (never ship test ads).
4. **Build**: Actions > "Build Android AAB (Play Store release)" > Run workflow. Download `word-duel.aab` from the `play-release` release.
5. **Privacy policy**: Settings > Pages > Source: branch `main`, folder `/docs`. URL: https://tolumessi8-sudo.github.io/word-duel/
6. **Listing**: use `store/listing.md`, `store/icon-512.png`, `store/feature-graphic-1024x500.png`, `store/screenshots/`.
7. Complete the Play Console forms (content rating, ads = yes, data safety, target audience 13+), then upload the AAB to an Internal/Closed test first. New personal accounts need a closed test with 12+ testers for 14 days before Production.
