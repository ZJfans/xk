class_name FrontierContracts
extends RefCounted
## Stable UX->Domain command IDs and responsible feature owners.
## When real domain services arrive, change the adapter, NOT every button.
const ACTION_OWNERS := {
	"win_lot": "auction",
	"scan": "expedition",
	"deploy": "expedition",
	"dispatch": "fleet",
	"sell": "market",
	"change_craft": "assembly",
	"mount_part": "assembly",
	"reset_round": "progression"
}
const NAV_IDS := ["hq", "auction", "expedition", "assembly", "market", "settlement"]

static func is_known_action(action_id: String) -> bool:
	return ACTION_OWNERS.has(action_id)

static func owner_for(action_id: String) -> String:
	return str(ACTION_OWNERS.get(action_id, "unknown"))
