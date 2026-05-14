export default function HowItWorks() {
  const steps = [
    {
      num: "1",
      title: "Choose your source",
      body: "Select System Audio, Microphone, or Both. The app remembers your preference across launches.",
    },
    {
      num: "2",
      title: "Press record",
      body: "One click starts the Core Audio tap. No permission dialogs, no setup — the waveform appears immediately.",
    },
    {
      num: "3",
      title: "Export and share",
      body: "Stop recording, then export to M4A, MP3, WAV, or AIFF in one step. Or share directly from the app.",
    },
  ]

  return (
    <section className="bg-pure-white py-28 px-6">
      <div className="max-w-[980px] mx-auto">
        <div className="text-center mb-20">
          <p
            className="text-medium-gray mb-4"
            style={{ fontSize: "17px", letterSpacing: "-0.022px", lineHeight: 1.47 }}
          >
            How it works
          </p>
          <h2
            className="text-midnight-graphite font-semibold"
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

        <div className="grid md:grid-cols-3 gap-px bg-border-silver">
          {steps.map((s) => (
            <div key={s.num} className="bg-pure-white p-8">
              <span
                className="block font-bold leading-none mb-6 text-lightest-gray"
                style={{
                  fontFamily: "var(--font-display)",
                  fontSize: "56px",
                  letterSpacing: "-0.28px",
                  lineHeight: 1.07,
                }}
              >
                {s.num}
              </span>
              <h3
                className="text-midnight-graphite font-semibold mb-2"
                style={{ fontSize: "17px", letterSpacing: "-0.015em", lineHeight: 1.47 }}
              >
                {s.title}
              </h3>
              <p className="text-medium-gray" style={{ fontSize: "14px", lineHeight: 1.47, letterSpacing: "-0.18px" }}>
                {s.body}
              </p>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}
