export default function HowItWorks() {
  const steps = [
    {
      num: "1",
      title: "Pick what to record",
      body: "Choose system audio, microphone, or both depending on whether you are saving playback, voice notes, or a mixed memo.",
    },
    {
      num: "2",
      title: "Press record",
      body: "Start a clean recording from the app and watch the waveform as your memo is captured.",
    },
    {
      num: "3",
      title: "Save or share it",
      body: "Stop when you are done, organize the memo, export it, or share the file straight from your Mac.",
    },
  ]

  return (
    <section className="bg-[var(--bg-elevated)] py-32 sm:py-44 px-6">
      <div className="max-w-[980px] mx-auto">
        <div className="text-center mb-20">
          <p
            className="text-[var(--text-secondary)] mb-6"
            style={{ fontSize: "17px", letterSpacing: "-0.022px", lineHeight: 1.47 }}
          >
            How it works
          </p>
          <h2
            className="text-[var(--text-primary)] font-semibold"
            style={{
              fontFamily: "var(--font-display)",
              fontSize: "clamp(2rem, 4vw, 2.5rem)",
              letterSpacing: "-0.025em",
              lineHeight: 1.1,
            }}
          >
            Recording in three steps.
          </h2>
        </div>

        <div className="grid md:grid-cols-3 gap-14">
          {steps.map((s) => (
            <div key={s.num} className="px-2">
              <span
                className="block font-semibold leading-none mb-8 text-[var(--bg-secondary)]"
                style={{
                  fontFamily: "var(--font-display)",
                  fontSize: "64px",
                  letterSpacing: "-0.03em",
                  lineHeight: 1.0625,
                }}
              >
                {s.num}
              </span>
              <h3
                className="text-[var(--text-primary)] font-semibold mb-4"
                style={{ fontSize: "17px", letterSpacing: "-0.021em", lineHeight: 1.47 }}
              >
                {s.title}
              </h3>
              <p className="text-[var(--text-secondary)]" style={{ fontSize: "14px", lineHeight: 1.4286, letterSpacing: "-0.016em" }}>
                {s.body}
              </p>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}
