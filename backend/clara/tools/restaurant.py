"""Foursquare restaurant search tools."""

import os

import httpx
from tenacity import retry, stop_after_attempt, wait_exponential

from clara.logging import get_logger

logger = get_logger(__name__)

FOURSQUARE_BASE_URL = "https://places-api.foursquare.com"
FOURSQUARE_VERSION = "2025-06-17"


def _get_headers() -> dict[str, str]:
    """Get Foursquare API headers."""
    return {
        "Authorization": f"Bearer {os.getenv('FOURSQUARE_API_KEY')}",
        "Accept": "application/json",
        "X-Places-Api-Version": FOURSQUARE_VERSION,
    }


@retry(
    stop=stop_after_attempt(3),
    wait=wait_exponential(multiplier=1, min=1, max=10),
)
async def search_restaurants(
    location: str,
    cuisine: str = "",
    limit: int = 3,
) -> str:
    """
    Search for restaurants near a location.

    Args:
        location: Location to search (e.g., "downtown austin" or "40.7128,-74.006")
        cuisine: Optional cuisine type (e.g., "italian", "mexican")
        limit: Maximum number of results (default 3)

    Returns:
        Formatted string with restaurant results
    """
    logger.info("search_restaurants", location=location, cuisine=cuisine, limit=limit)

    query = f"{cuisine} restaurant" if cuisine else "restaurant"

    params = {
        "query": query,
        "near": location,
        "limit": limit,
        "categories": "13065",  # Restaurant category
    }

    async with httpx.AsyncClient(timeout=5.0) as client:
        response = await client.get(
            f"{FOURSQUARE_BASE_URL}/places/search",
            headers=_get_headers(),
            params=params,
        )

        if response.status_code == 429:
            retry_after = int(response.headers.get("Retry-After", 1))
            logger.warning("rate_limited", service="foursquare", retry_after=retry_after)
            raise httpx.HTTPStatusError("Rate limited", request=response.request, response=response)

        response.raise_for_status()
        data = response.json()

    results = data.get("results", [])

    if not results:
        return "I couldn't find any restaurants in that area. Could you try a different location?"

    formatted = []
    for place in results:
        name = place.get("name", "Unknown")
        fsq_id = place.get("fsq_place_id", "")  # API returns fsq_place_id, not fsq_id
        formatted.append(f"- {name} [ID: {fsq_id}]")

    logger.info("search_restaurants_success", count=len(results))
    return (
        f"Found {len(results)} restaurants. To get details, call get_restaurant_details with the ID value:\n"
        + "\n".join(formatted)
    )


async def get_restaurant_details(fsq_place_id: str) -> str:
    """
    Get details about a specific restaurant.

    Args:
        fsq_place_id: Foursquare place ID

    Returns:
        Formatted string with restaurant details
    """
    logger.info("get_restaurant_details", fsq_place_id=fsq_place_id)

    async with httpx.AsyncClient(timeout=5.0) as client:
        response = await client.get(
            f"{FOURSQUARE_BASE_URL}/places/{fsq_place_id}",
            headers=_get_headers(),
            params={"fields": "name,tel,location,hours,website,rating"},
        )

        if response.status_code == 429:
            logger.warning("rate_limited", service="foursquare")
            return "I'm getting too many requests right now. Please wait a moment and try again."

        if response.status_code == 404:
            return "I couldn't find that restaurant. It may no longer exist."

        response.raise_for_status()
        place = response.json()

    name = place.get("name", "Unknown")
    phone = place.get("tel", "")
    location = place.get("location", {})
    address = location.get("formatted_address", "Address not available")
    hours = place.get("hours", {})
    hours_display = hours.get("display", "Hours not available")
    rating = place.get("rating")

    details = [f"{name}"]
    details.append(f"Address: {address}")

    if phone:
        details.append(f"Phone: {phone}")

    details.append(f"Hours: {hours_display}")

    if rating:
        details.append(f"Rating: {rating}/10")

    logger.info("get_restaurant_details_success", fsq_place_id=fsq_place_id, has_phone=bool(phone))
    return "\n".join(details)
