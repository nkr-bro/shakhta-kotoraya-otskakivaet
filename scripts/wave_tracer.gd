class_name WaveTracer
## Shared geometric ray logic for the preview, the energy wave and boss blasts.
## The preview and the real projectile both call resolve() so they obey the
## same collision rules.

const L_TERRAIN := 1
const L_REFLECTOR := 2
const L_TARGET := 4
const L_WORM := 8
const L_SHIELD := 16
const PLAYER_MASK := L_TERRAIN | L_REFLECTOR | L_TARGET | L_WORM
const HOSTILE_MASK := L_TERRAIN | L_REFLECTOR | L_SHIELD
const BOUNDS := Rect2(-60, -260, 1792, 1300)
const SURFACE_OFFSET := 0.75


static func cast(space: PhysicsDirectSpaceState2D, from: Vector2, to: Vector2, mask: int) -> Dictionary:
	var q := PhysicsRayQueryParameters2D.create(from, to, mask)
	q.collide_with_areas = true
	q.collide_with_bodies = true
	q.hit_from_inside = false
	return space.intersect_ray(q)


## Classifies a collider: "reflector", "target", "shield" or "wall".
static func kind_of(collider: Object) -> String:
	if collider is Node:
		var n := collider as Node
		if n.is_in_group("reflector"):
			return "reflector"
		if n.is_in_group("gem"):
			return "gem"
		if n.is_in_group("rock") and Save.equipped == "drill":
			return "gem"
		if n.is_in_group("wave_target"):
			return "target"
		if n.is_in_group("shield"):
			return "shield"
	return "wall"


## Moves a ray of length `dist` from pos along dir, handling every reflection
## inside that distance. Returns {pos, dir, travelled, events:[{kind, point, collider, normal}], stop}
static func step(space: PhysicsDirectSpaceState2D, pos: Vector2, dir: Vector2, dist: float, mask: int, bounces_left: int) -> Dictionary:
	var events := []
	var remaining := dist
	var guard := 0
	while remaining > 0.001 and guard < 16:
		guard += 1
		var hit := cast(space, pos, pos + dir * remaining, mask)
		if hit.is_empty():
			pos += dir * remaining
			remaining = 0.0
			break
		var p: Vector2 = hit.position
		remaining -= pos.distance_to(p)
		var k := kind_of(hit.collider)
		var n: Vector2 = hit.normal
		events.append({"kind": k, "point": p, "collider": hit.collider, "normal": n})
		if k == "gem":
			pos = p + dir * 0.5
			continue
		if k == "reflector" and bounces_left > 0:
			bounces_left -= 1
			dir = dir.bounce(n).normalized()
			pos = p + n * SURFACE_OFFSET
			continue
		return {"pos": p, "dir": dir, "events": events, "stop": true}
	return {"pos": pos, "dir": dir, "events": events, "stop": false}


## Full path for previews and solvers. tail_len limits the segment drawn after
## the last allowed reflection. Returns {points, kind, collider, bounces}.
static func trace(space: PhysicsDirectSpaceState2D, origin: Vector2, dir: Vector2, max_bounces: int, mask: int, tail_len := 2400.0, max_len := 4000.0) -> Dictionary:
	var pts := PackedVector2Array([origin])
	var pos := origin
	var d := dir.normalized()
	var bounces := 0
	var travelled := 0.0
	var gems := []
	while travelled < max_len:
		var reach := minf(max_len - travelled, 3000.0)
		if bounces >= max_bounces:
			reach = minf(reach, tail_len)
		var hit := cast(space, pos, pos + d * reach, mask)
		if hit.is_empty():
			pos += d * reach
			pts.append(pos)
			return {"points": pts, "kind": "tail" if bounces >= max_bounces and reach < 3000.0 else "out", "collider": null, "bounces": bounces, "gems": gems}
		var p: Vector2 = hit.position
		travelled += pos.distance_to(p)
		pts.append(p)
		var k := kind_of(hit.collider)
		if k == "gem":
			gems.append(hit.collider)
			pts.remove_at(pts.size() - 1)
			pos = p + d * 0.5
			continue
		if k == "reflector" and bounces < max_bounces:
			bounces += 1
			d = d.bounce(hit.normal).normalized()
			pos = p + hit.normal * SURFACE_OFFSET
			continue
		return {"points": pts, "kind": k, "collider": hit.collider, "bounces": bounces, "gems": gems}
	return {"points": pts, "kind": "limit", "collider": null, "bounces": bounces, "gems": gems}
