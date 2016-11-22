--[[
Title: Collision 
Author(s): leio
Date: 2016/10/10
Desc: 
use the lib:
------------------------------------------------------------
NPL.load("(gl)Mod/ModelVoxelizer/bmax/Collision.lua");
local Collision = commonlib.gettable("Mod.ModelVoxelizer.bmax.Collision");
Collision.isIntersectionTriangleAABB(a, b, c, aabb); 
------------------------------------------------------------
]]

NPL.load("(gl)script/ide/math/ShapeAABB.lua");
NPL.load("(gl)Mod/NplCadLibrary/csg/CSGVector.lua");
NPL.load("(gl)Mod/NplCadLibrary/csg/CSGPlane.lua");
local ShapeAABB = commonlib.gettable("mathlib.ShapeAABB");
local CSGVector = commonlib.gettable("Mod.NplCadLibrary.csg.CSGVector");
local CSGPlane = commonlib.gettable("Mod.NplCadLibrary.csg.CSGPlane");
local Collision = commonlib.gettable("Mod.ModelVoxelizer.bmax.Collision");
local static_vector_1 = CSGVector:new();
local static_vector_2 = CSGVector:new();
local static_csg_plane = CSGPlane:new();

local static_vector_a00 = CSGVector:new();
local static_vector_a01 = CSGVector:new();
local static_vector_a02 = CSGVector:new();
local static_vector_a10 = CSGVector:new();
local static_vector_a11 = CSGVector:new();
local static_vector_a12 = CSGVector:new();
local static_vector_a20 = CSGVector:new();
local static_vector_a21 = CSGVector:new();
local static_vector_a22 = CSGVector:new();

local math_abs = math.abs;
local math_min = math.min;
local math_max = math.max;

-- based on http:--www.gamedev.net/topic/534655-aabb-triangleplane-intersection--distance-to-plane-is-incorrect-i-have-solved-it/
--			https:--gist.github.com/yomotsu/d845f21e2e1eb49f647f
-- a: <CSGVector>, -- vertex of a triangle
-- b: <CSGVector>, -- vertex of a triangle
-- c: <CSGVector>, -- vertex of a triangle
-- aabb: <ShapeAABB>
function Collision.isIntersectionTriangleAABB(a, b, c, aabb) 
	local p0, p1, p2, r;
  
	-- Compute box center and extents of AABoundingBox (if not already given in that format)
	local center = static_vector_1:init(aabb.mCenter[1],aabb.mCenter[2],aabb.mCenter[3]);
	local extents = static_vector_2:init(aabb.mExtents[1],aabb.mExtents[2],aabb.mExtents[3]);

	-- Translate triangle as conceptually moving AABB to origin
	local v0 = a:clone_from_pool():minusInplace(center);
    local v1 = b:clone_from_pool():minusInplace(center);
    local v2 = c:clone_from_pool():minusInplace(center);

	-- Compute edge vectors for triangle
	local f0 = v1:clone_from_pool():minusInplace(v0);
    local f1 = v2:clone_from_pool():minusInplace(v1);
    local f2 = v0:clone_from_pool():minusInplace(v2);

	-- Test axes a00..a22 (category 3)
	local a00 = static_vector_a00:init( 0, -f0[3], f0[2] );
    local a01 = static_vector_a01:init( 0, -f1[3], f1[2] );
    local a02 = static_vector_a02:init( 0, -f2[3], f2[2] );
    local a10 = static_vector_a10:init( f0[3], 0, -f0[1] );
    local a11 = static_vector_a11:init( f1[3], 0, -f1[1] );
    local a12 = static_vector_a12:init( f2[3], 0, -f2[1] );
    local a20 = static_vector_a20:init( -f0[2], f0[1], 0 );
    local a21 = static_vector_a21:init( -f1[2], f1[1], 0 );
    local a22 = static_vector_a22:init( -f2[2], f2[1], 0 );

	-- Test axis a00
	p0 = v0:dot( a00 );
	p1 = v1:dot( a00 );
	p2 = v2:dot( a00 );
	r = extents[2] * math_abs( f0[3] ) + extents[3] * math_abs( f0[2] );

	if ( math_max( -math_max( p0, p1, p2 ), math_min( p0, p1, p2 ) ) > r )then
		return false; -- Axis is a separating axis
	end
	-- Test axis a01
	  p0 = v0:dot( a01 );
	  p1 = v1:dot( a01 );
	  p2 = v2:dot( a01 );
	  r = extents[2] * math_abs( f1[3] ) + extents[3] * math_abs( f1[2] );

	  if ( math_max( -math_max( p0, p1, p2 ), math_min( p0, p1, p2 ) ) > r ) then
		return false; -- Axis is a separating axis
	  end

	  -- Test axis a02
	  p0 = v0:dot( a02 );
	  p1 = v1:dot( a02 );
	  p2 = v2:dot( a02 );
	  r = extents[2] * math_abs( f2[3] ) + extents[3] * math_abs( f2[2] );

	  if ( math_max( -math_max( p0, p1, p2 ), math_min( p0, p1, p2 ) ) > r ) then
		return false; -- Axis is a separating axis
	  end

	  -- Test axis a10
	  p0 = v0:dot( a10 );
	  p1 = v1:dot( a10 );
	  p2 = v2:dot( a10 );
	  r = extents[1] * math_abs( f0[3] ) + extents[3] * math_abs( f0[1] );
	  if ( math_max( -math_max( p0, p1, p2 ), math_min( p0, p1, p2 ) ) > r ) then
		return false; -- Axis is a separating axis
	  end

	  -- Test axis a11
	  p0 = v0:dot( a11 );
	  p1 = v1:dot( a11 );
	  p2 = v2:dot( a11 );
	  r = extents[1] * math_abs( f1[3] ) + extents[3] * math_abs( f1[1] );

	  if ( math_max( -math_max( p0, p1, p2 ), math_min( p0, p1, p2 ) ) > r ) then
		return false; -- Axis is a separating axis
	  end

	  -- Test axis a12
	  p0 = v0:dot( a12 );
	  p1 = v1:dot( a12 );
	  p2 = v2:dot( a12 );
	  r = extents[1] * math_abs( f2[3] ) + extents[3] * math_abs( f2[1] );

	  if ( math_max( -math_max( p0, p1, p2 ), math_min( p0, p1, p2 ) ) > r ) then
		return false; -- Axis is a separating axis
	  end

	  -- Test axis a20
	  p0 = v0:dot( a20 );
	  p1 = v1:dot( a20 );
	  p2 = v2:dot( a20 );
	  r = extents[1] * math_abs( f0[2] ) + extents[2] * math_abs( f0[1] );

	  if ( math_max( -math_max( p0, p1, p2 ), math_min( p0, p1, p2 ) ) > r ) then
		return false; -- Axis is a separating axis
	  end

	  -- Test axis a21
	  p0 = v0:dot( a21 );
	  p1 = v1:dot( a21 );
	  p2 = v2:dot( a21 );
	  r = extents[1] * math_abs( f1[2] ) + extents[2] * math_abs( f1[1] );

	  if ( math_max( -math_max( p0, p1, p2 ), math_min( p0, p1, p2 ) ) > r ) then
		return false; -- Axis is a separating axis
	  end

	  -- Test axis a22
	  p0 = v0:dot( a22 );
	  p1 = v1:dot( a22 );
	  p2 = v2:dot( a22 );
	  r = extents[1] * math_abs( f2[2] ) + extents[2] * math_abs( f2[1] );

	  if ( math_max( -math_max( p0, p1, p2 ), math_min( p0, p1, p2 ) ) > r ) then
		return false; -- Axis is a separating axis
	  end

	   -- Test the three axes corresponding to the face normals of AABB b (category 1).
	  -- Exit if...
	  -- ... [-extents[1], extents[1]] and [min(v0[1],v1[1],v2[1]), max(v0[1],v1[1],v2[1])] do not overlap
	  if ( math_max( v0[1], v1[1], v2[1] ) < -extents[1] or math_min( v0[1], v1[1], v2[1] ) > extents[1] ) then
		return false;
	  end
	  -- ... [-extents[2], extents[2]] and [min(v0[2],v1[2],v2[2]), max(v0[2],v1[2],v2[2])] do not overlap
	  if ( math_max( v0[2], v1[2], v2[2] ) < -extents[2] or math_min( v0[2], v1[2], v2[2] ) > extents[2] ) then
		return false;
	  end
	  -- ... [-extents[3], extents[3]] and [min(v0[3],v1[3],v2[3]), max(v0[3],v1[3],v2[3])] do not overlap
	  if ( math_max( v0[3], v1[3], v2[3] ) < -extents[3] or math_min( v0[3], v1[3], v2[3] ) > extents[3] ) then
		return false;
	  end

	  -- Test separating axis corresponding to triangle face normal (category 2)
	  -- Face Normal is -ve as Triangle is clockwise winding (and XNA uses -z for into screen)
	  local plane = static_csg_plane;
	  plane.normal = f1:crossInplace( f0 ):unitInplace();
	  plane.w = plane.normal:dot( a );
  
	  return Collision.isIntersectionAABBPlane( aabb, plane );
end
-- aabb: <ShapeAABB>
-- Plane: <CSGPlane>
function Collision.isIntersectionAABBPlane( aabb, Plane )
	local center = static_vector_1:init(aabb.mCenter[1],aabb.mCenter[2],aabb.mCenter[3]);
	local extents = static_vector_2:init(aabb.mExtents[1],aabb.mExtents[2],aabb.mExtents[3]);

	local r = extents[1] * math_abs( Plane.normal[1] ) + extents[2] * math_abs( Plane.normal[2] ) + extents[3] * math_abs( Plane.normal[3] );
	local s = Plane.normal:dot( center ) - Plane.w;

	return math_abs( s ) <= r;
end
