# Джерела для пошуку ілюстрацій (6.17)

Стартовий список доменів для пошуку реальних історій-ілюстрацій. Чернетка: конфесійну належність і актуальність кожного сайту перевіряємо вручну перед релізом (колонка «Перевірено»).

Правила (див. [PRD 6.17](prd.md)):
- Пошук лише в allowlist; англомовні баптистські або протестантські (євангельські) ресурси.
- Blocklist православних і католицьких доменів як запасна перевірка в `BibleCore`.
- Локальний індекс (sitemap/RSS) і живий пошук ходять лише на домени з allowlist; blocklist перевіряє `BibleCore`.

## Allowlist

| Домен | Що там | Напрям | Перевірено |
|---|---|---|---|
| `sermonillustrations.com` | збірка проповідницьких ілюстрацій за темами | протестантський | ні |
| `preachingtoday.com` | ілюстрації й проповіді (Christianity Today) | євангельський | ні |
| `sermoncentral.com` | ілюстрації, проповіді | євангельський | ні |
| `bible.org` | ілюстрації, статті (Dallas Theological Seminary) | євангельський | ні |
| `christianitytoday.com` | статті, розділ Christian History | євангельський | ні |
| `christianhistoryinstitute.org` | журнал Christian History, біографії | протестантський | ні |
| `desiringgod.org` | біографії, статті (John Piper) | реформатський баптистський | ні |
| `spurgeon.org` | Spurgeon Center, Midwestern Baptist Seminary | баптистський | ні |
| `founders.org` | історія баптистів, біографії | реформатський баптистський | ні |
| `baptistpress.com` | новини й свідчення (Southern Baptist Convention) | баптистський | ні |
| `imb.org` | історії місіонерів (International Mission Board, SBC) | баптистський | ні |
| `wholesomewords.org` | біографії місіонерів і проповідників | євангельський | ні |
| `vom.org` | свідчення переслідуваних християн (Voice of the Martyrs) | протестантський | ні |
| `billygraham.org` | свідчення, історії навернення | євангельський | ні |
| `thegospelcoalition.org` | статті, біографії | реформатський євангельський | ні |
| `ligonier.org` | церковна історія, біографії | реформатський | ні |
| `moodybible.org` | статті, історія (Moody Bible Institute) | євангельський | ні |

Ризик: навіть протестантські сайти (особливо `christianitytoday.com`, `christianhistoryinstitute.org`) іноді пишуть про католицьких чи православних персоналій. Allowlist гарантує джерело, а не тему; промпт додатково просить історії про протестантських героїв віри або нейтральні історичні події.

## Blocklist (запасна перевірка)

`vatican.va`, `catholic.com`, `catholicculture.org`, `catholicnewsagency.com`, `ewtn.com`, `newadvent.org`, `franciscanmedia.org`, `aleteia.org`, `oca.org`, `goarch.org`, `orthodoxwiki.org`, `orthochristian.com`, `antiochian.org`, `pravoslavie.ru`, `azbyka.ru`.

## Як оновлювати
Список живе в конфігурації додатка (один файл, без змін коду). Новий домен додаємо з позначкою «Перевірено: ні», після ручної перевірки (сторінка «About/Beliefs» сайту) ставимо «так».
