"""Clara voice agent."""

from livekit.agents import Agent, AgentSession, JobContext, RunContext, function_tool
from livekit.plugins import cartesia, deepgram, openai, silero

from clara.logging import get_logger
from clara.tools.call import call_transfer, end_call
from clara.tools.restaurant import get_restaurant_details, search_restaurants

logger = get_logger(__name__)

# Preload VAD model once at module load (reduces per-session latency by ~500ms)
_vad = silero.VAD.load()


class ClaraAgent(Agent):
    """Voice-powered restaurant concierge agent."""

    def __init__(self) -> None:
        super().__init__(
            instructions="""You are Clara, a helpful restaurant concierge.
You help users find restaurants using real-time data.
Ask for their location and cuisine preferences.
Provide concise information about restaurants you find.

IMPORTANT: When using get_restaurant_details, you MUST pass the fsq_id value (like "4b5e662af964a52060c928e3") from the search results, NOT the restaurant name.

When users want to call a restaurant, use the call_transfer tool.
Keep responses brief and conversational - this is voice, not text.
Never use formatting like bullet points or numbered lists in your speech.
Speak naturally as if having a phone conversation.""",
        )

    @function_tool
    async def search_restaurants(
        self,
        _ctx: RunContext,
        location: str,
        cuisine: str = "",
        limit: int = 3,
    ) -> str:
        """
        Search for restaurants near a location.

        Args:
            location: The area to search (e.g., "downtown austin", "near times square")
            cuisine: Optional cuisine type (e.g., "italian", "mexican", "sushi")
            limit: Maximum number of results to return
        """
        logger.info(
            "tool_start",
            tool="search_restaurants",
            location=location,
            cuisine=cuisine,
        )
        result = await search_restaurants(location, cuisine, limit)
        logger.info("tool_end", tool="search_restaurants", success=True)
        return result

    @function_tool
    async def get_restaurant_details(
        self,
        _ctx: RunContext,
        fsq_place_id: str,
    ) -> str:
        """
        Get details about a specific restaurant including phone number, address, and hours.

        Args:
            fsq_place_id: The Foursquare place ID from search results. Must be an alphanumeric ID. NEVER pass a restaurant name - only use the fsq_id value from search_restaurants output.
        """
        # Validate that this looks like a Foursquare ID, not a restaurant name
        if " " in fsq_place_id or len(fsq_place_id) > 30:
            return f"Error: '{fsq_place_id}' is not a valid Foursquare place ID. Please use the fsq_id from the search results (e.g. '4b5e662af964a52060c928e3'), not the restaurant name."
        logger.info("tool_start", tool="get_restaurant_details", fsq_place_id=fsq_place_id)
        result = await get_restaurant_details(fsq_place_id)
        logger.info("tool_end", tool="get_restaurant_details", success=True)
        return result

    @function_tool
    async def call_transfer(
        self,
        ctx: RunContext,
        phone_number: str,
    ) -> str:
        """
        Transfer the call to connect the user with a restaurant.

        Args:
            phone_number: The restaurant's phone number in format +1XXXXXXXXXX
        """
        room_name = ctx.session.room_io.room.name
        logger.info("tool_start", tool="call_transfer", phone_number=phone_number)
        result = await call_transfer(room_name, phone_number)
        logger.info("tool_end", tool="call_transfer", success="Connected" in result)
        return result

    @function_tool
    async def end_call(self, ctx: RunContext) -> str:
        """End the current call when the user wants to hang up."""
        room_name = ctx.session.room_io.room.name
        logger.info("tool_start", tool="end_call")
        result = await end_call(room_name)
        logger.info("tool_end", tool="end_call", success=True)
        return result


async def create_session(ctx: JobContext) -> None:
    """Create and start an agent session."""
    try:
        logger.info(
            "session_start",
            room_name=ctx.room.name,
            source="sip" if ctx.room.name.startswith("call-") else "web",
        )

        logger.info("creating_session_components")
        session = AgentSession(
            stt=deepgram.STT(model="nova-3"),
            llm=openai.LLM(model="gpt-4o-mini"),  # Faster than gpt-4o, lower latency
            tts=cartesia.TTS(model="sonic-2-2025-03-07"),
            vad=_vad,  # Use preloaded VAD
        )

        logger.info("starting_session")
        await session.start(room=ctx.room, agent=ClaraAgent())
        logger.info("session_started")

        # Greet the user (keep it short for faster TTS)
        logger.info("generating_greeting")
        await session.generate_reply(
            instructions="Say a brief greeting like 'Hi, I'm Clara. How can I help you find a restaurant today?'"
        )
        logger.info("greeting_sent")
    except Exception as e:
        logger.error("session_error", error=str(e), error_type=type(e).__name__)
