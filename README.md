<img width="1248" height="988" alt="Gemini_Generated_Image_b05lfxb05lfxb05l" src="https://github.com/user-attachments/assets/4b273aff-55dc-48bb-b9d6-1c1482222f82" />

# AntiDarkSword ⚔️ (TrollStore Edition)

AntiDarkSword is an advanced iOS security framework designed to mitigate zero-click payloads and browser RCEs through granular WebKit isolation. 

This specific build has been completely re-architected as a standalone dynamic library (`.dylib`). It is designed for non-jailbroken users running **TrollStore**, providing advanced JIT, JavaScript, and User-Agent mitigations directly to individual 3rd-party applications.

-----

## ✨ Features

* **In-App Management:** Configuration is handled entirely within the target app via a hidden, native iOS overlay menu.
* **Granular WebKit Control:** Individually disable the JIT compiler (iOS 15 & 16+), JavaScript, WebRTC (peer connections), Media Auto-Play, and Local File Access per app.
* **Anti-Fingerprinting:** Spoof your `WKWebView` User-Agent to bypass targeted payload delivery systems.
* **Zero-Crash Architecture:** By disabling the highly-targeted JIT compiler while allowing baseline interpreted JavaScript, your injected apps retain their UI functionality while neutralizing memory-corruption zero-days.
* **Per-App Sandboxing:** Preferences are securely saved directly to the injected app's local storage.

## 🚀 How to Install & Use (TrollFools Method)

Because this version operates without a jailbreak, it relies on static injection. You will need to use a tool like [TrollFools](https://github.com/Lessica/TrollFools/releases/download/v4.2-227/TrollFools_4.2-227.tipa) to physically inject the security framework into your desired apps.

1. **Download AntiDarkSword:** Grab the latest `AntiDarkSwordUI.dylib` from the [**Releases**](https://github.com/EolnMsuk/AntiDarkSword-TrollStore/releases) tab of this repository.
2. **Inject:** Open TrollFools on your device, select your target app, and inject the `AntiDarkSwordUI.dylib` file.
3. **Configure:** Open your newly protected app. Perform a **3-finger double-tap** anywhere on the screen. The AntiDarkSword configuration menu will appear.
4. **Apply:** Toggle your desired security mitigations. Close the menu and completely restart the app for the changes to fully apply to the WebKit engine.

-----

## 🛑 Mitigated Exploits

By disabling WebKit JIT and JavaScriptCore attack vectors inside your injected apps, this tweak prevents several known exploit chains:

* **DarkSword:** Full-chain, JavaScript-based exploit kit.
* **Coruna:** JavaScript-reliant iOS exploit kit.
* **Chaos:** Safari/WebKit DOM vulnerability exploit.
* **CVE-2025-43529 / CVE-2024-44308:** WebKit remote code executions via web content.
* **CVE-2022-42856:** JavaScriptCore type confusion in the JIT compiler.
* **Hermit:** JavaScriptCore type-confusion spyware chain.

-----

## ⚠️ Limitations & The Jailbreak Advantage

**If your device is capable of running a full jailbreak, you should absolutely use the standard versions of AntiDarkSword instead of this TrollStore edition.** Due to the strict nature of the iOS Sandbox and the lack of a system-wide hooking engine (like ElleKit or Substrate), this TrollStore version has several critical limitations:

1. **No System Daemon Protection (Level 3):** This version *cannot* protect background system daemons like `imagent`, `mediaserverd`, or `apsd`. It cannot protect against native iMessage zero-clicks (like BLASTPASS or FORCEDENTRY).
2. **No Native Apple App Protection (Level 1):** You cannot inject this `.dylib` into pre-installed iOS apps. Native Safari, Apple Mail, and Apple Messages remain unprotected.
3. **No Global Umbrella:** Protection is strictly localized. The framework only exists inside the specific 3rd-party apps you manually inject it into. There is no master switch to protect your entire device at once.

**In short:** The TrollStore edition acts as a localized shield for specific 3rd-party browsers and messengers. The Jailbreak edition acts as an umbrella over your entire operating system.

### 🔗 Official Jailbreak Releases
For maximum device security, please use the standard tweaks if you are jailbroken:
* **[AntiDarkSword (Rootless)](https://github.com/EolnMsuk/AntiDarkSword)** - For iOS 15.0 – 17.0 modern jailbreaks (Dopamine, Palera1n rootless).
* **[AntiDarkSword (Rootful)](https://github.com/EolnMsuk/AntiDarkSword-rootful)** - For older/legacy jailbreaks (Checkm8, Palera1n rootful).

-----

## 👨‍💻 Developer

Created by: [EolnMsuk](https://github.com/EolnMsuk)

Donate 🤗: [Venmo](https://venmo.com/user/eolnmsuk)
