import type { Metadata } from "next"
import "./globals.css"

export const metadata: Metadata = {
  title: "SystemVoiceMemos — Open Source Voice Memos for System Audio",
  description:
    "An open source Voice Memos-style app for recording system audio and microphone on macOS. Local files, simple folders, and no account.",
  openGraph: {
    title: "SystemVoiceMemos",
    description: "Open source Voice Memos for your Mac's system audio.",
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
