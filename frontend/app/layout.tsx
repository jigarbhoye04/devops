import type { Metadata } from 'next';
import { Klee_One, Inter_Tight } from 'next/font/google';
import './globals.css';

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
    <html lang="en" suppressHydrationWarning>
      <body className={`${klee.variable} ${inter.variable} antialiased`}>
        {children}
      </body>
    </html>
  );
}
