import type { ReactNode } from "react";
import "./globals.css";

export const metadata = {
  title: "Helios Advertiser Dashboard",
  description: "Monitor campaign performance in real-time.",
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
