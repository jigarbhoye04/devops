import { ArrowRight, CheckCircle, Circle, Mail, Zap, Eye } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";

const CtaSection = () => {
  return (
    <section className=" backdrop-blur-3xl border-b py-32">
      <div className=" w-full max-sm:px-12">
        <div className="flex flex-col items-start md:items-center">
          {/* Badge */}
          <Badge className="rounded-none bg-transparent text-white/80 border outline">
            <Eye className="mr-2 h-4 w-4" />
            Join the Vision
          </Badge>

          {/* Heading */}
          <h4 className="mt-4 text-2xl font-semibold tracking-tight md:text-center md:text-3xl xl:text-4xl">
            Be among the first to witness
          </h4>

          {/* Form */}
          <form className="mt-5 flex w-full flex-col gap-2 md:w-auto xl:mt-8 xl:gap-3">
            <div className="group relative flex w-full items-center gap-2 rounded-lg px-3 md:w-[416px]">
              <Input
                type="email"
                required
                placeholder="Enter your email..."
                className="bg-background rounded-none"
              />
              <Button
                type="submit"
                className="rounded-none"
                aria-label="Submit form"
              >
                <ArrowRight className="h-3 w-3" />
              </Button>
            </div>
          </form>

          {/* Features */}
          <div className="mt-5 flex flex-wrap gap-4 md:justify-center xl:mt-8 xl:gap-7">
            <div className="flex items-center gap-2 text-sm xl:text-base">
              <Circle className="h-4 w-4 stroke-[#d0f6ae] stroke-3" />
              Exclusive reveals
            </div>
            <div className="flex items-center gap-2 text-sm xl:text-base">
              <Circle className="h-4 w-4 stroke-[#d0f6ae] stroke-3" />
              Priority access
            </div>
            <div className="flex items-center gap-2 text-sm xl:text-base">
              <Circle className="h-4 w-4 stroke-[#d0f6ae] stroke-3" />
              Behind the scenes
            </div>
          </div>
        </div>
      </div>
    </section>
  );
};

export { CtaSection };