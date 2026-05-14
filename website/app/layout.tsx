import type { Metadata } from "next"
import "./globals.css"

export const metadata: Metadata = {
  title: "SystemVoiceMemos — System Audio Recorder for macOS",
  description:
    "Capture system audio and microphone on macOS without Screen Recording permission. Local M4A files, multiple export formats, folder organization.",
  openGraph: {
    title: "SystemVoiceMemos",
    description: "Capture system audio on macOS — no screen recording required.",
    type: "website",
  },
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  )
}
