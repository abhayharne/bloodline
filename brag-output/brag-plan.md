# Brag Plan: BloodLine

## Planning rubric
1. App: emergency blood-request coordination; each request creates one live chat room for its requester, banks and matched donors.
2. Strongest claim: one request = one live room; the room closes when fulfilled (README and PITCH).
3. Visual hook: a giant O− request badge transforms into a bright red, shared room.
4. Actual UI: recreate New Blood Request and the request-summary/chat interface from Flutter source, retaining real labels and structure.
5. Shortest satisfying film: 22 seconds, 1920×1080, 30fps.
6. Tone: cinematic, with a clear and humane product demo; confident motion without fear or guilt.
7. Audio: optimistic rhythmic instrumental and sparse soft UI accents, no narration.
8. Caption: BloodLine turns emergency blood requests into live chat rooms. Requesters, blood banks and nearby donors coordinate in one place—then close the room when the request is fulfilled. Built with Flutter, Go and Nexconn.
9. Flow: choose group, units and hospital → broadcast and match → coordinate in chat → fulfill and close.

## Angle and hook
Urgent blood. One live room. Show coordination becoming concrete, not ungrounded impact statistics.

## Visual identity
Source: app/lib/main.dart Material 3 red/light theme; phone screenshots inspected for layout only, never copied into public output.
App red #F44336, critical red #D32F2F, white #FFFFFF, pale app surface #FFF8F7, ink #231918. Film framing uses deep burgundy #160B0D and brighter readable red #FF645B.
Film display: Archivo Black, 900-equivalent native bold; data: IBM Plex Mono 400/500. Product interface uses the bundled neutral sans as a video adaptation of Flutter Material.

## Storyboard (22 seconds total)
### 1 — Need → connection — 0–3s
Giant O− blood group with the headline “Urgent blood. One live room.” A short red connection line grows toward the wordmark. Hook holds fully readable from 0.6s.
Sequential: headline, badge, line. Sound: soft major reveal hit. Transition: red badge/colour wipe into app scene.
### 2 — Broadcast — 3–8.74s
Left: “Make the need clear.” Right: New Blood Request, Blood Group O−, Units 2 units, Whole blood, Demo City Hospital, Critical, Broadcast Request. A simulated button press at 6s; result reveals “Emergency Request Broadcasted!” and demo matching counts of one bank and four donors. All example records are explicitly labeled DEMO DATA.
Sequential: form then button action then result. Sound: quiet tap and confirmation; natural timing for readable labels rather than snapping all text to each beat.
### 3 — Coordinate — 8.74–17.47s
“One request. One live room.” Recreated chat header carries group, units, hospital and urgency; requester, bank and donor participants appear. Fictional sample messages: “2 units available.” / “I can help.” / hospital location pin. A final “Mark fulfilled” action turns status into Fulfilled and closes room read-only.
Sequential: three messages with at least 1.2s between reads. Sound: warm short messages, fulfillment cue. Entry beat-locked at 8.74s.
### 4 — Resolution — 17.47–22s
BloodLine wordmark, “One request. One room.”, “Requesters · Blood banks · Donors”, “Built with Nexconn”. Fulfilled badge ties outcome to flow. Hold final copy over 3 seconds. Music fades for final 1.2s. Logo reveal beat-locked at 17.47s.

## Audio direction and Music cue guidance
Bundled happy-beats-business-moves-vol-12-by-ende-dot-app.mp3, Sascha Ende, CC BY 4.0. Read cue preset; estimated 109.96 BPM. Strong anchors 8.74 and 17.47s. Sparse SFX from bundled Kenney CC0 library: click_003, bong_001, impactSoft_medium_001. Music gain .32 with .3s fade-in and 1.2s fade-out. Audio analysis will drive restrained depth/glow of the request object, never readable type. Narration disabled.

## Grounding and privacy
All on-screen features are grounded in README, docs/API.md, Flutter RequesterScreen and RequestSummaryHeader. Demo counts, hospital and messages are fictional illustrations, visibly labeled. No production database or phone screenshots are included. No promised medical outcome or speed metric.
