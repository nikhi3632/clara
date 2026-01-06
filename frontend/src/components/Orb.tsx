'use client'

import { useRef, useMemo } from 'react'
import { Canvas, useFrame } from '@react-three/fiber'
import { Sphere, MeshDistortMaterial } from '@react-three/drei'
import * as THREE from 'three'

type OrbState = 'idle' | 'connecting' | 'connected' | 'listening' | 'thinking' | 'speaking'

interface OrbProps {
  state: OrbState
}

function AnimatedSphere({ state }: { state: OrbState }) {
  const meshRef = useRef<THREE.Mesh>(null)

  const config = useMemo(() => {
    switch (state) {
      case 'idle':
        return { color: '#4b5563', distort: 0.2, speed: 1 }
      case 'connecting':
        return { color: '#3b82f6', distort: 0.3, speed: 3 }
      case 'connected':
        return { color: '#3b82f6', distort: 0.2, speed: 1.5 }
      case 'listening':
        return { color: '#10b981', distort: 0.25, speed: 2 }
      case 'thinking':
        return { color: '#8b5cf6', distort: 0.35, speed: 2.5 }
      case 'speaking':
        return { color: '#3b82f6', distort: 0.5, speed: 4 }
      default:
        return { color: '#4b5563', distort: 0.2, speed: 1 }
    }
  }, [state])

  useFrame((_, delta) => {
    if (meshRef.current) {
      meshRef.current.rotation.x += delta * 0.2
      meshRef.current.rotation.y += delta * 0.3
    }
  })

  return (
    <Sphere ref={meshRef} args={[1, 64, 64]}>
      <MeshDistortMaterial
        color={config.color}
        attach="material"
        distort={config.distort}
        speed={config.speed}
        roughness={0.4}
        metalness={0.8}
      />
    </Sphere>
  )
}

export function Orb({ state }: OrbProps) {
  return (
    <div className="w-48 h-48">
      <Canvas camera={{ position: [0, 0, 3] }}>
        <ambientLight intensity={0.5} />
        <directionalLight position={[10, 10, 5]} intensity={1} />
        <pointLight position={[-10, -10, -5]} intensity={0.5} />
        <AnimatedSphere state={state} />
      </Canvas>
    </div>
  )
}
