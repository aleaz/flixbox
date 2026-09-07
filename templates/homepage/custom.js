/* Flixbox Homepage polish — runs after auth; keep free of secrets.
 * 1) Move #revalidate beside the clock (header telemetry cluster).
 * 2) Tag network-mode + LAN-profile chips (separate greetings).
 */
(function () {
  "use strict";

  var CHIP_SEL =
    ".information-widget-greeting span.text-sm, [class*=Greeting_greeting] span.text-sm, [class*=greeting] .text-sm";

  function placeRefresh() {
    var btn = document.getElementById("revalidate");
    if (!btn) return false;

    var right =
      document.getElementById("information-widgets-right") ||
      document.querySelector(".information-widget-datetime")?.closest("[id], .widget-container, div");

    if (!right) return false;
    if (btn.parentElement === right && btn.dataset.flixboxPlaced === "1") return true;

    btn.dataset.flixboxPlaced = "1";
    btn.classList.add("flixbox-header-refresh");
    btn.setAttribute("title", "Refresh");
    btn.setAttribute("aria-label", "Refresh dashboard");
    right.appendChild(btn);
    return true;
  }

  function styleChips() {
    document.querySelectorAll(CHIP_SEL).forEach(function (el) {
      var t = (el.textContent || "").trim().toLowerCase();
      el.classList.remove(
        "flixbox-chip--vpn",
        "flixbox-chip--direct",
        "flixbox-chip--mode",
        "flixbox-chip--profile"
      );
      // Network mode (VPN tunnel vs Direct host IP)
      if (t === "vpn") {
        el.classList.add("flixbox-chip--mode", "flixbox-chip--vpn");
        el.setAttribute("title", "Network mode: VPN");
      } else if (t === "direct") {
        el.classList.add("flixbox-chip--mode", "flixbox-chip--direct");
        el.setAttribute("title", "Network mode: Direct (no VPN)");
      } else if (t === "trusted" || t === "shared") {
        // LAN access profile (ADR 0015)
        el.classList.add("flixbox-chip--profile");
        el.setAttribute("title", "Access profile: " + t);
      }
    });
  }

  function run() {
    placeRefresh();
    styleChips();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", run);
  } else {
    run();
  }

  var scheduled = false;
  function schedule() {
    if (scheduled) return;
    scheduled = true;
    requestAnimationFrame(function () {
      scheduled = false;
      run();
    });
  }

  if (typeof MutationObserver !== "undefined") {
    var obs = new MutationObserver(schedule);
    obs.observe(document.documentElement, {
      childList: true,
      subtree: true,
      characterData: true,
    });
  }
})();
