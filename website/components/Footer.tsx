import { Github } from "iconoir-react"

export default function Footer() {
  const links = [
    { label: "Releases", href: "https://github.com/aramb-dev/SystemVoiceMemos/releases" },
    { label: "Issues", href: "https://github.com/aramb-dev/SystemVoiceMemos/issues" },
    { label: "GitHub", href: "https://github.com/aramb-dev/SystemVoiceMemos" },
  ]

  return (
    <footer className="bg-[var(--bg-secondary)] border-t border-[var(--border-primary)]">
      <div className="max-w-[980px] mx-auto px-6 py-12 flex flex-col sm:flex-row items-center justify-between gap-6">
        <p className="text-[var(--text-secondary)]" style={{ fontSize: "12px", letterSpacing: "-0.15px" }}>
          Copyright © {new Date().getFullYear()} Abdur-Rahman Bilal · MIT License
        </p>

        <nav className="flex items-center gap-8">
          {links.map((l) => (
            <a
              key={l.label}
              href={l.href}
              target="_blank"
              rel="noopener noreferrer"
              className="flex items-center gap-2 text-[var(--text-secondary)] hover:text-[var(--text-primary)] transition-colors"
              style={{ fontSize: "12px", letterSpacing: "-0.15px" }}
            >
              {l.label === "GitHub" && <Github width={16} height={16} strokeWidth={1.5} />}
              {l.label}
            </a>
          ))}
        </nav>
      </div>
    </footer>
  )
}
