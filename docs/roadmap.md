# Chota Crypto — Execution Roadmap

This roadmap turns the architecture and specs into an execution plan.

## 0. Foundations (Week 0–1)
- Confirm MVP scope: packs (AI, Bluechip, Solana Momentum, ETH L2), SIP + lump sum, supported chains.
- **Primary client for V1: React Native mobile application (Android + iOS)** for maximum reach in India.
- Lock regulatory posture with counsel and confirm partner requirements (on-ramp, KYC, custody stance).
- Choose core tech stack:
  - Backend: Node.js/Express or Python/FastAPI, PostgreSQL, Azure/AWS.
  - Mobile: React Native with TypeScript, Expo for faster iteration, native modules for UPI/biometric integration.

## 1. Product & UX Definition (Week 1–3)
- Finalize key user journeys using UX storyboard:
  - Onboarding + Mirai keyless login and Aadhaar-lite KYC.
  - UPI funding and return-to-app flow (deep linking for Android/iOS).
  - Pack browse/detail, invest flow, SIP setup, portfolio, withdrawals.
- Turn [spec/packs.md](../spec/packs.md) into a concrete V1 pack catalog (IDs, allocations, risk tiers, KYC tiers).
- Define copy guidelines and disclosure patterns for all packs.
- Produce a minimal design system: colors, typography, button styles, cards, charts, form controls.
- **Mobile-specific considerations**:
  - Design for both Android Material and iOS Human Interface Guidelines.
  - Plan for platform-specific UPI handlers (Android Intent, iOS Universal Links).
  - Optimize touch targets and bottom navigation for mobile.

## 2. Backend API & Data Model (Week 2–5)
- Design and document REST/GraphQL APIs for:
  - Auth/session.
  - Pack catalog (list/detail).
  - Quotes and investment orders (create, status).
  - SIP entities (create, pause, resume, cancel).
  - UPI ledger (balance, ledger entries).
  - Portfolio and statements.
- Define data model aligned with [docs/architecture.md](./architecture.md):
  - Users, KYC profiles, wallets.
  - Packs, pack definitions.
  - Orders, SIPs, executions, provider events.
  - INR ledger and crypto holdings.
- Choose and provision the primary database; sketch migration strategy.

## 3. Kana, Wallet & Pack Orchestrator (Week 4–7)
- Integrate Mirai smart wallet SDK for keyless accounts and Paymaster for gasless execution.
- Implement Pack Orchestrator service:
  - Allocation math and route request building based on pack specs.
  - Integration with Kana Aggregator SDK for swaps and bridges.
  - Execution pipeline with idempotency, retries, and event emission.
- Implement price guardrails and route simulation checks as per [docs/architecture.md](./architecture.md):
  - Shadow oracle checks and deviation thresholds.
  - Alerts and fallbacks when thresholds are breached.

## 4. Payments, KYC & Compliance (Week 4–8)
- Implement UPI on-ramp integration according to [spec/payments.md](../spec/payments.md):
  - Provider selection logic.
  - Payment link creation and webhook handlers.
  - INR ledger crediting and settlement assumptions.
- Implement off-ramp and withdrawals with limits and cooling periods.
- Build KYC flows:
  - Tier-1 and Tier-2 onboarding.
  - AML screening integration.
  - Secure KYC storage and retention policies.
- Capture all compliance/audit events (payment → ledger → swap intent) into an immutable log.

## 5. React Native Mobile Application (Week 5–9)
- **Set up React Native project structure**:
  - Initialize with Expo (managed workflow) or bare React Native.
  - Configure TypeScript, ESLint, Prettier.
  - Set up navigation (React Navigation) with bottom tabs and stack navigators.
  - Configure environment variables for dev/stage/prod backends.
- **Implement core flows for Android and iOS**:
  - Onboarding, login, KYC (with native biometric support).
  - Pack browse/detail and investment flow.
  - UPI payment integration:
    - Android: Native module for UPI Intent handling.
    - iOS: Universal Links + webview fallback.
  - Portfolio and SIP management.
- **Integrate with backend APIs** for packs, orders, SIPs, and portfolio.
- **Implement UX patterns** from [design/ux-notes.md](../design/ux-notes.md):
  - Home dashboard, pack cards, confirmation sheet, success state, portfolio.
  - Localization for Hindi and English.
  - React Native Reanimated for smooth animations.
  - Platform-specific UI components (Android Material, iOS native feel).
- **Device integrations**:
  - Push notifications (Firebase Cloud Messaging for Android, APNs for iOS).
  - Biometric authentication (Face ID, Touch ID, fingerprint).
  - Deep linking for payment returns and referrals.
- **Testing on both platforms**:
  - Set up Jest for unit tests.
  - Detox for E2E testing on Android and iOS simulators/devices.
  - Test on multiple screen sizes and OS versions.

## 6. Data, Analytics & Reporting (Week 7–10)
- Define schemas for operational events (orders, SIP runs, swaps, provider events, wallet actions).
- Set up streaming/CDC into a data warehouse (e.g., Synapse/BigQuery).
- Build core dashboards:
  - Weekly recurring buys per active user.
  - Pack-level AUM and performance.
  - Provider performance and failure rates.
- Implement generation of user statements and AIS-compatible tax exports.

## 7. Infra, DevOps & Observability (Week 2–10, ongoing)
- Set up environments (dev/stage/prod) with CI/CD:
  - Backend: GitHub Actions or Azure DevOps for API deployment.
  - **Mobile: EAS Build (Expo) or Fastlane for automated Android/iOS builds**.
  - **App distribution: TestFlight for iOS beta, Google Play Internal Testing for Android**.
- Implement logging, metrics, and tracing standards across services and third-party integrations.
- **Mobile-specific observability**:
  - Crash reporting (Sentry, Firebase Crashlytics).
  - Analytics (Mixpanel, Amplitude) for user flows and funnel tracking.
  - Performance monitoring for app startup, API latency, navigation transitions.
- Add rate limiting, circuit breakers, and backpressure controls for providers and Kana.
- Configure backups, DR, and key rotation where applicable.

## 8. Testing, Security & Reliability (Week 5–11)
- Define and implement testing layers:
  - Unit tests for business logic.
  - Integration tests for providers and Kana (sandbox environments).
  - End-to-end tests for core flows (deposit → pack purchase → portfolio).
- Implement security baselines:
  - AuthN/Z model, secret handling, encryption at rest/in transit.
  - Webhook HMAC verification and replay protection.
- Run performance tests for peak UPI traffic and pack execution.
- Conduct threat modeling and at least one external security review.

## 9. Launch & Operations (Week 10–12)
- **Plan phased rollout**:
  - Internal alpha with TestFlight (iOS) and Internal Testing (Android).
  - Closed beta with 100–500 users via invite codes.
  - Constrained public launch on Google Play Store and Apple App Store.
- **App store preparation**:
  - Prepare app store listings, screenshots, demo videos for Play Store and App Store.
  - Ensure compliance with Play Store and App Store guidelines.
  - Set up in-app rating prompts and review management.
- **Prepare support playbooks** and tooling for:
  - Payment/KYC issues.
  - Swap/bridge delays or failures.
  - Regulatory and tax queries.
  - Platform-specific issues (Android permission problems, iOS certificate issues).
- Create incident response runbooks for provider outages, Kana issues, and pricing anomalies.
- Align GTM with partners (Kana/Zyra, on-ramp providers) and define launch metrics.
- **Monitor app store reviews and ratings** for user feedback and iterate quickly.

## 10. Next 2–3 Sprints (Suggested)

**Sprint 1 (2 weeks)**
- Confirm MVP scope and regulatory posture.
- Lock in **React Native + Expo** for mobile development.
- Choose backend stack (Node.js/Python) and cloud provider (Azure/AWS).
- Finalize UX flows and design system MVP for mobile (Android + iOS).
- Draft API contracts and initial data model.

**Sprint 2 (2 weeks)**
- Scaffold backend services (API gateway + Pack Orchestrator skeleton).
- Implement basic auth and pack catalog read APIs.
- Stub provider and Kana integrations with sandbox keys.
- **Initialize React Native project**:
  - Set up navigation, state management (Redux/Zustand), and API client.
  - Build basic pack browse/detail screens with mock data.
  - Test on both Android emulator and iOS simulator.

Refine this roadmap as decisions are made on stack, providers, and regulatory constraints.