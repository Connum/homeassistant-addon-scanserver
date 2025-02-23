from homeassistant.helpers.entity import Entity

async def async_setup_platform(hass, config, async_add_entities, discovery_info=None):
    """Set up the scanner sensor."""
    devices = hass.data.get("scanners", [])

    sensors = [ScannerSensor(device) for device in devices]
    async_add_entities(sensors, True)

class ScannerSensor(Entity):
    def __init__(self, device):
        self._name = device["product"]
        self._vendor = device["vendor"]
        self._address = device["address"]
        self._state = "online"

    @property
    def name(self):
        return self._name

    @property
    def state(self):
        return self._state
