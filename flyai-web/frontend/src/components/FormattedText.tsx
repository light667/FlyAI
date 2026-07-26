"use client";

import React from "react";

interface Props {
  content: string;
  className?: string;
}

export default function FormattedText({ content, className = "" }: Props) {
  if (!content) return null;

  // Simple clean parser converting markdown formatting into rich React elements
  const lines = content.split("\n");

  return (
    <div className={`space-y-2.5 leading-relaxed text-sm ${className}`}>
      {lines.map((line, idx) => {
        const trimmed = line.trim();

        if (!trimmed) {
          return <div key={idx} className="h-1.5" />;
        }

        // Headings
        if (trimmed.startsWith("### ")) {
          return (
            <h4 key={idx} className="font-extrabold text-base text-slate-900 dark:text-white mt-3 mb-1">
              {formatInline(trimmed.replace("### ", ""))}
            </h4>
          );
        }
        if (trimmed.startsWith("## ")) {
          return (
            <h3 key={idx} className="font-black text-lg text-indigo-600 dark:text-indigo-400 mt-4 mb-2">
              {formatInline(trimmed.replace("## ", ""))}
            </h3>
          );
        }

        // Bullet lists
        if (trimmed.startsWith("- ") || trimmed.startsWith("* ")) {
          const listText = trimmed.substring(2);
          return (
            <div key={idx} className="flex items-start gap-2 pl-2">
              <span className="w-1.5 h-1.5 rounded-full bg-indigo-500 mt-2 shrink-0" />
              <span>{formatInline(listText)}</span>
            </div>
          );
        }

        // Numbered lists
        const numMatch = trimmed.match(/^(\d+)\.\s+(.*)/);
        if (numMatch) {
          return (
            <div key={idx} className="flex items-start gap-2 pl-2">
              <span className="font-bold text-indigo-600 dark:text-indigo-400 shrink-0">{numMatch[1]}.</span>
              <span>{formatInline(numMatch[2])}</span>
            </div>
          );
        }

        return <p key={idx}>{formatInline(trimmed)}</p>;
      })}
    </div>
  );
}

function formatInline(text: string): React.ReactNode {
  // Bold formatting **text**
  const parts = text.split(/(\*\*.*?\*\*)/g);
  return parts.map((part, i) => {
    if (part.startsWith("**") && part.endsWith("**")) {
      return (
        <strong key={i} className="font-extrabold text-slate-900 dark:text-white">
          {part.slice(2, -2)}
        </strong>
      );
    }
    return part;
  });
}
