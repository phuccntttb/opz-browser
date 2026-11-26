// Opz Browser default prefs (not locked; users can change them in about:config).
// Installed as browser/defaults/preferences/opz.js. Things that must be locked
// live in prefs/policies.json instead. Every name here was checked against the
// Firefox 159 source (browser/app/profile/firefox.js, modules/libpref/init/all.js,
// browser/extensions/newtab/lib/ActivityStream.sys.mjs).

// --- Telemetry (DisableTelemetry policy locks the main upload switches) -------
pref("toolkit.telemetry.unified", false);
pref("toolkit.telemetry.server", "");
pref("browser.newtabpage.activity-stream.telemetry", false);
pref("browser.search.serpEventTelemetryCategorization.enabled", false);

// --- Studies (DisableFirefoxStudies policy disables Normandy/Shield) ----------
pref("app.normandy.enabled", false);
pref("app.shield.optoutstudies.enabled", false);

// --- Sponsored / promoted content in the URL bar -----------------------------
pref("browser.urlbar.sponsoredTopSites", false);
pref("browser.urlbar.trending.featureGate", false);

// --- VPN and Mozilla service promos -------------------------------------------
pref("browser.vpn_promo.enabled", false);
pref("browser.promo.pin.enabled", false);
pref("browser.contentblocking.report.monitor.enabled", false);
pref("browser.contentblocking.report.lockwise.enabled", false);

// --- Recommendations and tours ------------------------------------------------
pref("extensions.htmlaboutaddons.recommendations.enabled", false);
pref("browser.discovery.enabled", false);
pref("browser.uitour.enabled", false);
pref("messaging-system.askForFeedback", false);

// --- Telemetry leftovers ------------------------------------------------------
pref("datareporting.usage.uploadEnabled", false);

// --- Sponsored tiles fetch (FirefoxHome hides them; this stops the request) ---
pref("browser.topsites.contile.enabled", false);

// --- Firefox Relay (off; Sync is on but Relay is not wanted) -----------------
pref("signon.firefoxRelay.feature", "disabled");
pref("browser.promo.relay.enabled", false);

// --- Google Lens "visual search" in the image context menu --------------------
pref("browser.search.visualSearch.featureGate", false);

// --- Leftover AI bits (AIControls blocks the user-facing switches) ------------
pref("browser.tabs.groups.smart.enabled", false);
pref("places.semanticHistory.featureGate", false);

// --- No "make Opz your default browser" prompt at startup --------------------
// (Settings > General still offers it.)
pref("browser.shell.checkDefaultBrowser", false);

// --- Vertical tabs ------------------------------------------------------------
// Patch 0006 turns them on once per profile after startup (a default of true
// here would build a broken nav-bar on new profiles) and hides the launcher's
// tool icons while tabs are vertical. They need the new sidebar
// (sidebar.revamp, already true in firefox.js). Users can go back to
// horizontal tabs in Settings > Tabs and browsing or the tab strip's menu.
//
// The tab column stays collapsed to icons and expands on hover. This has to be
// the default value too, not only a one-time setting (patch 0010): Firefox's
// default is "always-show", and a pref set to its default is not kept as a
// user value, so a profile without one would never expand on hover. The pin
// button (patch 0021) stores "always-show" as a user value.
pref("sidebar.visibility", "expand-on-hover");

// Whether hovering the collapsed tab column expands it. Turned off from the
// tab context menu's "Expand sidebar on hover" (patch 0042); the column then
// stays collapsed to icons until this is turned back on.
pref("opz.sidebar.expandOnHover", true);

// --- URL bar: no search-engine switcher button (classic URL bar) -------------
// The engine icons come back as one-off buttons at the bottom of the dropdown.
pref("browser.urlbar.scotchBonnet.enableOverride", false);

// --- Bookmarks toolbar hidden, and no "Import bookmarks..." button on it -----
// Ctrl+Shift+B (Cmd+Shift+B on macOS) still shows the toolbar.
pref("browser.toolbars.bookmarks.visibility", "never");
pref("browser.bookmarks.addedImportButton", true);

// --- New Tab: a truly blank page ----------------------------------------------
// With this off, about:newtab is browser/content/blanktab.html instead of the
// Activity Stream page, so there is no Customize (pencil) button and none of
// what it opens: panel, wallpapers, widgets, sections, sponsored content.
pref("browser.newtabpage.enabled", false);

// --- If the Activity Stream page is turned back on: no widgets (clock, lists, timer, crossword...) or wallpapers ----
// ActivityStream keeps default-branch values that are already set, so these win.
pref("browser.newtabpage.activity-stream.widgets.system.enabled", false);
pref("browser.newtabpage.activity-stream.widgets.enabled", false);
pref("browser.newtabpage.activity-stream.newtabWallpapers.enabled", false);

// --- Profiles (new multi-profile manager) and Backup -------------------------
// Profiles stays on if the user already created profiles with it.
pref("browser.profiles.enabled", false);
pref("browser.backup.enabled", false);
pref("browser.backup.archive.enabled", false);
pref("browser.backup.restore.enabled", false);

// --- Translations: no "Translate this page?" popup on foreign-language pages -
// The translate button still appears in the URL bar on those pages and opens
// the same panel when clicked.
pref("browser.translations.automaticallyPopup", false);

// --- Toolbar: no Extensions (puzzle) button ---------------------------------
// It still shows up when an extension needs attention. Extensions are managed
// from the app menu (Add-ons and themes); extensions pinned to the toolbar keep
// their own buttons.
pref("extensions.unifiedExtensions.button.always_visible", false);

// --- Theme: plain gray "Opz" theme (browser/themes/addons/opz, patch 0007) ----
// Patch 0007 switches every profile, new or old, to it once at startup
// (marked by opz.defaultThemeApplied); after that the user's choice is kept.
// Light or dark follows the system.

// --- Tracking protection --------------------------------------------------------
// Enhanced Tracking Protection stays on Firefox's "Standard" level (trackers,
// cross-site cookies, cryptominers and known fingerprinters blocked; Total
// Cookie Protection on). "Strict" breaks too many logins and embeds to be a
// default; users can pick it in Settings > Privacy & Security.
// Global Privacy Control tells sites not to sell or share the user's data.
pref("privacy.globalprivacycontrol.enabled", true);

// --- Telemetry pings and crash reports (on top of DisableTelemetry) ----------
pref("toolkit.telemetry.archive.enabled", false);
pref("toolkit.telemetry.newProfilePing.enabled", false);
pref("toolkit.telemetry.shutdownPingSender.enabled", false);
pref("toolkit.telemetry.firstShutdownPing.enabled", false);
pref("toolkit.telemetry.bhrPing.enabled", false);
pref("toolkit.telemetry.updatePing.enabled", false);
pref("browser.tabs.crashReporting.sendReport", false);
pref("browser.crashReports.unsubmittedCheck.autoSubmit2", false);

// --- More sponsored content and Mozilla promos -------------------------------
pref("browser.urlbar.quicksuggest.enabled", false);
pref("browser.urlbar.suggest.quicksuggest.sponsored", false);
pref("browser.newtabpage.activity-stream.showSponsoredCheckboxes", false);
pref("browser.contentblocking.report.show_mobile_app", false);
pref("browser.contentblocking.report.hide_vpn_banner", true);

// --- Welcome screen (patch 0013) ----------------------------------------------
// Full-window welcome shown once per profile at startup (import, search engine,
// uBlock Origin from AMO, default browser).
// Set to false to see it again on the next start.
pref("opz.welcome.shown", false);

// --- Always restore the previous session -------------------------------------
// Reopen the last session's windows and tabs on every start, and after a crash
// (or the browser being killed) restore it straight away instead of showing
// the "Sorry. We're having trouble getting your pages back" page.
pref("browser.startup.page", 3);
pref("browser.sessionstore.max_resumed_crashes", -1);

// --- Smooth scrolling -----------------------------------------------------
// Momentum-style wheel scrolling (spring physics, as in Smoothfox's "natural
// smooth scrolling V3"): each notch glides and keeps the speed of a fast spin.
// Float prefs take string values. A touchpad that now scrolls too fast:
// lower mousewheel.default.delta_multiplier_y in about:config.
pref("general.smoothScroll", true);
pref("general.smoothScroll.msdPhysics.enabled", true);
pref("general.smoothScroll.msdPhysics.continuousMotionMaxDeltaMS", 12);
pref("general.smoothScroll.msdPhysics.motionBeginSpringConstant", 600);
pref("general.smoothScroll.msdPhysics.regularSpringConstant", 650);
pref("general.smoothScroll.msdPhysics.slowdownMinDeltaMS", 25);
pref("general.smoothScroll.msdPhysics.slowdownMinDeltaRatio", "2.0");
pref("general.smoothScroll.msdPhysics.slowdownSpringConstant", 250);
pref("general.smoothScroll.currentVelocityWeighting", "1.0");
pref("general.smoothScroll.stopDecelerationWeighting", "1.0");
pref("mousewheel.default.delta_multiplier_y", 300);
pref("apz.overscroll.enabled", true);

// --- Lower memory use ---------------------------------------------------------
// Unload background tabs when the system runs low on memory. Firefox only turns
// this on for macOS and Windows; Linux has the same memory watcher
// (xpcom/base/AvailableMemoryWatcherLinux.cpp, fires below 5% free memory).
// Unloaded tabs stay in the tab strip and reload when selected. Tabs used in
// the last 10 minutes, playing sound, in Picture-in-Picture, in a call (WebRTC)
// or private are never unloaded; pinned tabs go after the others
// (browser/components/tabbrowser/TabUnloader.sys.mjs).
pref("browser.tabs.unloadOnLowMemory", true);
// No hidden, preloaded about:newtab page. The Opz New Tab page is blank, so
// keeping one loaded in the background only costs memory.
pref("browser.newtab.preload", false);
// No spare web content process kept ready for the next site (about 30-60 MB).
// A new site waits a moment for its process to start.
pref("dom.ipc.processPrelaunch.enabled", false);
// Keep at most 2 previous pages in the back/forward cache, across all tabs
// (-1 picks up to 8 by installed memory). With Fission each cached page can
// keep a whole content process alive. Going further back reloads the page.
pref("browser.sessionhistory.max_total_viewers", 2);
// Tab hover cards show the title and address but no screenshot. The vertical
// tab strip expands on hover (patch 0010), so the mouse crosses tabs often and
// each crossing would capture a tab image.
pref("browser.tabs.hoverPreview.showThumbnails", false);
// Do not record page interactions (view time, scrolling, typing) in
// places.sqlite for every page; Opz has no feature that reads them.
pref("browser.places.interactions.enabled", false);

// --- Containers travel with Sync (Settings) through this pref ---------------
// OpzContainerSync writes the containers and site choices into
// opz.containers.sync; the control pref makes the Sync prefs engine carry it.
pref("opz.containers.sync", "");
pref("services.sync.prefs.sync.opz.containers.sync", true);
