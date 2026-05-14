export default function Hero() {
  return (
    <section className="relative flex flex-col items-center bg-[var(--bg-primary)] overflow-hidden pt-[44px]">
      <div className="relative z-10 flex flex-col items-center text-center px-6 pt-32 pb-36 sm:pt-40 sm:pb-48">
        <p
          className="text-[var(--text-secondary)] mb-6"
          style={{ fontSize: "17px", letterSpacing: "-0.022px", lineHeight: 1.47 }}
        >
          Open source for macOS
        </p>

        <h1
          className="max-w-4xl text-[var(--text-primary)] font-semibold mb-8"
          style={{
            fontFamily: "var(--font-display)",
            fontSize: "clamp(2.75rem, 7vw, 3.5rem)",
            lineHeight: 1.07,
            letterSpacing: "-0.28px",
          }}
        >
          Voice Memos for
          <br />
          system audio.
        </h1>

        <p
          className="max-w-2xl text-[var(--text-secondary)] mb-12"
          style={{ fontSize: "24px", lineHeight: 1.33, letterSpacing: "-0.24px" }}
        >
          Record what your Mac is playing, your microphone, or both in one
          simple app. No account, no subscription, no cloud.
        </p>

        <div className="flex flex-wrap items-center justify-center gap-3 mb-16">
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

        <div className="flex flex-wrap items-center justify-center gap-x-8 gap-y-3">
          {["macOS 14.2+", "Free and open source", "Local recordings only"].map((t) => (
            <span key={t} className="text-[12px] text-[var(--text-secondary)]" style={{ letterSpacing: "-0.15px" }}>{t}</span>
          ))}
        </div>
      </div>
    </section>
  )
}
