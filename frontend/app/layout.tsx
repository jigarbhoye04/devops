import type { Metadata } from 'next';
import { Klee_One, Inter_Tight } from 'next/font/google';
import './globals.css';
import { Navbar5 } from '@/components/Navbar';
import ErrorReporter from '@/components/ErrorReporter';
import Script from 'next/script';

// Playful headline font (Klee One) + Inter for UI
const klee = Klee_One({
  variable: '--font-klee',
  weight: ['400'],
  subsets: ['latin'],
});

const inter = Inter_Tight({
  variable: '--font-inter',
  subsets: ['latin'],
});

export const metadata: Metadata = {
  title: 'Kuch Nhi - Landing',
  description: 'A whimsical glassmorphism landing page',
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className="dark">
      <body
        className={`${klee.variable} ${inter.variable} bg-[url('https://cdn.sanity.io/images/71u2kr0t/production/d448e7e6ea7a741311d190aa16731d16b78ae736-6048x4024.jpg?w=3840&h=2555&q=70&auto=format')] bg-cover bg-center bg-fixed min-h-screen antialiased`}
      >
        <ErrorReporter />
        <Navbar5 />
        {children}
      </body>
    </html>
  );
}
