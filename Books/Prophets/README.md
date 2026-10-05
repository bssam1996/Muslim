# Prophet reading PDFs

Use one stable path for each prophet, language and audience:

```text
<Prophet>/ar/kids.pdf
<Prophet>/en/kids.pdf
<Prophet>/ar/full.pdf
<Prophet>/en/full.pdf
```

Folder names and letter case are significant. Replace an edition at its existing path and update its entry in `sources.json` when a better edition becomes available.

This folder contains 92 reading PDFs: 25 Arabic kids editions, 17 English kids editions and 50 adult editions. `sources.json` records each PDF's source, page count, size and SHA-256 hash. It also preserves available author credits, download URLs, reuse notices and source-page mappings.

Preparation scripts, previews, rejected downloads, unused source copies and duplicate inventories are excluded from this repository.

| Prophet folder | Arabic kids | English kids | Arabic adults | English adults |
| --- | --- | --- | --- | --- |
| Adam | [PDF](Adam/ar/kids.pdf) | [PDF](Adam/en/kids.pdf) | [PDF](Adam/ar/full.pdf) | [PDF](Adam/en/full.pdf) |
| Al-Yasa | [PDF](Al-Yasa/ar/kids.pdf) | [PDF](Al-Yasa/en/kids.pdf) | [PDF](Al-Yasa/ar/full.pdf) | [PDF](Al-Yasa/en/full.pdf) |
| Ayyub | [PDF](Ayyub/ar/kids.pdf) | Not supplied | [PDF](Ayyub/ar/full.pdf) | [PDF](Ayyub/en/full.pdf) |
| Dawud | [PDF](Dawud/ar/kids.pdf) | Not supplied | [PDF](Dawud/ar/full.pdf) | [PDF](Dawud/en/full.pdf) |
| Dhul-Kifl | [PDF](Dhul-Kifl/ar/kids.pdf) | [PDF](Dhul-Kifl/en/kids.pdf) | [PDF](Dhul-Kifl/ar/full.pdf) | [PDF](Dhul-Kifl/en/full.pdf) |
| Harun | [PDF](Harun/ar/kids.pdf) | Not supplied | [PDF](Harun/ar/full.pdf) | [PDF](Harun/en/full.pdf) |
| Hud | [PDF](Hud/ar/kids.pdf) | [PDF](Hud/en/kids.pdf) | [PDF](Hud/ar/full.pdf) | [PDF](Hud/en/full.pdf) |
| Ibrahim | [PDF](Ibrahim/ar/kids.pdf) | [PDF](Ibrahim/en/kids.pdf) | [PDF](Ibrahim/ar/full.pdf) | [PDF](Ibrahim/en/full.pdf) |
| Idris | [PDF](Idris/ar/kids.pdf) | [PDF](Idris/en/kids.pdf) | [PDF](Idris/ar/full.pdf) | [PDF](Idris/en/full.pdf) |
| Ilyas | [PDF](Ilyas/ar/kids.pdf) | [PDF](Ilyas/en/kids.pdf) | [PDF](Ilyas/ar/full.pdf) | [PDF](Ilyas/en/full.pdf) |
| Isa | [PDF](Isa/ar/kids.pdf) | [PDF](Isa/en/kids.pdf) | [PDF](Isa/ar/full.pdf) | [PDF](Isa/en/full.pdf) |
| Ishaq | [PDF](Ishaq/ar/kids.pdf) | [PDF](Ishaq/en/kids.pdf) | [PDF](Ishaq/ar/full.pdf) | [PDF](Ishaq/en/full.pdf) |
| Ismail | [PDF](Ismail/ar/kids.pdf) | [PDF](Ismail/en/kids.pdf) | [PDF](Ismail/ar/full.pdf) | [PDF](Ismail/en/full.pdf) |
| Lut | [PDF](Lut/ar/kids.pdf) | [PDF](Lut/en/kids.pdf) | [PDF](Lut/ar/full.pdf) | [PDF](Lut/en/full.pdf) |
| Muhammad | [PDF](Muhammad/ar/kids.pdf) | [PDF](Muhammad/en/kids.pdf) | [PDF](Muhammad/ar/full.pdf) | [PDF](Muhammad/en/full.pdf) |
| Musa | [PDF](Musa/ar/kids.pdf) | [PDF](Musa/en/kids.pdf) | [PDF](Musa/ar/full.pdf) | [PDF](Musa/en/full.pdf) |
| Nuh | [PDF](Nuh/ar/kids.pdf) | [PDF](Nuh/en/kids.pdf) | [PDF](Nuh/ar/full.pdf) | [PDF](Nuh/en/full.pdf) |
| Saleh | [PDF](Saleh/ar/kids.pdf) | [PDF](Saleh/en/kids.pdf) | [PDF](Saleh/ar/full.pdf) | [PDF](Saleh/en/full.pdf) |
| Shuayyb | [PDF](Shuayyb/ar/kids.pdf) | Not supplied | [PDF](Shuayyb/ar/full.pdf) | [PDF](Shuayyb/en/full.pdf) |
| Sulaiman | [PDF](Sulaiman/ar/kids.pdf) | Not supplied | [PDF](Sulaiman/ar/full.pdf) | [PDF](Sulaiman/en/full.pdf) |
| Yahya | [PDF](Yahya/ar/kids.pdf) | Not supplied | [PDF](Yahya/ar/full.pdf) | [PDF](Yahya/en/full.pdf) |
| Yaqub | [PDF](Yaqub/ar/kids.pdf) | Not supplied | [PDF](Yaqub/ar/full.pdf) | [PDF](Yaqub/en/full.pdf) |
| Yunus | [PDF](Yunus/ar/kids.pdf) | [PDF](Yunus/en/kids.pdf) | [PDF](Yunus/ar/full.pdf) | [PDF](Yunus/en/full.pdf) |
| Yusuf | [PDF](Yusuf/ar/kids.pdf) | Not supplied | [PDF](Yusuf/ar/full.pdf) | [PDF](Yusuf/en/full.pdf) |
| Zakariyya | [PDF](Zakariyya/ar/kids.pdf) | [PDF](Zakariyya/en/kids.pdf) | [PDF](Zakariyya/ar/full.pdf) | [PDF](Zakariyya/en/full.pdf) |

English kids PDFs are missing for: Ayyub, Dawud, Harun, Shuayyb, Sulaiman, Yahya, Yaqub, Yusuf.

The adult files contain unchanged published source pages, with original source credits retained. Arabic and English editions use different published sources; the English Seoharwi edition is a published abridgment. Shared chapters and short source accounts remain as published. Check the source and edition notes in `sources.json` for each prophet.

English kids editions for Hud, Saleh, Lut, Dhul-Kifl, Ilyas and Al-Yasa are unofficial translations of the supplied Arabic stories. Their original illustrations and credits are retained; translation and content-review details remain in `sources.json`.

Ismail's English kids PDF combines both original illustrated lessons: Obey Allah on pages 1-4 and Build the Kabah on pages 5-8. Ishaq and Zakariyya use the original available lesson PDFs under the stable `kids.pdf` filename. Some kids editions are lessons or activity books rather than complete biographies.

The two existing Muhammad biography PDFs remain in `../Prophet Muhammed Biography/Ibn Kathir/` because the app's biography catalogue references their existing filenames.
