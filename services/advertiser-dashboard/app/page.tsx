import { CaseStudySection } from '@/components/CaseSetudySection';
import { CtaSection } from '@/components/CTASection';
import FeatureSection from '@/components/FeatureSection';
import FeatureSectionTwo from '@/components/FeatureSectionTwo';
import { Footer } from '@/components/Footer';
import HeroSection from '@/components/HeroSection';
import { ProjectSection } from '@/components/ProjectSection';
import { SocialSection } from '@/components/SocialSection';

export default function Home() {
  return (
    //bg-[#14281D]
    <main className="min-h-screen w-full flex flex-col   text-white">
      <HeroSection />
      <FeatureSection />
      <FeatureSectionTwo />
      <ProjectSection />
      <CaseStudySection />
      <SocialSection />
      <CtaSection />
      <Footer />
    </main>
  );
}
