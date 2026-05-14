import { Microphone, Download } from "iconoir-react"

export default function DownloadCTA() {
  return (
    <section className="bg-[var(--bg-elevated)] py-36 sm:py-48 px-6">
      <div className="max-w-[980px] mx-auto text-center">
        <div className="inline-flex items-center justify-center mb-10 text-[var(--text-primary)]">
          <Microphone width={72} height={72} strokeWidth={1.35} />
        </div>

        <h2
          className="text-[var(--text-primary)] font-semibold mb-6"
          style={{
            fontFamily: "var(--font-display)",
            fontSize: "clamp(2rem, 4vw, 2.5rem)",
            letterSpacing: "-0.025em",
            lineHeight: 1.1,
          }}
        >
          Start recording system audio.
        </h2>
        <p className="text-[var(--text-secondary)] mb-12 max-w-md mx-auto" style={{ fontSize: "17px", lineHeight: 1.47, letterSpacing: "-0.022px" }}>
          Free and open source. Keep your recordings on your Mac, export them
          when you need them, and skip the cloud entirely.
        </p>

        <div className="flex flex-col sm:flex-row items-center justify-center gap-4">
          <a
            href="https://github.com/aramb-dev/SystemVoiceMemos/releases/latest"
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-2 px-[21px] py-[11px] rounded-full bg-interactive-blue text-white hover:bg-interactive-blue/90 transition-colors"
            style={{ fontSize: "17px", lineHeight: 1.47, letterSpacing: "-0.022px" }}
          >
            <Download width={16} height={16} strokeWidth={2} />
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

        <p className="mt-10 text-[var(--text-secondary)]" style={{ fontSize: "12px", letterSpacing: "-0.15px" }}>
          Requires macOS 14.2 Sonoma or later · MIT License · Local recordings only
        </p>
      </div>
    </section>
  )
}
