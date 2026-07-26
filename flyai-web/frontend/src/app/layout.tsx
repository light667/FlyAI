import type { Metadata } from "next";
import { Inter, Instrument_Serif } from "next/font/google";
import "./globals.css";

const inter = Inter({
  subsets: ["latin"],
  variable: "--font-sans",
});

// Instrument Serif n'existe qu'en weight 400 (normal + italique) sur Google Fonts.
const instrumentSerif = Instrument_Serif({
  weight: "400",
  style: ["normal", "italic"],
  subsets: ["latin"],
  variable: "--font-instrument-serif",
  display: "swap",
});

export const metadata: Metadata = {
  title: "FlyAI — Plateforme Globale de Bourses & Matching IA",
  description: "Découvre et postule aux meilleures bourses internationales avec l'aide de FlyAgent et du matching intelligent.",
  icons: {
    icon: "/logo.png",
    apple: "/logo.png",
    shortcut: "/logo.png",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="fr" className={`${inter.variable} ${instrumentSerif.variable} h-full antialiased`}>
      <body className="min-h-full flex flex-col bg-[rgb(var(--background)] text-[rgb(var(--foreground))] font-sans selection:bg-indigo-500 selection:text-white transition-colors duration-200">
        {children}
      </body>
    </html>
  );
}
