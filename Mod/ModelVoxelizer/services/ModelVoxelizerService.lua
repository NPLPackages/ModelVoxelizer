--[[
Title: ModelVoxelizer Service 
Author(s): leio
Date: 2016/10/8
Desc: 
use the lib:
------------------------------------------------------------
NPL.load("(gl)Mod/ModelVoxelizer/services/ModelVoxelizerService.lua");
local ModelVoxelizerService = commonlib.gettable("Mod.ModelVoxelizer.services.ModelVoxelizerService");
------------------------------------------------------------
]]
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
local MAX_NUM = 16;
function ModelVoxelizerService.upload(buffer)
	local data = Encoding.unbase64(buffer);
	local polygons,aabb = ModelVoxelizerService.load_stl(data)
	ModelVoxelizerService.voxelizer(polygons,aabb);
	return true;
end
function ModelVoxelizerService.load_stl(buffer)
	if(not buffer)then
		return
	end
	local aabb = ShapeBox:new():SetPointBox(0,0,0);
	local polygons = {};
	local block;
	for block in string.gfind(buffer, "facet(.-)endfacet") do
		-- get normal value
		local normal_x,normal_y,normal_z = string.match(block,"normal%s+(.-)%s+(.-)%s+(.-)\n");
		normal_x = tonumber(normal_x);
		normal_y = tonumber(normal_y);
		normal_z = tonumber(normal_z);

		local polygon_vertices = {};
		local vertex_line;
		-- get vertices value
		for vertex_line in string.gfind(block,"vertex(.-)\n") do
			local x,y,z = string.match(vertex_line,"%s+(.+)%s+(.+)%s+(.+)");
			x = tonumber(x);
			y = tonumber(y);
			z = tonumber(z);

			table.insert(polygon_vertices,{
				pos = {x,y,z},
				normal = {normal_x,normal_y,normal_z},
			});

			aabb:Extend(x,y,z);
		end
		table.insert(polygons,polygon_vertices);
	end
	return polygons,aabb;
end
-- Get voxel model
-- @param polygons:the array of {pos = { x,y,z} }
-- @param block_length:the max length of block which can be voxel.
function ModelVoxelizerService.voxelizer(polygons,aabb,block_length)
	if(not polygons or not aabb)then
		return;
	end
	block_length = block_length or MAX_NUM
	block_length = math.min(block_length,MAX_NUM);
	block_length = math.max(block_length,1);

	local min_pos = aabb:GetMin();
	local start_x = min_pos[1];
	local start_y = min_pos[2];
	local start_z = min_pos[3];

	local width = aabb:GetWidth();
	local height = aabb:GetHeight();
	local depth = aabb:GetDepth();

	local max_dist = math.max(width,height);
	max_dist = math.max(max_dist,depth);

	local x_block_length = math.floor((width / max_dist) * block_length);
	local y_block_length = math.floor((height / max_dist) * block_length);
	local z_block_length = math.floor((depth / max_dist) * block_length);

	local function get_min_max(block_length,max_block_length)
		local max_block_length_half = math.floor(max_block_length* 0.5);
		local block_length_half = math.floor(block_length * 0.5);

		local block_length_min = max_block_length_half - block_length_half + 1;
		local block_length_max = max_block_length_half + block_length_half;

		return block_length_min,block_length_max;
	end
	
	local x_min,x_max = get_min_max(x_block_length,block_length);
	local y_min,y_max = get_min_max(y_block_length,block_length);
	local z_min,z_max = get_min_max(z_block_length,block_length);

	local center_x = start_x + width/2;
	local center_y = start_y + height/2;
	local center_z = start_z + depth/2;

	local offset_x = 0 - center_x;
	local offset_y = 0 - center_y;
	local offset_z = 0 - center_z;

	LOG.std(nil, "info", "voxelizer", "block length x:%d,y:%d,z:%d,max:%d ",x_block_length,y_block_length,z_block_length,block_length);
	LOG.std(nil, "info", "voxelizer", "x_min:%d x_max:%d,y_min:%d y_max:%d,z_min:%d z_max:%d", x_min,x_max,y_min,y_max,z_min,z_max);
	LOG.std(nil, "info", "voxelizer", "polygons lenght is:%d", #polygons);
	local block_size = max_dist/block_length;
	local block_maps = {};
	local blocks = {};

	for x = x_min,x_max do
		for y = y_min,y_max do
			for z = z_min,z_max do
				local c_x = (x-1)*block_size + block_size * 0.5 + (center_x - max_dist * 0.5);
				local c_y = (y-1)*block_size + block_size * 0.5 + (center_y - max_dist * 0.5);
				local c_z = (z-1)*block_size + block_size * 0.5 + (center_z - max_dist * 0.5);

				local size = block_size * 0.5;
				local aabb = ShapeAABB:new();
				aabb.mCenter = vector3d:new({c_x,c_y,c_z});
				aabb.mExtents = vector3d:new({size,size,size});
				local polygon;
				for __, polygon in ipairs(polygons) do
					if(ModelVoxelizerService.intersectPolygon(aabb,polygon))then
						local id = string.format("%d_%d_%d",x,y,z);
						if(not block_maps[id])then
							aabb.mCenter:add(offset_x,offset_y,offset_z);
							block_maps[id] = aabb;
							table.insert(blocks,{x,y,z});
						end
					end
				end
				z = z + 1;
			end
			y = y + 1;
		end
		x = x + 1;
	end
	local model = BMaxModel:new();
	model:LoadFromBlocks(blocks);

	local writer = STLWriter:new();
	writer:LoadModel(model);
	writer:SetYAxisUp(false);
	writer:SaveAsText("test/test_voxel.stl");
end
-- polygon is a array of {pos = {x,y,z} normal = {normal_x,normal_y,normal_z}, }
function ModelVoxelizerService.intersectPolygon(aabb,polygon)
	local a = CSGVector:new():init(polygon[1].pos);
	local b = CSGVector:new():init(polygon[2].pos);
	local c = CSGVector:new():init(polygon[3].pos);
	return Collision.isIntersectionTriangleAABB (a, b, c, aabb); 
end
function ModelVoxelizerService.contains(aabb,x,y,z)
	if(not aabb:IsValid())then
		return
	end	
	local min_x,min_y,min_z = aabb:GetMinValues();
	local max_x,max_y,max_z = aabb:GetMaxValues();

	return (x >= min_x and y >= min_y and z >= min_z and x <= max_x and y <= max_y and z <= max_z);
end

