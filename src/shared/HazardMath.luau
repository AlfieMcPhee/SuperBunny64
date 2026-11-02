--[[
	HazardMath - deterministic motion for firebars and crushers.
	Server and clients evaluate the same functions with the shared server
	clock, so clients can animate hazards smoothly while the server decides
	who gets hurt.
]]

local HazardMath = {}

function HazardMath.Now()
	return workspace:GetServerTimeNow()
end

-- Firebar: rotates about a vertical axis through `pivot`
function HazardMath.FirebarAngle(speed, phase, t)
	return phase + speed * t
end

-- Direction of the bar's arm for a given angle (matches CFrame.Angles(0, a, 0) * +X)
function HazardMath.FirebarDir(angle)
	return Vector3.new(math.cos(angle), 0, -math.sin(angle))
end

-- Crusher: returns how far (0 = resting high, 1 = slammed down) it is
--   [0, hold)               waiting high
--   [hold, hold+0.18)       slamming down
--   [hold+0.18, hold+1.0)   resting low
--   [hold+1.0, period)      rising back up
function HazardMath.CrusherDrop(period, offset, t)
	local hold = period - 1.8
	local u = (t + offset) % period
	if u < hold then
		return 0
	elseif u < hold + 0.18 then
		return (u - hold) / 0.18
	elseif u < hold + 1.0 then
		return 1
	else
		return 1 - (u - hold - 1.0) / 0.8
	end
end

-- Distance from point p to segment a-b
function HazardMath.SegmentDistance(p, a, b)
	local ab = b - a
	local len2 = ab:Dot(ab)
	if len2 < 1e-6 then
		return (p - a).Magnitude
	end
	local t = math.clamp((p - a):Dot(ab) / len2, 0, 1)
	return (p - (a + ab * t)).Magnitude
end

return HazardMath
