import { Microphone, Download } from "iconoir-react"

export default function DownloadCTA() {
  return (
    <section className="bg-pure-white py-28 px-6">
      <div className="max-w-[980px] mx-auto text-center">
        <div className="inline-flex items-center justify-center w-14 h-14 rounded-[18px] bg-midnight-graphite mb-8 text-white">
          <Microphone width={28} height={28} strokeWidth={1.5} />
        </div>

        <h2
          className="text-midnight-graphite font-semibold mb-4"
          style={{
            fontFamily: "var(--font-display)",
            fontSize: "clamp(2rem, 4vw, 2.5rem)",
            letterSpacing: "-0.025em",
            lineHeight: 1.1,
          }}
        >
          Start capturing today.
        </h2>
        <p className="text-medium-gray mb-10 max-w-md mx-auto" style={{ fontSize: "17px", lineHeight: 1.47, letterSpacing: "-0.022px" }}>
          Free download. No account, no subscription. Your recordings stay on your Mac — always.
        </p>

        <div className="flex flex-col sm:flex-row items-center justify-center gap-[10px]">
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

        <p className="mt-8 text-medium-gray" style={{ fontSize: "12px", letterSpacing: "-0.15px" }}>
          Requires macOS 14.2 Sonoma or later · MIT License · Local recordings only
        </p>
      </div>
    </section>
  )
}
