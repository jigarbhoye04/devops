import { ArrowUpRight, Lock, Eye, Zap, Shield, MoveRight } from "lucide-react";

import { Button } from "@/components/ui/button";

const projects = [
  {
    heading: "Project Enigma",
    subheading: "Classification: Ultra",
    description:
      "A breakthrough innovation that will fundamentally change how you interact with technology. Details remain classified until the official unveiling. Only those on the inside will know what's coming.",
    image:
      "https://cdn.cosmos.so/d33ccd12-48ec-47f7-bd5e-bd497a5f5fb1?format=jpeg",
    url: "#",
    icon: Lock,
  },
  {
    heading: "The Nexus Protocol",
    subheading: "Reality Redefined",
    description:
      "Something extraordinary is being forged in our laboratories. The boundaries between possible and impossible are about to blur. The chosen few will witness history in the making.",
    image:
      "https://cdn.cosmos.so/d828d816-1d9b-4816-9353-7a58fcfde3a9?format=jpeg",
    url: "#",
    icon: Eye,
  },
  {
    heading: "Quantum Disruption",
    subheading: "Beyond Imagination",
    description:
      "Revolutionary technology that defies conventional thinking. Our engineers have unlocked something that will make today's innovations seem primitive. The future is closer than you think.",
    image:
      "https://cdn.cosmos.so/70637007-22b1-4ad4-8076-e085f761c943?format=jpeg",
    url: "#",
    icon: Zap,
  },
  {
    heading: "Operation Catalyst",
    subheading: "The Final Frontier",
    description:
      "The culmination of years of secretive research and development. A product so groundbreaking, it required the brightest minds working in absolute secrecy. The world will never be the same.",
    image:
      "https://cdn.cosmos.so/ee6edeb0-9a64-4452-9a47-5cfa02039ab7?format=jpeg",
    url: "#",
    icon: Shield,
  },
];

const ProjectSection = () => {
  return (
    <section className="py-16 lg:py-32 max-sm:px-6 w-full  backdrop-blur-3xl">
      <div className="w-full">
        <div className="w-full lg:px-16 mx-auto">
          <p className="text-muted-foreground mb-1 uppercase md:text-lg">
            Something Revolutionary is Coming
          </p>
          <h1 className="text-3xl font-bold uppercase md:text-7xl">Classified</h1>
          <p className="text-muted-foreground mt-7 max-w-2xl">
            Behind closed doors, our team of visionaries is crafting something 
            that will reshape the future. These glimpses into our classified 
            projects are all we can reveal—for now. Join the waitlist to be 
            among the first to witness the impossible become reality.
          </p>
          <Button className="group mt-7 border border-white/20 bg-transparent text-white hover:bg-white/10 rounded-none px">
            Join the Waitlist
            <MoveRight className="h-4 w-4 transition-transform duration-500 ease-out group-hover:translate-x-2" />
          </Button>
        </div>
        <div className="mt-24 flex flex-col gap-5 md:mt-36">
          {projects.map((project, idx) => (
            <a
              key={idx}
              href={project.url}
              className="group relative isolate min-h-96 lg:min-h-72 bg-cover bg-center px-5 py-14 lg:px-12 border border-x-0 max-sm:pb-32 lg:py-24"
              style={{
                backgroundImage: `url(${project.image})`,
              }}
            >
              <div className="relative z-10 flex flex-col gap-7 text-white/80 transition-colors duration-300 ease-out group-hover:text-white lg:flex-row">
                <div className="flex gap-1 text-2xl font-bold items-center">
                  <project.icon className="size-6" />
                  <span>/</span>
                  <span>{String(idx + 1).padStart(2, "0")}</span>
                </div>
                <div className="flex flex-1 flex-col gap-2.5">
                  <h3 className="text-2xl font-bold lg:text-4xl">
                    {project.heading}
                  </h3>
                  <p className="text-sm font-medium uppercase text-red-400">
                    {project.subheading}
                  </p>
                </div>
                <div className="flex-1">
                  <div className="flex flex-col">
                    <p>{project.description}</p>
                    <div className="mt-2.5 h-0 transition-all duration-300 ease-out group-hover:h-10">
                      <div>
                        <Button className="rounded-none bg-transparent text-white border mt-4 w-fit opacity-90 transition-opacity duration-300 ease-out group-hover:opacity-100">
                          Learn More
                          <ArrowUpRight className="size-4" />
                        </Button>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
              <div className="backdrop-blur-xs absolute inset-0 z-0 bg-black/80 transition-all duration-300 ease-out group-hover:bg-black/50 group-hover:backdrop-blur-none" />
            </a>
          ))}
        </div>
      </div>
    </section>
  );
};

export { ProjectSection };