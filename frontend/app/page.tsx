'use client';

import { useEffect, useRef } from 'react';

// Hand-drawn doodle components
const DoodleGrass = () => (
  <svg
    width="32"
    height="32"
    viewBox="0 0 24 24"
    fill="none"
    xmlns="http://www.w3.org/2000/svg"
    stroke="#34d399"
    strokeWidth="1.5"
    strokeLinecap="round"
    strokeLinejoin="round"
  >
    <path d="M4 20V10C4 8.89543 4.89543 8 6 8H7C8.10457 8 9 8.89543 9 10V20" />
    <path d="M9 20V12C9 10.8954 9.89543 10 11 10H12C13.1046 10 14 10.8954 14 12V20" />
    <path d="M14 20V14C14 12.8954 14.8954 12 16 12H17C18.1046 12 19 12.8954 19 14V20" />
  </svg>
);

const DoodleCloud = () => (
  <svg
    width="40"
    height="40"
    viewBox="0 0 24 24"
    fill="none"
    xmlns="http://www.w3.org/2000/svg"
  >
    <path
      d="M18.5 15.5C20.433 15.5 22 13.933 22 12C22 10.067 20.433 8.5 18.5 8.5C18.5 6.01472 16.4853 4 14 4C11.9237 4 10.1898 5.33433 9.5 7.09998C8.04258 6.82101 6.5 7.7342 6.5 9.5C6.5 11.2658 8.04258 12.179 9.5 11.9C10.1898 13.6657 11.9237 15 14 15C15.0363 15 15.9699 14.6341 16.7071 14.0355C17.2494 14.952 17.567 15.5 18.5 15.5Z"
      stroke="#a7c7e7"
      strokeWidth="1.5"
      fill="#dceefb"
      strokeLinecap="round"
      strokeLinejoin="round"
    />
  </svg>
);

const DoodleSparkle = () => (
  <svg
    width="24"
    height="24"
    viewBox="0 0 24 24"
    fill="none"
    xmlns="http://www.w3.org/2000/svg"
  >
    <path
      d="M12 2L14.5 9.5L22 12L14.5 14.5L12 22L9.5 14.5L2 12L9.5 9.5L12 2Z"
      stroke="#fde047"
      strokeWidth="1.5"
      strokeLinecap="round"
      strokeLinejoin="round"
    />
  </svg>
);

export default function Home() {
  const containerRef = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    // mouse move parallax
    function onMove(e: MouseEvent) {
      const node = containerRef.current;
      if (!node) return;
      const rect = node.getBoundingClientRect();
      const cx = rect.left + rect.width / 2;
      const cy = rect.top + rect.height / 2;
      const dx = (e.clientX - cx) / rect.width; // -0.5..0.5
      const dy = (e.clientY - cy) / rect.height;

      node.style.setProperty('--px', `${dx * 22}px`);
      node.style.setProperty('--py', `${dy * 18}px`);
    }

    // simple scroll parallax for shapes
    function onScroll() {
      const node = containerRef.current;
      if (!node) return;
      const st = window.scrollY;
      node.style.setProperty('--scroll', `${st * 0.05}px`);
    }

    window.addEventListener('mousemove', onMove);
    window.addEventListener('scroll', onScroll, { passive: true });
    onScroll();

    return () => {
      window.removeEventListener('mousemove', onMove);
      window.removeEventListener('scroll', onScroll);
    };
  }, []);

  return (
    <div ref={containerRef} className="page-center" data-parallax>
      <div className="hero">
        <div className="hero-left">
          <div style={{ position: 'relative' }}>
            {/* floating organic shapes */}
            <div
              className="shape morph floaty-slow soft"
              style={{
                width: 280,
                height: 220,
                left: -80,
                top: -80,
                background: 'var(--accent-2)',
              }}
              aria-hidden
            />
            <div
              className="shape morph floaty soft"
              style={{
                width: 180,
                height: 180,
                right: -60,
                top: 10,
                background: 'var(--accent-3)',
                opacity: 0.8,
              }}
              aria-hidden
            />
            {/* Floating Shapes */}
            <div
              className="shape morph floaty-soft soft"
              style={{
                width: 200,
                height: 120,
                left: 50,
                top: 150,
                background: 'var(--accent-1)',
                opacity: 0.7,
              }}
              aria-hidden
            />

            <div
              className="shape morph floaty-slow soft"
              style={{
                width: 140,
                height: 140,
                left: 250,
                top: -40,
                background: 'var(--accent-2)',
                opacity: 0.9,
              }}
              aria-hidden
            />

            <div
              className="shape morph floaty-fast soft"
              style={{
                width: 100,
                height: 180,
                right: 120,
                top: 200,
                background: 'var(--accent-3)',
                opacity: 0.6,
              }}
              aria-hidden
            />

            <div
              className="shape morph floaty soft"
              style={{
                width: 220,
                height: 100,
                left: 180,
                bottom: -60,
                background: 'var(--accent-4)',
                opacity: 0.85,
              }}
              aria-hidden
            />

            <div
              className="shape morph floaty-slow soft"
              style={{
                width: 160,
                height: 160,
                right: -40,
                bottom: 100,
                background: 'var(--accent-5)',
                opacity: 0.75,
              }}
              aria-hidden
            />

            <div
              className="shape morph floaty-fast soft"
              style={{
                width: 120,
                height: 140,
                left: -60,
                top: 300,
                background: 'var(--accent-6)',
                opacity: 0.8,
              }}
              aria-hidden
            />

            <div
              className="shape morph floaty-soft soft"
              style={{
                width: 180,
                height: 120,
                right: 200,
                top: -50,
                background: 'var(--accent-7)',
                opacity: 0.7,
              }}
              aria-hidden
            />

            <div
              className="shape morph floaty slow soft"
              style={{
                width: 140,
                height: 180,
                left: 100,
                bottom: 200,
                background: 'var(--accent-8)',
                opacity: 0.9,
              }}
              aria-hidden
            />

            <div
              className="shape morph floaty-fast soft"
              style={{
                width: 200,
                height: 140,
                right: 50,
                bottom: -40,
                background: 'var(--accent-9)',
                opacity: 0.65,
              }}
              aria-hidden
            />

            <div
              className="shape morph floaty-soft soft"
              style={{
                width: 160,
                height: 160,
                left: 250,
                top: 250,
                background: 'var(--accent-10)',
                opacity: 0.8,
              }}
              aria-hidden
            />

            <h1 className="headline">
              Kuch nhi milega idhar go touch some grass or something
            </h1>
            <p className="subtle">
              A small, whimsical landing page for fun internet jokes.
            </p>

            <div style={{ marginTop: 40 }} className="card-row">
              <div className="post-it" style={{ transform: 'rotate(-3deg)' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                  <div className="icon" aria-hidden>
                    <DoodleGrass />
                  </div>
                  <div>
                    <div style={{ fontWeight: 600 }}>Take a break</div>
                    <div className="subtle" style={{ fontSize: '0.9rem' }}>
                      Go outside, it&apos;s nice.
                    </div>
                  </div>
                </div>
              </div>

              <div
                className="post-it"
                style={{
                  transform: 'rotate(2deg)',
                  alignSelf: 'flex-start',
                  marginTop: '1rem',
                }}
              >
                <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                  <div className="icon" aria-hidden>
                    <DoodleSparkle />
                  </div>
                  <div>
                    <div style={{ fontWeight: 600 }}>Tiny Wins</div>
                    <div className="subtle" style={{ fontSize: '0.9rem' }}>
                      Celebrate the small stuff.
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <aside className="hero-right">
          <div style={{ position: 'relative', width: 320, height: 360 }}>
            <div
              className="glass"
              style={{
                width: 320,
                height: 360,
                borderRadius: 0,
                padding: 20,
                display: 'flex',
                flexDirection: 'column',
                justifyContent: 'space-between',
              }}
            >
              <div>
                <div style={{ display: 'flex', gap: 12, alignItems: 'center' }}>
                  <div className="icon">
                    <DoodleCloud />
                  </div>
                  <div>
                    <div style={{ fontWeight: 700 }}>Quiet Mode</div>
                    <div className="subtle">
                      Soft background noise & calm visuals.
                    </div>
                  </div>
                </div>
              </div>

              <div
                style={{
                  display: 'flex',
                  justifyContent: 'space-between',
                  alignItems: 'center',
                }}
              >
                <div className="badge">Live • Pastel</div>
                <button
                  className="glass"
                  style={{
                    padding: '8px 14px',
                    borderRadius: 0,
                    cursor: 'pointer',
                  }}
                >
                  Explore
                </button>
              </div>
            </div>

            {/* floating nature icons */}
            <div
              style={{ position: 'absolute', right: -20, top: -20 }}
              className="floaty-fast"
              aria-hidden
            >
              <div className="icon">
                <DoodleSparkle />
              </div>
            </div>
            <div
              style={{ position: 'absolute', left: -15, bottom: -15 }}
              className="floaty-slow"
              aria-hidden
            >
              <div className="icon">
                <DoodleGrass />
              </div>
            </div>
          </div>
        </aside>
      </div>
    </div>
  );
}
