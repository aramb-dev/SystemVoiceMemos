import { Github } from "iconoir-react"

export default function Footer() {
  const links = [
    { label: "Releases", href: "https://github.com/aramb-dev/SystemVoiceMemos/releases" },
    { label: "Issues", href: "https://github.com/aramb-dev/SystemVoiceMemos/issues" },
    { label: "GitHub", href: "https://github.com/aramb-dev/SystemVoiceMemos" },
  ]

  return (
    <footer className="bg-midnight-graphite border-t border-white/10">
      <div className="max-w-[980px] mx-auto px-6 py-8 flex flex-col sm:flex-row items-center justify-between gap-4">
        <p className="text-medium-gray" style={{ fontSize: "12px", letterSpacing: "-0.15px" }}>
          Copyright © {new Date().getFullYear()} Abdur-Rahman Bilal · MIT License
        </p>

        <nav className="flex items-center gap-6">
          {links.map((l) => (
            <a
              key={l.label}
              href={l.href}
              target="_blank"
              rel="noopener noreferrer"
              className="flex items-center gap-1.5 text-medium-gray hover:text-white transition-colors"
              style={{ fontSize: "12px", letterSpacing: "-0.15px" }}
            >
              {l.label === "GitHub" && <Github width={13} height={13} strokeWidth={1.5} />}
              {l.label}
            </a>
          ))}
        </nav>
      </div>
    </footer>
  )
}
