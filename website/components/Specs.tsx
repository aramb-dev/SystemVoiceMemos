const specs = [
  { label: "macOS version", value: "14.2 Sonoma or later" },
  { label: "Records", value: "System audio · Mic · Both" },
  { label: "Export formats", value: "M4A · MP3 · WAV · AIFF" },
  { label: "Files", value: "Stored locally on your Mac" },
  { label: "Organization", value: "Folders · Rename · Move" },
  { label: "Updates", value: "Signed GitHub releases" },
  { label: "Price", value: "Free and open source" },
  { label: "License", value: "MIT" },
]

export default function Specs() {
  return (
    <section className="bg-[var(--bg-primary)] py-32 sm:py-44 px-6">
      <div className="max-w-[980px] mx-auto grid lg:grid-cols-2 gap-16 items-start">
        <div className="pt-6">
          <p
            className="text-[var(--text-secondary)] mb-5"
            style={{ fontSize: "17px", letterSpacing: "-0.022em", lineHeight: 1.47 }}
          >
            What you get
          </p>
          <h2
            className="text-[var(--text-primary)] font-semibold mb-6"
            style={{
              fontFamily: "var(--font-display)",
              fontSize: "clamp(1.75rem, 3.5vw, 2.25rem)",
              letterSpacing: "-0.025em",
              lineHeight: 1.1,
            }}
          >
            Simple, local, and yours.
          </h2>
          <p className="text-[var(--text-secondary)]" style={{ fontSize: "17px", lineHeight: 1.47, letterSpacing: "-0.022em" }}>
            SystemVoiceMemos is for saving the audio already playing on your
            Mac, then treating it like a regular voice memo you can organize,
            export, and keep private.
          </p>
        </div>

        <div className="overflow-hidden border border-[var(--border-primary)] bg-[var(--bg-elevated)] rounded-[11px]">
          {specs.map((s, i) => (
            <div
              key={s.label}
              className={`flex items-center justify-between gap-6 px-6 py-4 ${
                i < specs.length - 1 ? "border-b border-[var(--border-primary)]" : ""
              }`}
            >
              <span className="text-[var(--text-secondary)]" style={{ fontSize: "14px", letterSpacing: "-0.18px" }}>{s.label}</span>
              <span className="text-[var(--text-primary)] font-normal" style={{ fontSize: "14px", letterSpacing: "-0.18px" }}>{s.value}</span>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}
