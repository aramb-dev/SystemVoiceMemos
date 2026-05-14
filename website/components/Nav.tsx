import { Microphone } from "iconoir-react"

export default function Nav() {
  return (
    <header className="fixed top-0 inset-x-0 z-50 nav-blur">
      <nav className="max-w-[980px] mx-auto h-[44px] flex items-center justify-between px-6">
        <a href="/" className="flex items-center gap-2">
          <div className="w-8 h-8 rounded-[9px] bg-[var(--text-primary)] flex items-center justify-center">
            <Microphone className="text-[var(--text-inverse)]" width={18} height={18} strokeWidth={1.8} />
          </div>
          <span className="text-[14px] font-normal text-[var(--text-primary)] tracking-[-0.01em]">SystemVoiceMemos</span>
        </a>

        <div className="flex items-center gap-5">
          <a
            href="https://github.com/aramb-dev/SystemVoiceMemos"
            target="_blank"
            rel="noopener noreferrer"
            className="text-[14px] text-[var(--text-primary)] hover:text-[var(--text-link)] transition-colors hidden sm:block"
          >
            GitHub
          </a>
          <a
            href="https://github.com/aramb-dev/SystemVoiceMemos/releases/latest"
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center px-[18px] py-[6px] rounded-full bg-interactive-blue text-white text-[14px] font-normal hover:bg-interactive-blue/90 transition-colors"
          >
            Download
          </a>
        </div>
      </nav>
    </header>
  )
}
