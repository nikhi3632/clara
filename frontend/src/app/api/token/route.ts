import { AccessToken, AgentDispatchClient, RoomServiceClient } from 'livekit-server-sdk'
import { NextResponse } from 'next/server'

export async function POST(request: Request) {
  try {
    const { roomName, participantName } = await request.json()

    if (!roomName || !participantName) {
      return NextResponse.json(
        { error: 'roomName and participantName are required' },
        { status: 400 }
      )
    }

    const apiKey = process.env.LIVEKIT_API_KEY
    const apiSecret = process.env.LIVEKIT_API_SECRET
    const livekitUrl = process.env.NEXT_PUBLIC_LIVEKIT_URL

    if (!apiKey || !apiSecret || !livekitUrl) {
      return NextResponse.json(
        { error: 'LiveKit credentials not configured' },
        { status: 500 }
      )
    }

    const httpUrl = livekitUrl.replace('wss://', 'https://')

    // Create room
    const roomService = new RoomServiceClient(httpUrl, apiKey, apiSecret)
    await roomService.createRoom({
      name: roomName,
      emptyTimeout: 300,
    })
    console.log('Room created:', roomName)

    // Dispatch agent to room
    const agentDispatch = new AgentDispatchClient(httpUrl, apiKey, apiSecret)
    await agentDispatch.createDispatch(roomName, 'clara-agent')
    console.log('Agent dispatched to room:', roomName)

    // Generate token
    const token = new AccessToken(apiKey, apiSecret, {
      identity: participantName,
    })

    token.addGrant({
      room: roomName,
      roomJoin: true,
      canPublish: true,
      canSubscribe: true,
    })

    return NextResponse.json({ token: await token.toJwt() })
  } catch (error) {
    console.error('Token generation failed:', error)
    const errorMessage = error instanceof Error ? error.message : 'Unknown error'
    return NextResponse.json(
      { error: 'Failed to generate token', details: errorMessage },
      { status: 500 }
    )
  }
}
