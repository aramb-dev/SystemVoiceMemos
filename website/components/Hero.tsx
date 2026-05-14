export default function Hero() {
  return (
    <section className="relative flex flex-col items-center bg-canvas-white overflow-hidden pt-[44px]">
      <div className="relative z-10 flex flex-col items-center text-center px-6 pt-32 pb-28">
        <p
          className="text-medium-gray mb-5"
          style={{ fontSize: "17px", letterSpacing: "-0.022px", lineHeight: 1.47 }}
        >
          v0.10.3 — Core Audio Tap
        </p>

        <h1
          className="max-w-4xl text-midnight-graphite font-semibold mb-6"
          style={{
            fontFamily: "var(--font-display)",
            fontSize: "clamp(2.75rem, 7vw, 3.5rem)",
            lineHeight: 1.07,
            letterSpacing: "-0.28px",
          }}
        >
          Capture every sound.
          <br />
          Nothing else.
        </h1>

        <p
          className="max-w-xl text-medium-gray mb-10"
          style={{ fontSize: "24px", lineHeight: 1.33, letterSpacing: "-0.24px" }}
        >
          A native macOS audio recorder that taps directly into system audio —
          no screen-recording permission, no subscriptions, no cloud.
        </p>

        <div className="flex flex-wrap items-center justify-center gap-[10px] mb-16">
          <a
            href="https://github.com/aramb-dev/SystemVoiceMemos/releases/latest"
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center px-[21px] py-[11px] rounded-full bg-interactive-blue text-white hover:bg-interactive-blue/90 transition-colors"
            style={{ fontSize: "17px", lineHeight: 1.47, letterSpacing: "-0.022px" }}
          >
            Download for macOS
          </a>
          <a
            href="https://github.com/aramb-dev/SystemVoiceMemos"
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-0.5 px-[21px] py-[11px] rounded-full border border-action-blue text-action-blue hover:bg-action-blue hover:text-white transition-colors"
            style={{ fontSize: "17px", lineHeight: 1.47, letterSpacing: "-0.022px" }}
          >
            View on GitHub
          </a>
        </div>

        <div className="flex flex-wrap items-center justify-center gap-6">
          {["macOS 14.2+", "Free & Open Source", "Local recordings only"].map((t) => (
            <span key={t} className="text-[12px] text-medium-gray" style={{ letterSpacing: "-0.15px" }}>{t}</span>
          ))}
        </div>
      </div>
    </section>
  )
}
