/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

// Opz Browser branding prefs (based on browser/branding/unofficial).
// Feature/privacy prefs do NOT belong here; see prefs/ in the repo root.

// No "what's new" / welcome pages on first run or after updates.
pref("startup.homepage_override_url", "");
pref("startup.homepage_welcome_url", "");
pref("startup.homepage_welcome_url.additional", "");

// Opz has no update server yet; keep the unofficial defaults but point the
// manual/details links nowhere Mozilla-branded.
pref("app.update.interval", 86400); // 24 hours
pref("app.update.promptWaitTime", 86400);
pref("app.update.url.manual", "about:blank");
pref("app.update.url.details", "about:blank");
pref("app.update.checkInstallTime.days", 2);
pref("app.update.badgeWaitTime", 0);

// Number of usages of the web console.
// If this is less than 5, then pasting code into the web console is disabled
pref("devtools.selfxss.count", 5);
