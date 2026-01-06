'use client'

type ConnectionState = 'disconnected' | 'connecting' | 'connected'

interface ControlsProps {
  connectionState: ConnectionState
  isMuted: boolean
  onConnect: () => void
  onDisconnect: () => void
  onMuteToggle: () => void
  onClear: () => void
}

export function Controls({
  connectionState,
  isMuted,
  onConnect,
  onDisconnect,
  onMuteToggle,
  onClear,
}: ControlsProps) {
  const isConnected = connectionState === 'connected'
  const isConnecting = connectionState === 'connecting'

  return (
    <div className="flex gap-4">
      {/* Mute Button */}
      <button
        onClick={onMuteToggle}
        disabled={!isConnected}
        className={`flex flex-col items-center gap-1 px-6 py-3 rounded-lg transition-all ${
          !isConnected
            ? 'bg-gray-100 text-gray-300 cursor-not-allowed'
            : isMuted
            ? 'bg-red-100 text-red-600 hover:bg-red-200'
            : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
        }`}
      >
        <span className="text-xl">{isMuted ? '🔇' : '🎤'}</span>
        <span className="text-xs">{isMuted ? 'Unmute' : 'Mute'}</span>
      </button>

      {/* Call Button */}
      <button
        onClick={isConnected ? onDisconnect : onConnect}
        disabled={isConnecting}
        className={`flex flex-col items-center gap-1 px-6 py-3 rounded-lg transition-all ${
          isConnecting
            ? 'bg-yellow-100 text-yellow-600 cursor-wait'
            : isConnected
            ? 'bg-red-100 text-red-600 hover:bg-red-200'
            : 'bg-green-100 text-green-600 hover:bg-green-200'
        }`}
      >
        <span className="text-xl">📞</span>
        <span className="text-xs">
          {isConnecting ? 'Connecting...' : isConnected ? 'End' : 'Call'}
        </span>
      </button>

      {/* Clear Button */}
      <button
        onClick={onClear}
        className="flex flex-col items-center gap-1 px-6 py-3 rounded-lg bg-gray-100 text-gray-700 hover:bg-gray-200 transition-all"
      >
        <span className="text-xl">🗑️</span>
        <span className="text-xs">Clear</span>
      </button>
    </div>
  )
}
