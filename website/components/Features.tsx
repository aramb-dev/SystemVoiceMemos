import { ShieldCheck, SoundHigh, MusicNote, Lock, Folder, RefreshDouble } from "iconoir-react"

const features = [
  {
    icon: <ShieldCheck width={22} height={22} strokeWidth={1.5} />,
    title: "No screen recording needed",
    body: "Uses the macOS 14.2+ Core Audio process tap to capture system audio directly — zero screen-sharing, zero privacy footprint.",
  },
  {
    icon: <SoundHigh width={22} height={22} strokeWidth={1.5} />,
    title: "System audio, mic, or both",
    body: "Switch sources on the fly — system audio alone, microphone alone, or a combined mix. Your selection is remembered.",
  },
  {
    icon: <MusicNote width={22} height={22} strokeWidth={1.5} />,
    title: "M4A, MP3, WAV, and AIFF",
    body: "Export to any major audio format after capture. Share straight from the app or reveal the file in Finder.",
  },
  {
    icon: <Lock width={22} height={22} strokeWidth={1.5} />,
    title: "Local and private",
    body: "Recordings live on your Mac as plain M4A files. No account, no cloud, no analytics. You own your audio.",
  },
  {
    icon: <Folder width={22} height={22} strokeWidth={1.5} />,
    title: "Folders and organization",
    body: "Group recordings into folders using SwiftData relationships. Find any capture instantly without file-name guessing.",
  },
  {
    icon: <RefreshDouble width={22} height={22} strokeWidth={1.5} />,
    title: "Automatic updates",
    body: "Every release is notarized, signed, and delivered automatically. You always have the latest version without lifting a finger.",
  },
]

export default function Features() {
  return (
    <section className="bg-canvas-white py-28 px-6">
      <div className="max-w-[980px] mx-auto">
        <div className="text-center mb-16">
          <p
            className="text-medium-gray mb-4"
            style={{ fontSize: "17px", letterSpacing: "-0.022px", lineHeight: 1.47 }}
          >
            Built for macOS
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
            Everything you need to capture audio.
          </h2>
        </div>

        <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-px bg-border-silver">
          {features.map((f) => (
            <div key={f.title} className="bg-canvas-white p-8">
              <div className="w-11 h-11 rounded-[11px] bg-lightest-gray flex items-center justify-center mb-5 text-midnight-graphite">
                {f.icon}
              </div>
              <h3
                className="text-midnight-graphite font-semibold mb-2"
                style={{ fontSize: "17px", letterSpacing: "-0.015em", lineHeight: 1.47 }}
              >
                {f.title}
              </h3>
              <p className="text-medium-gray" style={{ fontSize: "14px", lineHeight: 1.47, letterSpacing: "-0.18px" }}>
                {f.body}
              </p>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}
