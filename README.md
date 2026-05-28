# ShakeTimer

ShakeTimer is a tiny macOS menu-bar timer for people who miss normal notifications while deep in focus or agentic workflows.

The core idea is simple: when a timer or meeting reminder fires, the app gives a hard-to-miss visual cue on every display instead of relying on Notification Center. The default cue is a desktop-shake-style overlay, and the cue system is extensible so you can choose other screen effects.

![ShakeTimer menu showing the visual cue picker](docs/assets/shake-timer-menu.svg)

## What it does

- Runs as a native macOS menu-bar app.
- Starts quick timers or a custom timer from the menu.
- Shows dismiss/snooze hotkeys directly in the timer display.
- Provides selectable visual cues:
  - Desktop Shake
  - Edge Pulse
  - Screen Flash
  - Scan Sweep
- Includes a Google Calendar integration path for meeting reminders.
- Avoids standard notifications as the primary alarm channel.

## Why

This is built as a personal reliability hack: if normal notifications are disabled, ignored, or buried, ShakeTimer still creates a visible cue that interrupts the current visual field enough to bring attention back.

## Starting point

This project started from the following prompt to Factory.ai / factory-droid:

> I want to build an app for macOS that is a very simple timer but a smart timer where I can set a timer, for example, for whatever 15 minutes. After 15 minutes, I have options in terms of alarm, but the default mode is that it shakes the entire desktop for a few seconds until I snooze it. Obviously, if you shake the screen so fast and you don't give me the opportunity to pause it, it's going to be a problem. I want a visual cue, not a pop-up or anything, because I disabled those. We cannot rely on standard notification; this is the hack against all of that.
>
> The reason I want to do this is that I space out and go deep dive into agentic workflow, and I keep forgetting to show up to meetings and things like that. That's the main default; we can extend that later to sound and so on, but the main one is just to shake the desktop so I have a visual cue. The smart thing is that you can connect it to some data stream, for example Google Calendar, where it knows to shake my screen a little bit before joining meetings. That could be an example, or other data streams as well.

## Run locally

```bash
swift run ShakeTimer
```

## Validate

```bash
swift build --product ShakeTimer
swift run ShakeTimerCoreChecks
```
