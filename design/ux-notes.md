# UX Storyboard — Chota Crypto

## 1. Principles
- **Robinhood simplicity**: zero jargon, bold typography, bright CTA.
- **Mutual-fund familiarity**: emphasize packs, not individual tokens.
- **Frictions removed**: keyless login, gasless execution, no chain switching.

## 2. Key Screens
1. **Home Dashboard**
   - Hero card: "Invest ₹500 in AI Coins in 1 tap" with progress ring showing total invested.
   - Carousel of packs (AI, Bluechip, Solana Momentum, ETH L2) with 7-day change + risk badge.
   - CTA for "Setup Weekly SIP".
2. **Pack Detail**
   - Chart area with 30D performance, benchmark toggle.
   - Allocation chips (e.g., SOL 40%, JUP 20%).
   - Disclosure accordion (risk, strategy).
   - Amount input slider + quick buttons (₹500/₹1k/₹5k).
3. **Confirmation Sheet**
   - Shows INR total, estimated tokens, route summary ("Kana auto-route via Jupiter")
   - Single button `Invest Now`; secondary `Edit allocation`.
4. **Success State**
   - Animated confetti, message "Pack purchased. Next SIP in 7 days".
   - Share CTA + provide download receipt link.
5. **Portfolio**
   - Pack tiles with invested amount, current value, gain/loss.
   - Option to pause SIP, withdraw, or rebalance.

## 3. Interaction Flow
- Onboarding uses Mirai keyless login (phone/email OTP) → capture Aadhaar OTP → auto-provision smart wallet.
- UPI payment embedded via webview; return deep link to resume app.
- While swap executes (~seconds), show progress modal with 3 steps (Collect INR → Swap → Confirm) inspired by Kana widget.

## 4. Visual Direction
- Color palette: warm saffron gradient background (#F9B233 → #FF6F3C) with dark navy cards (#0A1A2F) for contrast.
- Typography: use "Space Grotesk" for numbers, "Public Sans" for body to avoid generic stacks.
- Micro-animations: pack cards slide in, confirmation modal scales with spring effect, success confetti fades within 1.5s.

## 5. Accessibility
- Minimum contrast 4.5:1 for text on gradients.
- Provide Hindi translations for key CTAs (e.g., "Invest Now" / "अब निवेश करें").
- Support VoiceOver/ TalkBack labels ("AI Coins Pack, 7-day change plus 5 percent").

## 6. Future Enhancements
- Add community sentiment badges ("Most bought this week").
- Integrate Kana Trade-style advanced view for power users with depth charts.
