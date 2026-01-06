'use client'

import { useCallback, useState, useEffect } from 'react'
import {
  LiveKitRoom,
  RoomAudioRenderer,
  useVoiceAssistant,
  useTranscriptions,
  BarVisualizer,
} from '@livekit/components-react'
import '@livekit/components-styles'

import { Controls } from '@/components/Controls'
import { Transcript } from '@/components/Transcript'
import { Orb } from '@/components/Orb'

type ConnectionState = 'disconnected' | 'connecting' | 'connected'

interface TranscriptEntry {
  id: string
  speaker: 'user' | 'agent'
  text: string
  timestamp: Date
}

export default function Home() {
  const [connectionState, setConnectionState] = useState<ConnectionState>('disconnected')
  const [token, setToken] = useState<string>('')
  const [transcript, setTranscript] = useState<TranscriptEntry[]>([])
  const [isMuted, setIsMuted] = useState(false)

  const handleConnect = useCallback(async () => {
    setConnectionState('connecting')

    try {
      const roomName = `clara-${Date.now()}`
      const participantName = `user-${Math.random().toString(36).substring(7)}`

      const response = await fetch('/api/token', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ roomName, participantName }),
      })

      if (!response.ok) {
        throw new Error('Failed to get token')
      }

      const { token } = await response.json()
      setToken(token)
      setConnectionState('connected')
    } catch (error) {
      console.error('Connection failed:', error)
      setConnectionState('disconnected')
    }
  }, [])

  const handleDisconnect = useCallback(() => {
    setToken('')
    setConnectionState('disconnected')
    setTranscript([])
  }, [])

  const handleClear = useCallback(() => {
    setTranscript([])
  }, [])

  const handleMuteToggle = useCallback(() => {
    setIsMuted((prev) => !prev)
  }, [])

  const updateTranscript = useCallback((id: string, speaker: 'user' | 'agent', text: string) => {
    setTranscript((prev) => {
      const existingIndex = prev.findIndex((entry) => entry.id === id)
      if (existingIndex >= 0) {
        // Update existing entry
        const updated = [...prev]
        updated[existingIndex] = { ...updated[existingIndex], text }
        return updated
      } else {
        // Add new entry
        return [...prev, { id, speaker, text, timestamp: new Date() }]
      }
    })
  }, [])

  return (
    <main className="flex min-h-screen flex-col items-center justify-between p-8">
      <div className="w-full max-w-2xl flex flex-col items-center gap-8">
        <h1 className="text-2xl font-semibold text-gray-900">Clara</h1>

        {connectionState === 'connected' && token ? (
          <LiveKitRoom
            token={token}
            serverUrl={process.env.NEXT_PUBLIC_LIVEKIT_URL}
            connect={true}
            audio={true}
            video={false}
            onDisconnected={handleDisconnect}
          >
            <RoomContent
              isMuted={isMuted}
              onUpdateTranscript={updateTranscript}
            />
            <RoomAudioRenderer />
          </LiveKitRoom>
        ) : (
          <Orb state={connectionState === 'connecting' ? 'connecting' : 'idle'} />
        )}

        <Transcript entries={transcript} />

        <Controls
          connectionState={connectionState}
          isMuted={isMuted}
          onConnect={handleConnect}
          onDisconnect={handleDisconnect}
          onMuteToggle={handleMuteToggle}
          onClear={handleClear}
        />
      </div>
    </main>
  )
}

function RoomContent({
  isMuted,
  onUpdateTranscript,
}: {
  isMuted: boolean
  onUpdateTranscript: (id: string, speaker: 'user' | 'agent', text: string) => void
}) {
  const { state, audioTrack, agent } = useVoiceAssistant()
  const transcriptions = useTranscriptions()

  // Track all transcriptions using stream ID
  useEffect(() => {
    transcriptions.forEach((t) => {
      if (t.text.trim()) {
        const streamId = t.streamInfo.id
        const isAgent = agent && t.participantInfo.identity === agent.identity
        onUpdateTranscript(streamId, isAgent ? 'agent' : 'user', t.text)
      }
    })
  }, [transcriptions, agent, onUpdateTranscript])

  // Map voice assistant state to orb state
  const orbState = (() => {
    switch (state) {
      case 'listening':
        return 'listening'
      case 'thinking':
        return 'thinking'
      case 'speaking':
        return 'speaking'
      default:
        return 'connected'
    }
  })()

  return (
    <div className="flex flex-col items-center gap-4">
      <Orb state={orbState} />
      {audioTrack && (
        <BarVisualizer
          state={state}
          barCount={5}
          trackRef={audioTrack}
          className="h-8"
        />
      )}
    </div>
  )
}
