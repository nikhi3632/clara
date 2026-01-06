'use client'

import { useEffect, useRef } from 'react'

interface TranscriptEntry {
  id: string
  speaker: 'user' | 'agent'
  text: string
  timestamp: Date
}

interface TranscriptProps {
  entries: TranscriptEntry[]
}

export function Transcript({ entries }: TranscriptProps) {
  const containerRef = useRef<HTMLDivElement>(null)

  // Auto-scroll to bottom on new entries
  useEffect(() => {
    if (containerRef.current) {
      containerRef.current.scrollTop = containerRef.current.scrollHeight
    }
  }, [entries])

  if (entries.length === 0) {
    return (
      <div className="w-full h-48 rounded-lg bg-gray-50 border border-gray-200 flex items-center justify-center">
        <p className="text-gray-400 text-sm">Conversation will appear here...</p>
      </div>
    )
  }

  return (
    <div
      ref={containerRef}
      className="w-full h-48 rounded-lg bg-gray-50 border border-gray-200 overflow-y-auto p-4 space-y-3"
    >
      {entries.map((entry) => (
        <div
          key={entry.id}
          className={`flex flex-col ${
            entry.speaker === 'user' ? 'items-end' : 'items-start'
          }`}
        >
          <span className="text-xs text-gray-500 mb-1">
            {entry.speaker === 'user' ? 'You' : 'Clara'}
          </span>
          <div
            className={`max-w-[80%] rounded-lg px-3 py-2 text-sm ${
              entry.speaker === 'user'
                ? 'bg-blue-500 text-white'
                : 'bg-gray-200 text-gray-900'
            }`}
          >
            {entry.text}
          </div>
        </div>
      ))}
    </div>
  )
}
