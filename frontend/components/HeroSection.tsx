import React from 'react';

type Props = object;

function HeroSection({}: Props) {
  return (
    <div className="w-full h-full min-h-[300px] lg:h-[600px]  border-b flex flex-col lg:flex-row items-center">
      <div className="lg:w-1/2 lg:border-r px-8 max-sm: py-8 lg:px-12 lg:ml-[2px] flex flex-col justify-center h-full">
        <h1 className="">
          Something revolutionary is coming. The future starts here.
        </h1>
        <p className="mt-8 max-w-lg ">
          We&apos;re building what&apos;s next. Be among the first to witness
          the transformation.
        </p>
      </div>
      <div className="lg:w-1/2 max-md:backdrop-blur-sm  flex justify-center">
        <img
          src="/hero.png"
          alt="Hero Image"
          className="rounded-lg hover:scale-105 duration-200 hover:animate-pulse"
        />
      </div>
    </div>
  );
}

export default HeroSection;
