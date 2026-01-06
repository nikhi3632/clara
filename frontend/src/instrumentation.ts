export async function register() {
  if (process.env.NEXT_RUNTIME === 'nodejs') {
    const handleShutdown = (signal: string) => {
      console.log(`\n[Clara] Received ${signal}, shutting down gracefully...`)
      process.exit(0)
    }

    process.on('SIGINT', () => handleShutdown('SIGINT'))
    process.on('SIGTERM', () => handleShutdown('SIGTERM'))

    console.log('[Clara] Frontend server started')
  }
}
