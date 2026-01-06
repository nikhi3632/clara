"""Call transfer and management tools."""

import os

from livekit import api

from clara.logging import get_logger

logger = get_logger(__name__)


async def call_transfer(room_name: str, phone_number: str) -> str:
    """
    Transfer the call to a restaurant.

    Args:
        room_name: LiveKit room name
        phone_number: Phone number to call (format: +1XXXXXXXXXX)

    Returns:
        Status message
    """
    redirect_enabled = os.getenv("CALL_REDIRECT_ENABLED", "false").lower() == "true"
    redirect_number = os.getenv("CALL_REDIRECT_NUMBER", "")

    actual_number = redirect_number if redirect_enabled and redirect_number else phone_number

    logger.info(
        "call_transfer",
        intent_phone=phone_number,
        actual_phone=actual_number,
        redirected=redirect_enabled and redirect_number != "",
    )

    try:
        lk_api = api.LiveKitAPI()
        await lk_api.sip.create_sip_participant(
            api.CreateSIPParticipantRequest(
                room_name=room_name,
                sip_trunk_id=os.getenv("LIVEKIT_OUTBOUND_TRUNK_ID", ""),
                sip_call_to=actual_number,
                participant_identity="restaurant",
                wait_until_answered=True,
            )
        )
        await lk_api.aclose()

        logger.info("call_transfer_success", phone=actual_number)
        return f"Connected to {phone_number}"

    except Exception as e:
        logger.error("call_transfer_failed", error=str(e), phone=actual_number)
        return f"Sorry, I couldn't connect the call. The restaurant's number is {phone_number}"


async def end_call(room_name: str) -> str:
    """
    End the current call.

    Args:
        room_name: LiveKit room name

    Returns:
        Status message
    """
    logger.info("end_call", room_name=room_name)

    try:
        lk_api = api.LiveKitAPI()
        await lk_api.room.delete_room(api.DeleteRoomRequest(room=room_name))
        await lk_api.aclose()

        logger.info("end_call_success", room_name=room_name)
        return "Call ended"

    except Exception as e:
        logger.error("end_call_failed", error=str(e), room_name=room_name)
        return "Call ended"
