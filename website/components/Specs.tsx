const specs = [
  { label: "macOS version", value: "14.2 Sonoma or later" },
  { label: "Architecture", value: "Apple Silicon · Intel" },
  { label: "Audio source", value: "System · Mic · Both" },
  { label: "Export formats", value: "M4A · MP3 · WAV · AIFF" },
  { label: "Storage", value: "Local only, no cloud" },
  { label: "Auto-updates", value: "Signed · Notarized · Automatic" },
  { label: "Price", value: "Free and open source" },
  { label: "License", value: "MIT" },
]

export default function Specs() {
  return (
    <section className="bg-canvas-white py-28 px-6">
      <div className="max-w-[980px] mx-auto grid lg:grid-cols-2 gap-16 items-start">
        <div className="pt-2">
          <p
            className="text-medium-gray mb-5"
            style={{ fontSize: "17px", letterSpacing: "-0.022px", lineHeight: 1.47 }}
          >
            System requirements
          </p>
          <h2
            className="text-midnight-graphite font-semibold mb-5"
            style={{
              fontFamily: "var(--font-display)",
              fontSize: "clamp(1.75rem, 3.5vw, 2.25rem)",
              letterSpacing: "-0.025em",
              lineHeight: 1.1,
            }}
          >
            Lean and native.
          </h2>
          <p className="text-medium-gray" style={{ fontSize: "17px", lineHeight: 1.47, letterSpacing: "-0.022px" }}>
            A pure Swift app — no Electron, no bundled runtimes. Installs in seconds,
            runs quietly in the menu bar, and stays out of your way.
          </p>
        </div>

        <div className="overflow-hidden border border-border-silver bg-pure-white">
          {specs.map((s, i) => (
            <div
              key={s.label}
              className={`flex items-center justify-between px-5 py-3.5 ${
                i < specs.length - 1 ? "border-b border-border-silver" : ""
              }`}
            >
              <span className="text-medium-gray" style={{ fontSize: "14px", letterSpacing: "-0.18px" }}>{s.label}</span>
              <span className="text-midnight-graphite font-normal" style={{ fontSize: "14px", letterSpacing: "-0.18px" }}>{s.value}</span>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}
