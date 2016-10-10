--[[
Title: Collision 
Author(s): leio
Date: 2016/10/10
Desc: 
use the lib:
------------------------------------------------------------
NPL.load("(gl)Mod/ModelVoxelizer/bmax/Collision.lua");
local Collision = commonlib.gettable("Mod.ModelVoxelizer.bmax.Collision");
Collision.isIntersectionTriangleAABB (a, b, c, aabb); 
------------------------------------------------------------
]]

NPL.load("(gl)script/ide/math/ShapeAABB.lua");
NPL.load("(gl)Mod/NplCadLibrary/csg/CSGVector.lua");
NPL.load("(gl)Mod/NplCadLibrary/csg/CSGPlane.lua");
local ShapeAABB = commonlib.gettable("mathlib.ShapeAABB");
local CSGVector = commonlib.gettable("Mod.NplCadLibrary.csg.CSGVector");
local CSGPlane = commonlib.gettable("Mod.NplCadLibrary.csg.CSGPlane");
local Collision = commonlib.gettable("Mod.ModelVoxelizer.bmax.Collision");

-- based on http:--www.gamedev.net/topic/534655-aabb-triangleplane-intersection--distance-to-plane-is-incorrect-i-have-solved-it/
--			https:--gist.github.com/yomotsu/d845f21e2e1eb49f647f
-- a: <CSGVector>, -- vertex of a triangle
-- b: <CSGVector>, -- vertex of a triangle
-- c: <CSGVector>, -- vertex of a triangle
-- aabb: <ShapeAABB>
function Collision.isIntersectionTriangleAABB (a, b, c, aabb) 
	local p0, p1, p2, r;
  
	-- Compute box center and extents of AABoundingBox (if not already given in that format)
	local center = CSGVector:new():init(aabb.mCenter[1],aabb.mCenter[2],aabb.mCenter[3]);
	local extents = CSGVector:new():init(aabb.mExtents[1],aabb.mExtents[2],aabb.mExtents[3]);

	-- Translate triangle as conceptually moving AABB to origin
	local v0 = a:minus(center);
    local v1 = b:minus(center);
    local v2 = c:minus(center);

	-- Compute edge vectors for triangle
	local f0 = v1:minus(v0);
    local f1 = v2:minus(v1);
    local f2 = v0:minus(v2);

	-- Test axes a00..a22 (category 3)
	local a00 = CSGVector:new():init( 0, -f0.z, f0.y );
    local a01 = CSGVector:new():init( 0, -f1.z, f1.y );
    local a02 = CSGVector:new():init( 0, -f2.z, f2.y );
    local a10 = CSGVector:new():init( f0.z, 0, -f0.x );
    local a11 = CSGVector:new():init( f1.z, 0, -f1.x );
    local a12 = CSGVector:new():init( f2.z, 0, -f2.x );
    local a20 = CSGVector:new():init( -f0.y, f0.x, 0 );
    local a21 = CSGVector:new():init( -f1.y, f1.x, 0 );
    local a22 = CSGVector:new():init( -f2.y, f2.x, 0 );

	-- Test axis a00
	p0 = v0:dot( a00 );
	p1 = v1:dot( a00 );
	p2 = v2:dot( a00 );
	r = extents.y * math.abs( f0.z ) + extents.z * math.abs( f0.y );

	if ( math.max( -math.max( p0, p1, p2 ), math.min( p0, p1, p2 ) ) > r )then
		return false; -- Axis is a separating axis
	end
	-- Test axis a01
	  p0 = v0:dot( a01 );
	  p1 = v1:dot( a01 );
	  p2 = v2:dot( a01 );
	  r = extents.y * math.abs( f1.z ) + extents.z * math.abs( f1.y );

	  if ( math.max( -math.max( p0, p1, p2 ), math.min( p0, p1, p2 ) ) > r ) then
		return false; -- Axis is a separating axis
	  end

	  -- Test axis a02
	  p0 = v0:dot( a02 );
	  p1 = v1:dot( a02 );
	  p2 = v2:dot( a02 );
	  r = extents.y * math.abs( f2.z ) + extents.z * math.abs( f2.y );

	  if ( math.max( -math.max( p0, p1, p2 ), math.min( p0, p1, p2 ) ) > r ) then
		return false; -- Axis is a separating axis
	  end

	  -- Test axis a10
	  p0 = v0:dot( a10 );
	  p1 = v1:dot( a10 );
	  p2 = v2:dot( a10 );
	  r = extents.x * math.abs( f0.z ) + extents.z * math.abs( f0.x );
	  if ( math.max( -math.max( p0, p1, p2 ), math.min( p0, p1, p2 ) ) > r ) then
		return false; -- Axis is a separating axis
	  end

	  -- Test axis a11
	  p0 = v0:dot( a11 );
	  p1 = v1:dot( a11 );
	  p2 = v2:dot( a11 );
	  r = extents.x * math.abs( f1.z ) + extents.z * math.abs( f1.x );

	  if ( math.max( -math.max( p0, p1, p2 ), math.min( p0, p1, p2 ) ) > r ) then
		return false; -- Axis is a separating axis
	  end

	  -- Test axis a12
	  p0 = v0:dot( a12 );
	  p1 = v1:dot( a12 );
	  p2 = v2:dot( a12 );
	  r = extents.x * math.abs( f2.z ) + extents.z * math.abs( f2.x );

	  if ( math.max( -math.max( p0, p1, p2 ), math.min( p0, p1, p2 ) ) > r ) then
		return false; -- Axis is a separating axis
	  end

	  -- Test axis a20
	  p0 = v0:dot( a20 );
	  p1 = v1:dot( a20 );
	  p2 = v2:dot( a20 );
	  r = extents.x * math.abs( f0.y ) + extents.y * math.abs( f0.x );

	  if ( math.max( -math.max( p0, p1, p2 ), math.min( p0, p1, p2 ) ) > r ) then
		return false; -- Axis is a separating axis
	  end

	  -- Test axis a21
	  p0 = v0:dot( a21 );
	  p1 = v1:dot( a21 );
	  p2 = v2:dot( a21 );
	  r = extents.x * math.abs( f1.y ) + extents.y * math.abs( f1.x );

	  if ( math.max( -math.max( p0, p1, p2 ), math.min( p0, p1, p2 ) ) > r ) then
		return false; -- Axis is a separating axis
	  end

	  -- Test axis a22
	  p0 = v0:dot( a22 );
	  p1 = v1:dot( a22 );
	  p2 = v2:dot( a22 );
	  r = extents.x * math.abs( f2.y ) + extents.y * math.abs( f2.x );

	  if ( math.max( -math.max( p0, p1, p2 ), math.min( p0, p1, p2 ) ) > r ) then
		return false; -- Axis is a separating axis
	  end

	   -- Test the three axes corresponding to the face normals of AABB b (category 1).
	  -- Exit if...
	  -- ... [-extents.x, extents.x] and [min(v0.x,v1.x,v2.x), max(v0.x,v1.x,v2.x)] do not overlap
	  if ( math.max( v0.x, v1.x, v2.x ) < -extents.x or math.min( v0.x, v1.x, v2.x ) > extents.x ) then
		return false;
	  end
	  -- ... [-extents.y, extents.y] and [min(v0.y,v1.y,v2.y), max(v0.y,v1.y,v2.y)] do not overlap
	  if ( math.max( v0.y, v1.y, v2.y ) < -extents.y or math.min( v0.y, v1.y, v2.y ) > extents.y ) then
		return false;
	  end
	  -- ... [-extents.z, extents.z] and [min(v0.z,v1.z,v2.z), max(v0.z,v1.z,v2.z)] do not overlap
	  if ( math.max( v0.z, v1.z, v2.z ) < -extents.z or math.min( v0.z, v1.z, v2.z ) > extents.z ) then
		return false;
	  end

	  -- Test separating axis corresponding to triangle face normal (category 2)
	  -- Face Normal is -ve as Triangle is clockwise winding (and XNA uses -z for into screen)
	  local plane = CSGPlane:new();
	  plane.normal = f1:cross( f0 ):unit();
	  plane.w = plane.normal:dot( a );
  
	  return Collision.isIntersectionAABBPlane( aabb, plane );
end
-- aabb: <ShapeAABB>
-- Plane: <CSGPlane>
function Collision.isIntersectionAABBPlane ( aabb, Plane )
	local center = CSGVector:new():init(aabb.mCenter[1],aabb.mCenter[2],aabb.mCenter[3]);
	local extents = CSGVector:new():init(aabb.mExtents[1],aabb.mExtents[2],aabb.mExtents[3]);

	local r = extents.x * math.abs( Plane.normal.x ) + extents.y * math.abs( Plane.normal.y ) + extents.z * math.abs( Plane.normal.z );
	local s = Plane.normal:dot( center ) - Plane.w;

	return math.abs( s ) <= r;
end
