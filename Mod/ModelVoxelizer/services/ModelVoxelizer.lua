--[[
Title: ModelVoxelizer
Author(s): leio
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
NPL.load("(gl)Mod/NplCadLibrary/csg/CSGVector.lua");

local vector3d = commonlib.gettable("mathlib.vector3d");
local ShapeBox = commonlib.gettable("mathlib.ShapeBox");
local ShapeAABB = commonlib.gettable("mathlib.ShapeAABB");
local Encoding = commonlib.gettable("System.Encoding");
local BMaxModel = commonlib.gettable("Mod.ModelVoxelizer.bmax.BMaxModel");
local STLWriter = commonlib.gettable("Mod.ModelVoxelizer.bmax.STLWriter");
local Collision = commonlib.gettable("Mod.ModelVoxelizer.bmax.Collision");
local CSGVector = commonlib.gettable("Mod.NplCadLibrary.csg.CSGVector");
local ModelVoxelizerService = commonlib.gettable("Mod.ModelVoxelizer.services.ModelVoxelizerService");
local MAX_NUM = 256;
local static_vector_1 = CSGVector:new();
local static_vector_2 = CSGVector:new();
local static_vector_3 = CSGVector:new();
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
-- @param polygons:an array of {pos = { x,y,z}, normal = {normal_x,normal_y,normal_z},  }
-- @param aabb:an instance of <ShapeBox>
-- @param block_length:the max length of block which can be voxel.
-- return an array of {x_index,y_index,z_index}
function ModelVoxelizer:buildBMaxModel_blocks(polygons,aabb,block_length)
	if(not polygons or not aabb)then
		return;
	end
	block_length = block_length or MAX_NUM
	block_length = math.min(block_length,MAX_NUM);
	block_length = math.max(block_length,1);

	local shape_aabb = ShapeAABB:new();
	shape_aabb:SetMinMax(aabb:GetMin(),aabb:GetMax());

	local extent = shape_aabb.mExtents;
	local max_dist = math.max(extent[1],extent[2]);
	max_dist = math.max(max_dist,extent[3]);
	max_dist = max_dist * 2;

	block_size = max_dist / block_length;
	LOG.std(nil, "info", "ModelVoxelizer", "buildBMaxModel polygons:%d max_dist:%f block_length:%d(MAX_NUM:%d) block_size:%f", #polygons,max_dist,block_length,MAX_NUM,block_size);

	local half_num = math_ceil(block_length/2);
	local half_size = block_size * 0.5;

	local block_maps = {};
	local blocks = {};

	local polygon;
	for __, polygon in ipairs(polygons) do
		local aabb,changed_polygon = self:buildShapeAABB(shape_aabb,polygon,block_length)
		self:buildBlocks(blocks,block_maps,changed_polygon,aabb,block_length,block_size,half_num,half_size);
	end
	
	LOG.std(nil, "info", "ModelVoxelizer", "blocks length:%d",#blocks);

	return blocks;
end
-- build polygon's aabb
-- @param shape_aabb:an instance of <ShapeAABB>
-- @param polygon:an array of {pos = {x,y,z}, normal = {normal_x,normal_y,normal_z}, }
-- @param block_length: max block number
-- return aabb,changed_polygon
function ModelVoxelizer:buildShapeAABB(shape_aabb,polygon,block_length)
	local min_x,min_y,min_z = shape_aabb:GetMinValues();
	local center = shape_aabb.mCenter;
	local extent = shape_aabb.mExtents;
	local changed_polygon = {};
	local first_node = polygon[1];
	local box = static_shape_box:SetPointBox(first_node.pos[1]- min_x,first_node.pos[2]- min_y,first_node.pos[3]- min_z);
	local k,v;
	for k,v in ipairs(polygon) do
		local x = v.pos[1] - min_x;
		local y = v.pos[2] - min_y;
		local z = v.pos[3] - min_z;

		box:Extend(x,y,z);
		table_insert(changed_polygon,{
			pos = {x,y,z},
			normat = {v.normal_x,v.normal_y,v.normal_z}
		})
	end
	local aabb = ShapeAABB:new();
	aabb:SetMinMax(box:GetMin(), box:GetMax());
	return aabb,changed_polygon;
end
-- build blocks for BMaxModel.
function ModelVoxelizer:buildBlocks(blocks,block_maps,changed_polygon,aabb,block_max_num,block_size,half_num,half_size)
	local center = aabb.mCenter;
	local extents = aabb.mExtents;
	local min = aabb:GetMin();
	local max = aabb:GetMax();
	
	local start_x = math_floor(min[1]/block_size);
	local start_y = math_floor(min[2]/block_size);
	local start_z = math_floor(min[3]/block_size);

	local end_x = math_floor(max[1]/block_size);
	local end_y = math_floor(max[2]/block_size);
	local end_z = math_floor(max[3]/block_size);

	--LOG.std(nil, "info", "ModelVoxelizer", "buildBlocks x:%d->%d y:%d->%d z:%d->%d", start_x,end_x,start_y,end_y,start_z,end_z);
	local x,y,z;
	for x = start_x,end_x do
		for y = start_y,end_y do
			for z = start_z,end_z do
				local id = string_format("id_%d_%d_%d",x,y,z);
				if(not block_maps[id])then
					static_shape_aabb:SetCenterExtentValues(x * block_size,y * block_size,z * block_size,half_size,half_size,half_size);
					if(self:intersectPolygon(static_shape_aabb,changed_polygon))then
						block_maps[id] = true;
						table_insert(blocks,{x,y,z});
					end
				end
			end
		end
	end
end
-- hittest between aabb and polygon.
-- @param aabb:an instance of <ShapeAABB>
-- @param polygon:an array of {pos = {x,y,z}, normal = {normal_x,normal_y,normal_z}, }
function ModelVoxelizer:intersectPolygon(aabb,polygon)
	local a = static_vector_1:init(polygon[1].pos);
	local b = static_vector_2:init(polygon[2].pos);
	local c = static_vector_3:init(polygon[3].pos);
	return Collision.isIntersectionTriangleAABB (a, b, c, aabb); 
end
