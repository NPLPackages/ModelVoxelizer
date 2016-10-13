--[[
Title: ModelVoxelizer Service 
Author(s): leio
Date: 2016/10/8
Desc: 
use the lib:
------------------------------------------------------------
NPL.load("(gl)Mod/ModelVoxelizer/services/ModelVoxelizerService.lua");
local ModelVoxelizerService = commonlib.gettable("Mod.ModelVoxelizer.services.ModelVoxelizerService");

local file = ParaIO.open("test/a.stl", "r");
if(file:IsValid()) then
	local text = file:GetText();
	local content = ModelVoxelizerService.voxelizer(text,false,32);
	file:close();

	ParaIO.DeleteFile("test/a_out.stl");
	local out_file = ParaIO.open("test/a_out.stl", "w");
	if(out_file:IsValid())then
		out_file:WriteString(content);
		out_file:close();
	end
end					
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
local MAX_NUM = 256;
-- changes content by input_format
-- @param buffer:input content
-- @param bBase64:if input buffer is Base64 string
-- @param input_format:stl or bmax
-- @param output_format:stl or bmax
-- return a base64 string
function ModelVoxelizerService.voxelizer(buffer,bBase64, block_length,input_format,output_format)
	LOG.std(nil, "info", "voxelizer", "block_length:%d input_format:%s output_format:%s",block_length,input_format,output_format);
	if(not buffer)then
		return
	end
	block_length = block_length or 1;
	input_format = input_format or "stl"
	output_format = output_format or "stl"

	local data;
	if(bBase64)then
		data = Encoding.unbase64(buffer);
	else
		data = buffer;
	end
	if(input_format == "stl")then
		local polygons,aabb = ModelVoxelizerService.load_stl(data)
		local bmax_model = ModelVoxelizerService.buildBMaxModel(polygons,aabb,block_length);
		local content;
		if(output_format == "stl")then
			content = ModelVoxelizerService.getStlContent(bmax_model);
		elseif(output_format == "bmax")then
			content = ModelVoxelizerService.getBMaxContent(bmax_model);
		end
		if(bBase64)then
			content = Encoding.base64(content);
		end
		return content;
	end
end
-- return an array of { pos = {x,y,z}, normal = {x,y,z}, } and an instance of <ShapeBox>
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

function ModelVoxelizerService.getStlContent(bmax_model)
	if(not bmax_model)then
		return
	end
	local writer = STLWriter:new();
	writer:LoadModel(bmax_model);
	writer:SetYAxisUp(false);
	return writer:GetText();
	
end
function ModelVoxelizerService.getBMaxContent(bmax_model)
	if(not bmax_model)then
		return
	end
	return bmax_model:GetText();
end
-- Get voxel model
-- @param polygons:an array of {pos = { x,y,z}, normal = {normal_x,normal_y,normal_z},  }
-- @param aabb:an instance of <ShapeBox>
-- @param block_length:the max length of block which can be voxel.
-- return an instance of <BMaxModel>.
function ModelVoxelizerService.buildBMaxModel(polygons,aabb,block_length)
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
	LOG.std(nil, "info", "voxelizer", "buildBMaxModel polygons:%d max_dist:%f block_length:%d(MAX_NUM:%d) block_size:%f", #polygons,max_dist,block_length,MAX_NUM,block_size);

	local block_maps = {};
	local blocks = {};

	local polygon;
	for __, polygon in ipairs(polygons) do
		local aabb,changed_polygon = ModelVoxelizerService.buildShapeAABB(shape_aabb,polygon,block_length)
		ModelVoxelizerService.buildBlocks(blocks,block_maps,changed_polygon,aabb,block_length,block_size)
	end


	local model = BMaxModel:new();
	model:LoadFromBlocks(blocks);
	LOG.std(nil, "info", "voxelizer", "BMaxModel created successfully. blocks length:%d",#blocks);

	return model;
end
-- build polygon's aabb
-- @param shape_aabb:an instance of <ShapeAABB>
-- @param polygon:an array of {pos = {x,y,z}, normal = {normal_x,normal_y,normal_z}, }
-- @param block_length: max block number
-- return aabb,changed_polygon
function ModelVoxelizerService.buildShapeAABB(shape_aabb,polygon,block_length)
	local center = shape_aabb.mCenter;
	local extent = shape_aabb.mExtents;
	local changed_polygon = {};
	local box = ShapeBox:new():SetPointBox(0,0,0);
	local k,v;
	for k,v in ipairs(polygon) do
		local x = v.pos[1] - center[1];
		local y = v.pos[2] - center[2];
		local z = v.pos[3] - center[3];

		box:Extend(x,y,z);

		table.insert(changed_polygon,{
			pos = {x,y,z},
			normat = {v.normal_x,v.normal_y,v.normal_z}
		})
	end
	local aabb = ShapeAABB:new();
	aabb:SetMinMax(box:GetMin(), box:GetMax());
	return aabb,changed_polygon;
end
-- build blocks for BMaxModel.
function ModelVoxelizerService.buildBlocks(blocks,block_maps,changed_polygon,aabb,block_max_num,block_size)
	local center = aabb.mCenter;
	local min = aabb:GetMin();
	local max = aabb:GetMax();

	local half_num = math.ceil(block_max_num/2);
	local half_size = block_size * 0.5;
	local center_x = math.floor(center[1]/block_size);
	local center_y = math.floor(center[2]/block_size);
	local center_z = math.floor(center[3]/block_size);

	
	local start_x = math.floor(min[1]/block_size);
	local start_y = math.floor(min[2]/block_size);
	local start_z = math.floor(min[3]/block_size);

	local end_x = math.floor(max[1]/block_size);
	local end_y = math.floor(max[2]/block_size);
	local end_z = math.floor(max[3]/block_size);
	LOG.std(nil, "info", "voxelizer", "buildBlocks x:%d->%d y:%d->%d z:%d->%d", start_x,end_x,start_y,end_y,start_z,end_z);
	local test_aabb = ShapeAABB:new();
	local x,y,z;
	for x = start_x,end_x do
		for y = start_y,end_y do
			for z = start_z,end_z do
				local id = string.format("id_%d_%d_%d",x,y,z);
				if(not block_maps[id])then
					test_aabb:SetCenterExtentValues(x * block_size,y * block_size,z * block_size,half_size,half_size,half_size);
					if(ModelVoxelizerService.intersectPolygon(test_aabb,changed_polygon))then
						block_maps[id] = true;
						local x_index = x + half_num;
						local y_index = y + half_num;
						local z_index = z + half_num;
						table.insert(blocks,{x_index,y_index,z_index});
					end
				end
			end
		end
	end
end
-- hittest between aabb and polygon.
-- @param aabb:an instance of <ShapeAABB>
-- @param polygon:an array of {pos = {x,y,z}, normal = {normal_x,normal_y,normal_z}, }
function ModelVoxelizerService.intersectPolygon(aabb,polygon)
	local a = CSGVector:new():init(polygon[1].pos);
	local b = CSGVector:new():init(polygon[2].pos);
	local c = CSGVector:new():init(polygon[3].pos);
	return Collision.isIntersectionTriangleAABB (a, b, c, aabb); 
end

