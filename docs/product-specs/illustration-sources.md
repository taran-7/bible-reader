# Illustration search sources (6.17)

The starting list of domains for finding real illustration stories. Draft: each site's denomination and relevance are checked manually before release (the "Verified" column).

Rules (see [PRD 6.17](prd.md)):
- Search only within the allowlist; English-language Baptist or Protestant (evangelical) resources.
- A blocklist of Orthodox and Catholic domains as a fallback check in `BibleCore`.
- Live search on click (no index) goes only to allowlisted domains, the Wikipedia API and, with the user's key, Brave Search; `BibleCore` checks the blocklist.

## How we search (verified 2026-09-28)
- **WordPress REST, full text (first ≤ 1500 characters):** `christianitytoday.com` (`preachingtoday.com` redirects there), `imb.org`.
- **Behind a Cloudflare bot check** (`bible.org`, `desiringgod.org`, `founders.org`, `baptistpress.com`, `vom.org`, `thegospelcoalition.org`, `ligonier.org`) and without an open API (`sermonillustrations.com`, `sermoncentral.com`, `christianhistoryinstitute.org`, `spurgeon.org`, `wholesomewords.org`, `billygraham.org`, `moodybible.org`): only via Brave Search `site:` (title, snippet, link). We do not bypass the protection.
- **Wikipedia** (`en.wikipedia.org`, CC BY-SA): the article intro; biographies only (categories "… births/deaths"), excluding categories with the words catholic, orthodox, pope, saint, cardinal, monk, nun, monastery, patriarch, jesuit, franciscan, dominican, benedictine, beatified, canonized, venerated.

## Allowlist

| Domain | What is there | Tradition | Verified |
|---|---|---|---|
| `sermonillustrations.com` | a collection of sermon illustrations by topic | Protestant | no |
| `preachingtoday.com` | illustrations and sermons (Christianity Today) | evangelical | no |
| `sermoncentral.com` | illustrations, sermons | evangelical | no |
| `bible.org` | illustrations, articles (Dallas Theological Seminary) | evangelical | no |
| `christianitytoday.com` | articles, Christian History section | evangelical | no |
| `christianhistoryinstitute.org` | Christian History magazine, biographies | Protestant | no |
| `desiringgod.org` | biographies, articles (John Piper) | Reformed Baptist | no |
| `spurgeon.org` | Spurgeon Center, Midwestern Baptist Seminary | Baptist | no |
| `founders.org` | Baptist history, biographies | Reformed Baptist | no |
| `baptistpress.com` | news and testimonies (Southern Baptist Convention) | Baptist | no |
| `imb.org` | missionary stories (International Mission Board, SBC) | Baptist | no |
| `wholesomewords.org` | biographies of missionaries and preachers | evangelical | no |
| `vom.org` | testimonies of persecuted Christians (Voice of the Martyrs) | Protestant | no |
| `billygraham.org` | testimonies, conversion stories | evangelical | no |
| `thegospelcoalition.org` | articles, biographies | Reformed evangelical | no |
| `ligonier.org` | church history, biographies | Reformed | no |
| `moodybible.org` | articles, history (Moody Bible Institute) | evangelical | no |
| `en.wikipedia.org` | biographies (category filter) | neutral | yes (owner decision 2026-09-28) |

Risk: even Protestant sites (especially `christianitytoday.com`, `christianhistoryinstitute.org`) sometimes write about Catholic or Orthodox figures. The allowlist guarantees the source, not the topic; the prompt additionally asks for stories about Protestant heroes of faith or neutral historical events.

## Blocklist (fallback check)

`vatican.va`, `catholic.com`, `catholicculture.org`, `catholicnewsagency.com`, `ewtn.com`, `newadvent.org`, `franciscanmedia.org`, `aleteia.org`, `oca.org`, `goarch.org`, `orthodoxwiki.org`, `orthochristian.com`, `antiochian.org`, `pravoslavie.ru`, `azbyka.ru`.

## How to update
The list lives in the app configuration (one file, no code changes). A new domain is added marked "Verified: no"; after a manual check (the site's "About/Beliefs" page) it is set to "yes".
