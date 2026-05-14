import Nav from "@/components/Nav"
import Hero from "@/components/Hero"
import Features from "@/components/Features"
import HowItWorks from "@/components/HowItWorks"
import Specs from "@/components/Specs"
import DownloadCTA from "@/components/DownloadCTA"
import Footer from "@/components/Footer"

export default function Page() {
  return (
    <>
      <Nav />
      <main>
        <Hero />
        <Features />
        <HowItWorks />
        <Specs />
        <DownloadCTA />
      </main>
      <Footer />
    </>
  )
}
