import { Circle } from "lucide-react";
import React from "react";

type Props = object;

function FeatureSection({}: Props) {
  return (
    <div className="w-full backdrop-blur-2xl min-h-[300px] max-sm:py-16 lg:h-[600px]  border-b flex flex-col-reverse lg:flex-row items-center">
      <div className="lg:w-1/2 flex   lg:justify-center">
        <img
          src="/feature.png"
          alt="Hero Image"
          className="rounded-lg brightness-80 hover:scale-105 duration-200 hover:animate-pulse"
        />
      </div>{" "}
      <div className="lg:w-1/2 lg:border-l lg:pl-16 px-8  flex flex-col justify-center h-full">
        <div className="flex mb-8 items-center gap-2">
          <h3 className="font-sans text-base capitalize">
            SOMETHING EXTRAORDINARY IS
          </h3>
          <Circle
            size={16}
            strokeWidth={4}
            className="stroke-[#d0f6ae] font-extrabold"
          />
        </div>
        <h1 className="">
          Beyond your <br /> imagination
        </h1>
        <p className="mt-8 max-w-lg ">
          Revolutionary technology meets visionary design. The future arrives
          sooner than expected
        </p>
      </div>
    </div>
  );
}

export default FeatureSection;