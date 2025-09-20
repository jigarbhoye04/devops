import { ArrowUpRight } from 'lucide-react';
import { FaDiscord, FaGithub, FaLinkedin, FaXTwitter } from 'react-icons/fa6';

const SocialSection = () => {
  return (
    <section className="py-16 lg:py-32 border border-t-0 border-x-0">
      <div className="w-full px-8 xl:px-28">
        <h2 className="mb-5 text-white/80 text-2xl font-semibold md:text-3xl">
          Stay Connected
        </h2>
        <p className="font-medium text-muted-foreground md:text-xl">
          Follow the whispers. Join those who dare to witness the unveiling.
        </p>
        <div className="mt-10 grid grid-cols-1  md:grid-cols-2 lg:grid-cols-4">
          <a
            className="group rounded-none backdrop-blur-3xl border border-border border-r lg:border-r-0 p-6"
            href="#"
          >
            <div className="flex items-center justify-between gap-4">
              <FaXTwitter className="size-5 text-white/80" />
              <ArrowUpRight className="size-4 text-white/80 -translate-x-2 translate-y-2 opacity-100 transition-all group-hover:translate-x-0 group-hover:translate-y-0 group-hover:opacity-100" />
            </div>
            <div className="mt-4">
              <h3 className="mb-1 font-semibold text-white/80">X / Twitter</h3>
              <p className="text-sm text-muted-foreground">
                Catch cryptic hints and coded messages from the creators.
              </p>
            </div>
          </a>
          <a
            className="group rounded-none backdrop-blur-3xl border border-border lg:border-r-0  p-6"
            href="#"
          >
            <div className="flex items-center justify-between gap-4">
              <FaLinkedin className="size-5 text-white/80" />
              <ArrowUpRight className="size-4 text-white/80 -translate-x-2 translate-y-2 opacity-100 transition-all group-hover:translate-x-0 group-hover:translate-y-0 group-hover:opacity-100" />
            </div>
            <div className="mt-4">
              <h3 className="mb-1 font-semibold text-white/80">LinkedIn</h3>
              <p className="text-sm text-muted-foreground">
                Connect with the visionaries behind the revolution.
              </p>
            </div>
          </a>
          <a
            className="group rounded-none backdrop-blur-3xl border border-border lg:border-r-0  p-6"
            href="#"
          >
            <div className="flex items-center justify-between gap-4">
              <FaGithub className="size-5 text-white/80" />
              <ArrowUpRight className="size-4 text-white/80 -translate-x-2 translate-y-2 opacity-100 transition-all group-hover:translate-x-0 group-hover:translate-y-0 group-hover:opacity-100" />
            </div>
            <div className="mt-4">
              <h3 className="mb-1 font-semibold text-white/80">GitHub</h3>
              <p className="text-sm text-muted-foreground">
                Witness the code that will reshape everything we know.
              </p>
            </div>
          </a>
          <a
            className="group rounded-none backdrop-blur-3xl border border-border p-6"
            href="#"
          >
            <div className="flex items-center justify-between gap-4">
              <FaDiscord className="size-5 text-white/80" />
              <ArrowUpRight className="size-4 text-white/80 -translate-x-2 translate-y-2 opacity-100 transition-all group-hover:translate-x-0 group-hover:translate-y-0 group-hover:opacity-100" />
            </div>
            <div className="mt-4">
              <h3 className="mb-1 font-semibold text-white/80">Discord</h3>
              <p className="text-sm text-muted-foreground">
                Join the inner circle. Share theories with fellow seekers.
              </p>
            </div>
          </a>
        </div>
      </div>
    </section>
  );
};

export { SocialSection };
