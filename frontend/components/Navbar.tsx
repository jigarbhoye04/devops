"use client";

import { ArrowRight, Framer, MenuIcon } from "lucide-react";
import Link from "next/link";

import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from "@/components/ui/accordion";
import { Button } from "@/components/ui/button";
// import {
//   NavigationMenu,
//   NavigationMenuContent,
//   NavigationMenuItem,
//   NavigationMenuLink,
//   NavigationMenuList,
//   NavigationMenuTrigger,
//   navigationMenuTriggerStyle,
// } from "@/components/ui/navigation-menu";
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
  SheetTrigger,
} from "@/components/ui/sheet";

const Navbar5 = () => {
  const features = [
    {
      title: "Encrypted",
      description: "Secured beyond measure",
      href: "#",
    },
    {
      title: "Quantum",
      description: "Advanced technology core",
      href: "#",
    },
    {
      title: "Neural",
      description: "Intelligence redefined",
      href: "#",
    },
    {
      title: "Adaptive",
      description: "Evolves with purpose",
      href: "#",
    },
    {
      title: "Infinite",
      description: "Limitless potential",
      href: "#",
    },
    {
      title: "Unknown",
      description: "Beyond comprehension",
      href: "#",
    },
  ];

  const navLinks = [
    { name: "Vision", href: "#" },
    { name: "Creators", href: "#" },
    { name: "Intel", href: "#" },
    { name: "Origins", href: "#" },
  ];

  return (
    <section className=" sticky bg-[url('https://cdn.sanity.io/images/71u2kr0t/production/d448e7e6ea7a741311d190aa16731d16b78ae736-6048x4024.jpg?w=3840&h=2555&q=70&auto=format')] z-50 bg-cover bg-center bg-fixed border-b border-border top-0">
      <div className="w-full max-sm:px-4 max-sm:py-2 ">
        <nav className="flex items-center justify-between">
          <Link href="/" className="flex lg:w-1/2 lg:pl-6  items-center gap-2">
            <Framer />
            <h3 className="text-lg font-semibold tracking-tighter">
              PROJECT X
            </h3>
          </Link>
          <div className="hidden w-1/2 lg:flex items-center h-full">
            {navLinks.map((link, idx) => (
              <Link
                key={link.name}
                href={link.href}
                className={`px-8 py-6
 text-lg font-medium text-muted-foreground hover:text-foreground w-full justify-center h-full flex items-center border-t-0 border-b-0 border`}
              >
                {link.name}
              </Link>
            ))}
            <Link
              href="#"
              className="px-8 py-2 text-lg font-medium text-muted-foreground hover:text-foreground h-full flex items-center gap-2"
            >
              <span>Join Now</span>
              <ArrowRight />
            </Link>
          </div>
          <Sheet>
            <SheetTrigger asChild className="lg:hidden">
              <MenuIcon className="h-4 w-4" />
            </SheetTrigger>
            <SheetContent side="top" className="max-h-screen overflow-auto">
              <SheetHeader>
                <SheetTitle>
                  <Link href="/" className="flex items-center gap-2">
                    <Framer className="h-12 w-12" />
                    <span className="text-lg font-semibold tracking-tighter">
                      PROJECT X
                    </span>
                  </Link>
                </SheetTitle>
              </SheetHeader>
              <div className="flex flex-col p-4">
                <Accordion type="single" collapsible className="mt-4 mb-2">
                  <AccordionItem value="solutions" className="border-none">
                    <AccordionTrigger className="text-base hover:no-underline">
                      Classified
                    </AccordionTrigger>
                    <AccordionContent>
                      <div className="grid md:grid-cols-2">
                        {features.map((feature, index) => (
                          <a
                            href={feature.href}
                            key={index}
                            className="rounded-md p-3 transition-colors hover:bg-muted/70"
                          >
                            <div key={feature.title}>
                              <p className="mb-1 font-semibold text-foreground">
                                {feature.title}
                              </p>
                              <p className="text-sm text-muted-foreground">
                                {feature.description}
                              </p>
                            </div>
                          </a>
                        ))}
                      </div>
                    </AccordionContent>
                  </AccordionItem>
                </Accordion>
                <div className="flex flex-col gap-6">
                  <a href="#" className="font-medium">
                    Manifesto
                  </a>
                  <a href="#" className="font-medium">
                    Intel
                  </a>
                  <a href="#" className="font-medium">
                    Waitlist
                  </a>
                </div>
                <div className="mt-6 flex flex-col gap-4">
                  <Button variant="outline">Access Code</Button>
                  <Button>Join Waitlist</Button>
                </div>
              </div>
            </SheetContent>
          </Sheet>
        </nav>
      </div>
    </section>
  );
};

export { Navbar5 };