# Privacy policy – Spojení CZ

*Česká verze níže.*

Last updated: 21 November 2026

Spojení CZ is a free, open-source Connect IQ app that finds public transport connections
and departures in the Czech Republic. It is developed by Radek Kůžel as a private,
non-commercial project. This policy describes the app published in the Garmin Connect IQ
Store and its server.

## What leaves the watch

Only what a search needs, and only when you start one:

| Data | When |
| --- | --- |
| Your position (latitude and longitude, rounded to about 100 m) | Only after you allowed it in the app, and only for a search from *My location*, *Nearby stops*, the nearest departure board, or to sort stops found by name |
| Stop names you type, chosen stop identifiers | Searching stops, connections and departures |
| Departure or arrival time, filters (transfers, vehicles) | Searching connections |

The app has no account, no advertising, no analytics and no tracking. It never sends
data in the background, except a search over Wi-Fi that you start yourself.

## Where it goes

1. **Garmin Connect on your phone** forwards the request from the watch to the internet
   (or the watch's own Wi-Fi does). Garmin's own privacy policy applies to this transport.
2. **The app's server** (a small proxy hosted on Vercel, region Frankfurt, EU) shortens
   the answer so that the watch can receive it. It stores nothing. Vercel keeps technical
   request logs for about one hour; they can contain the request, including the rounded
   position or the typed name.
3. **Transitous** (transitous.org), a free community routing service, computes the
   connections. It receives the position, stop identifiers and times from the server,
   not your IP address or anything that identifies you.

The developer runs the server but keeps no data: there is no database and no log of
its own. Data submitted through the app is submitted to the developer and the services
above, not to Garmin. Garmin has no responsibility or liability for this data.

## What stays on the watch

Recent stops, favourite trips, the last searches and the permission for your position
are stored on the watch only. You can delete them in the app (*Delete recent stops*,
*Delete searches*, *Remove a trip*) or by uninstalling the app.

## Your rights

Because nothing is stored on the server, there is nothing to look up, export or delete
there. For questions, contact the developer through
https://github.com/Radek2rady/journey-planner-garmin/issues.

## Changes

Changes to this policy are published at this address with a new date.

---

# Zásady ochrany soukromí – Spojení CZ

Poslední změna: 21. listopadu 2026

Spojení CZ je bezplatná aplikace s otevřeným zdrojovým kódem pro hodinky Garmin (Connect IQ),
která hledá spojení a odjezdy veřejné dopravy v Česku. Vyvíjí ji Radek Kůžel jako
soukromý, nekomerční projekt. Tyto zásady popisují aplikaci z obchodu Garmin Connect IQ
a její server.

## Co odchází z hodinek

Jen to, co hledání potřebuje, a jen když ho sami spustíte:

| Údaj | Kdy |
| --- | --- |
| Vaše poloha (zeměpisná šířka a délka, zaokrouhlená na přibližně 100 m) | Jen pokud jste ji v aplikaci povolili, a jen při hledání z *Moje poloha*, *Zastávky v okolí*, nejbližší tabule odjezdů, nebo pro seřazení zastávek nalezených podle názvu |
| Zadané názvy zastávek, vybrané zastávky | Hledání zastávek, spojení a odjezdů |
| Čas odjezdu nebo příjezdu, filtry (přestupy, dopravní prostředky) | Hledání spojení |

Aplikace nemá účet, reklamy, analytiku ani sledování. Na pozadí nic neposílá, kromě
hledání přes Wi-Fi, které sami spustíte.

## Kam data jdou

1. **Garmin Connect v telefonu** předá požadavek z hodinek do internetu (nebo Wi-Fi
   hodinek). Pro tento přenos platí zásady ochrany soukromí společnosti Garmin.
2. **Server aplikace** (malá proxy na Vercelu, oblast Frankfurt, EU) zkrátí odpověď, aby
   ji hodinky mohly přijmout. Nic neukládá. Vercel si vede technické záznamy požadavků
   přibližně jednu hodinu; mohou obsahovat požadavek včetně zaokrouhlené polohy nebo zadaného názvu.
3. **Transitous** (transitous.org), bezplatná komunitní služba pro vyhledávání spojení,
   spojení spočítá. Ze serveru dostane polohu, zastávky a časy, ne vaši IP adresu ani nic,
   co by vás identifikovalo.

Server provozuje vývojář, ale žádná data si nenechává: nemá databázi ani vlastní
záznamy. Údaje odeslané z aplikace se předávají vývojáři a výše uvedeným službám, ne
společnosti Garmin. Garmin za tyto údaje nenese žádnou odpovědnost.

## Co zůstává v hodinkách

Nedávné zastávky, oblíbené trasy, poslední hledání a povolení polohy jsou uložené jen
v hodinkách. Smažete je v aplikaci (*Smazat nedávné*, *Smazat hledání*, *Odebrat trasu*)
nebo odinstalováním aplikace.

## Vaše práva

Protože server nic neukládá, není tam co vyhledat, exportovat ani smazat. S dotazy se
obracejte na vývojáře přes https://github.com/Radek2rady/journey-planner-garmin/issues.

## Změny

Změny těchto zásad se zveřejní na této adrese s novým datem.
