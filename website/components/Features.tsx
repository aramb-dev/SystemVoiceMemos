import { ShieldCheck, SoundHigh, MusicNote, Lock, Folder, RefreshDouble } from "iconoir-react"

const features = [
  {
    icon: <ShieldCheck width={58} height={58} strokeWidth={1.35} />,
    title: "Record system audio",
    body: "Capture calls, videos, music, lectures, or any other sound playing on your Mac without a complicated setup.",
  },
  {
    icon: <SoundHigh width={58} height={58} strokeWidth={1.35} />,
    title: "Add your microphone",
    body: "Record system audio alone, your voice alone, or both together when you want narration or notes in the same memo.",
  },
  {
    icon: <MusicNote width={58} height={58} strokeWidth={1.35} />,
    title: "Export common formats",
    body: "Save recordings as M4A, MP3, WAV, or AIFF, then share them or reveal the file in Finder.",
  },
  {
    icon: <Lock width={58} height={58} strokeWidth={1.35} />,
    title: "Private by default",
    body: "Recordings stay on your Mac. There is no account, cloud sync, subscription, or analytics pipeline behind the app.",
  },
  {
    icon: <Folder width={58} height={58} strokeWidth={1.35} />,
    title: "Organize like Voice Memos",
    body: "Keep captures in folders, rename them, move them, and come back later without hunting through random filenames.",
  },
  {
    icon: <RefreshDouble width={58} height={58} strokeWidth={1.35} />,
    title: "Open source updates",
    body: "Install signed releases from GitHub and keep up with improvements while the project stays inspectable and free.",
  },
]

export default function Features() {
  return (
    <section className="bg-[var(--bg-primary)] py-32 sm:py-44 px-6">
      <div className="max-w-[980px] mx-auto">
        <div className="text-center mb-20">
          <p
            className="text-[var(--text-secondary)] mb-6"
            style={{ fontSize: "17px", letterSpacing: "-0.022px", lineHeight: 1.47 }}
          >
            Made for everyday captures
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
            The missing system audio recorder.
          </h2>
        </div>

        <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-x-12 gap-y-16">
          {features.map((f) => (
            <div key={f.title} className="px-2">
              <div className="mb-8 text-[var(--text-primary)]">
                {f.icon}
              </div>
              <h3
                className="text-[var(--text-primary)] font-semibold mb-4"
                style={{ fontSize: "17px", letterSpacing: "-0.021em", lineHeight: 1.47 }}
              >
                {f.title}
              </h3>
              <p className="text-[var(--text-secondary)]" style={{ fontSize: "14px", lineHeight: 1.4286, letterSpacing: "-0.016em" }}>
                {f.body}
              </p>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}
