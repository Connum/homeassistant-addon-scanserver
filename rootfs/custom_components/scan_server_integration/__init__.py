from homeassistant.config_entries import ConfigEntry
from homeassistant.core import HomeAssistant

DOMAIN = "scanner"

async def async_setup(hass: HomeAssistant, config: dict):
    """Set up the scanner integration from configuration.yaml."""
    return True

async def async_setup_entry(hass: HomeAssistant, entry: ConfigEntry):
    """Set up the scanner integration from a config entry."""
    hass.data.setdefault(DOMAIN, {})
    return True
