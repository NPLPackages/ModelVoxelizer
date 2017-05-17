--[[
Title: ModelVoxelizer
Author(s): leio, LiXizhi (minor fix performance)
Date: 2016/10/16
Desc: 
use the lib:
------------------------------------------------------------
NPL.load("(gl)Mod/ModelVoxelizer/services/ModelVoxelizer.lua");
local ModelVoxelizer = commonlib.gettable("Mod.ModelVoxelizer.services.ModelVoxelizer");
local model_voxelizer = ModelVoxelizer:new();
------------------------------------------------------------
]]
NPL.load("(gl)script/ide/commonlib.lua");
NPL.load("(gl)script/ide/math/vector.lua");
NPL.load("(gl)script/ide/math/ShapeBox.lua");
NPL.load("(gl)script/ide/math/ShapeAABB.lua");
NPL.load("(gl)script/ide/System/Encoding/base64.lua");
NPL.load("(gl)Mod/ModelVoxelizer/bmax/BMaxModel.lua");
NPL.load("(gl)Mod/ModelVoxelizer/bmax/STLWriter.lua");
NPL.load("(gl)Mod/ModelVoxelizer/bmax/Collision.lua");
NPL.load("(gl)script/ide/System/Core/Color.lua");
NPL.load("(gl)script/ide/math/vector.lua");

local ShapeBox = commonlib.gettable("mathlib.ShapeBox");
local ShapeAABB = commonlib.gettable("mathlib.ShapeAABB");
local Encoding = commonlib.gettable("System.Encoding");
local BMaxModel = commonlib.gettable("Mod.ModelVoxelizer.bmax.BMaxModel");
local STLWriter = commonlib.gettable("Mod.ModelVoxelizer.bmax.STLWriter");
local Collision = commonlib.gettable("Mod.ModelVoxelizer.bmax.Collision");
local Color = commonlib.gettable("System.Core.Color");
local vector3d = commonlib.gettable("mathlib.vector3d");

local ModelVoxelizerService = commonlib.gettable("Mod.ModelVoxelizer.services.ModelVoxelizerService");
local MAX_NUM = 256;
local static_vector_1 = vector3d:new();
local static_vector_2 = vector3d:new();
local static_vector_3 = vector3d:new();
local static_shape_aabb = ShapeAABB:new();
local static_shape_box = ShapeBox:new();

local math_floor = math.floor;
local math_ceil = math.ceil;
local string_format = string.format;
local table_insert = table.insert;

local ModelVoxelizer = commonlib.inherit(nil,commonlib.gettable("Mod.ModelVoxelizer.services.ModelVoxelizer"));
function ModelVoxelizer:ctor()
end

-- Get all of blocks 
-- @param polygons:an array of {pos = { x,y,z}, normal = {normal_x,normal_y,normal_z},  color = {r,g,b}, }
-- @param aabb:an instance of <ShapeBox>
-- @param block_length:the max length of block which can be voxel.
-- return an array of {x_index,y_index,z_index,constant_id_10,color_value}
function ModelVoxelizer:buildBMaxModel_blocks(polygons,aabb,block_length)
	if(not polygons or not aabb)then
		return;
	end
	block_length = block_length or MAX_NUM
	block_length = math.min(block_length,MAX_NUM);
	block_length = math.max(block_length,1);

	local shape_aabb = ShapeAABB:new();
	local vOffsetMin = aabb:GetMin();
	shape_aabb:SetMinMax(vOffsetMin,aabb:GetMax());

	local extent = shape_aabb.mExtents;
	local max_dist = math.max(extent[1],extent[2]);
	max_dist = math.max(max_dist,extent[3]);
	max_dist = max_dist * 2;

	block_size = max_dist / block_length;
	local timeStart = ParaGlobal.timeGetTime();
	LOG.std(nil, "info", "ModelVoxelizer", "buildBMaxModel polygons:%d max_dist:%f block_length:%d(MAX_NUM:%d) block_size:%f", #polygons,max_dist,block_length,MAX_NUM,block_size);

	local half_size = block_size * 0.5;

	local block_maps = {};
	local blocks = {};

	local aabb = ShapeAABB:new();
	
	for __, polygon in ipairs(polygons) do
		aabb = self:getPolygonAABB(polygon,aabb);
		self:buildBlocks(blocks, block_maps, polygon, aabb, vOffsetMin, block_length, block_size, half_size);
	end
	-- e.g. Finished in 0.547 seconds, generated 6220 blocks from 7405 polygons
	LOG.std(nil, "info", "ModelVoxelizer", "Finished in %.3f seconds, generated %d blocks from %d polygons", (ParaGlobal.timeGetTime()-timeStart)/1000, #blocks, #polygons);
	return blocks;
end

-- compute a single polygon's aabb box
-- @param polygon:an array of {pos = {x,y,z}, normal = {normal_x,normal_y,normal_z}, color = {r,g,b}, }
-- @param aabb: inout value. if nil, a new one is created. 
-- return aabb
function ModelVoxelizer:getPolygonAABB(polygon, aabb)
	local first_node = polygon[1];
	local pos = first_node.pos;
	local box = static_shape_box:SetPointBox(pos[1],pos[2],pos[3]);
	for i = 2, #polygon do
		pos = polygon[i].pos;
		box:Extend(pos[1],pos[2],pos[3]);
	end
	aabb = aabb or ShapeAABB:new();
	local vMin = box:GetMin();
	local vMax = box:GetMax();
	aabb:SetMinMaxValues(vMin[1],vMin[2],vMin[3], vMax[1], vMax[2], vMax[3]);
	return aabb;
end

-- get sparse index
local function GetSparseIndex(x, y, z)
	return y*30000*30000+x*30000+z;
end

-- build blocks for BMaxModel.
function ModelVoxelizer:buildBlocks(blocks,block_maps,polygon,aabb, vOffsetMin, block_max_num,block_size, half_size)
	local min_x,min_y,min_z = vOffsetMin[1], vOffsetMin[2], vOffsetMin[3];

	local start_x, start_y, start_z = aabb:GetMinValues();
	local end_x, end_y, end_z = aabb:GetMaxValues();
	
	start_x = math_floor((start_x - min_x)/block_size);
	start_y = math_floor((start_y - min_y)/block_size);
	start_z = math_floor((start_z - min_z)/block_size);

	end_x = math_floor((end_x - min_x)/block_size);
	end_y = math_floor((end_y - min_y)/block_size);
	end_z = math_floor((end_z - min_z)/block_size);

	local bHasColor,r,g,b = self:getAverageColor(polygon);
	--color block id
	local block_id = 10;
	local color;
	if(bHasColor)then
		r = math_floor(r * 255);
		g = math_floor(g * 255);
		b = math_floor(b * 255);
		color = Color.RGBA_TO_DWORD(r, g, b);
		color = Color.convert32_16(color);
	end
	--LOG.std(nil, "info", "ModelVoxelizer", "buildBlocks x:%d->%d y:%d->%d z:%d->%d", start_x,end_x,start_y,end_y,start_z,end_z);
	static_shape_aabb:SetCenterExtentValues(0,0,0,half_size,half_size,half_size);

	local offset_x,offset_y,offset_z = min_x + half_size, min_y + half_size, min_z + half_size;
	for x = start_x,end_x do
		for y = start_y,end_y do
			for z = start_z,end_z do
				local id = GetSparseIndex(x,y,z);
				if(not block_maps[id])then
					static_shape_aabb.mCenter:set(x * block_size + offset_x,y * block_size + offset_y,z * block_size + offset_z);
					if(self:intersectPolygon(static_shape_aabb, polygon))then
						block_maps[id] = true;
						blocks[#blocks+1] = {x,y,z,block_id,color};
					end
				end
			end
		end
	end
end
-- hittest between aabb and polygon.
-- @param aabb:an instance of <ShapeAABB>
-- @param polygon:an array of {pos = {x,y,z}, normal = {normal_x,normal_y,normal_z}, color = {r,g,b}, }
function ModelVoxelizer:intersectPolygon(aabb,polygon)
	local a = static_vector_1:set(polygon[1].pos);
	for i=3, #polygon do
		local b = static_vector_2:set(polygon[i-1].pos);
		local c = static_vector_3:set(polygon[i].pos);
		if(Collision.isIntersectionTriangleAABB(a, b, c, aabb)) then
			return true;
		end
	end
end
--r g b range is [0,1]
-- reutrn bHasColor,r,g,b
function ModelVoxelizer:getAverageColor(polygon)
	if(not polygon)then
		return
	end
	local bHasColor = false;
	local r = 0;
	local g = 0;
	local b = 0;
	local len = 0;
	for k,v in ipairs(polygon) do
		local color = v.color;
		if(color)then
			r = r + color[1];
			g = g + color[2];
			b = b + color[3];
			len = len + 1;

			bHasColor = true;
		end
	end
	if(bHasColor) then
		r = r / len;
		g = g / len;
		b = b / len;
		return bHasColor,r,g,b;
	end
end
