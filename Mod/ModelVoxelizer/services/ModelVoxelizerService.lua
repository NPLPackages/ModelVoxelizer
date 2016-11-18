--[[
Title: ModelVoxelizerService
Author(s): leio
Date: 2016/10/16
Desc: 
use the lib:
------------------------------------------------------------
NPL.load("(gl)Mod/ModelVoxelizer/services/ModelVoxelizerService.lua");
local ModelVoxelizerService = commonlib.gettable("Mod.ModelVoxelizer.services.ModelVoxelizerService");
ModelVoxelizerService.test("test/a.stl","test/a_out.stl",false,16,nil,nil)
ModelVoxelizerService.test("test/a.stl","test/a_out.bmax",false,16,nil,"bmax")

ModelVoxelizerService.test("test/a.bmax","test/a_out.stl",false,16,"bmax","stl")
ModelVoxelizerService.test("test/a.bmax","test/a_out.bmax",false,16,"bmax","bmax")

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
NPL.load("(gl)Mod/ModelVoxelizer/services/ModelVoxelizer.lua");
NPL.load("(gl)script/ide/System/Core/Color.lua");
NPL.load("(gl)Mod/ModelVoxelizer/bmax/VertexWriter.lua");
local vector3d = commonlib.gettable("mathlib.vector3d");
local ShapeBox = commonlib.gettable("mathlib.ShapeBox");
local ShapeAABB = commonlib.gettable("mathlib.ShapeAABB");
local Encoding = commonlib.gettable("System.Encoding");
local BMaxModel = commonlib.gettable("Mod.ModelVoxelizer.bmax.BMaxModel");
local STLWriter = commonlib.gettable("Mod.ModelVoxelizer.bmax.STLWriter");
local Collision = commonlib.gettable("Mod.ModelVoxelizer.bmax.Collision");
local CSGVector = commonlib.gettable("Mod.NplCadLibrary.csg.CSGVector");
local Color = commonlib.gettable("System.Core.Color");
local VertexWriter = commonlib.gettable("Mod.ModelVoxelizer.bmax.VertexWriter");

local ModelVoxelizer = commonlib.gettable("Mod.ModelVoxelizer.services.ModelVoxelizer");

local ModelVoxelizerService = commonlib.inherit(nil,commonlib.gettable("Mod.ModelVoxelizer.services.ModelVoxelizerService"));

ModelVoxelizerService.max_thread = 1;

ModelVoxelizerService.working_thread_list = {};
ModelVoxelizerService.blocks = {};
ModelVoxelizerService.blocks_map = {};
ModelVoxelizerService.id_index = 0;

ModelVoxelizerService.bBase64 = nil;
ModelVoxelizerService.block_length = 0;
ModelVoxelizerService.input_format = nil;
ModelVoxelizerService.output_format = nil;

ModelVoxelizerService.callback = nil;

function ModelVoxelizerService.reset()
	ModelVoxelizerService.working_thread_list = {};
	ModelVoxelizerService.blocks = {};
	ModelVoxelizerService.blocks_map = {};

	ModelVoxelizerService.id_index = 0;

	ModelVoxelizerService.bBase64 = nil;
	ModelVoxelizerService.block_length = 0;
	ModelVoxelizerService.input_format = nil;
	ModelVoxelizerService.output_format = nil;

	ModelVoxelizerService.callback = nil;
end
function ModelVoxelizerService.generateID()
	ModelVoxelizerService.id_index = ModelVoxelizerService.id_index + 1;
	local id = "ModelVoxelizerProcessor_" .. ModelVoxelizerService.id_index;
	return id;
end
function ModelVoxelizerService.insertThreadID(id)
	if(not id)then
		return
	end
	table.insert(ModelVoxelizerService.working_thread_list,id);
end
function ModelVoxelizerService.getThreadID(id)
	if(not id)then
		return
	end
	for k,v in ipairs(ModelVoxelizerService.working_thread_list) do
		if(v == id)then
			return v;
		end
	end
end
function ModelVoxelizerService.deleteThreadID(id)
	if(not id)then
		return
	end
	local k,v;
	for k,v in ipairs(ModelVoxelizerService.working_thread_list) do
		if(v == id)then
			table.remove(ModelVoxelizerService.working_thread_list,k);
			return;
		end
	end
end
function ModelVoxelizerService.processing(msg)
	if(not msg or not msg.polygons)then
		return
	end
	local working_main_thread = msg.working_main_thread;
	local thread_id = msg.thread_id;
	local polygons = msg.polygons;
	local block_length = msg.block_length;

	local aabb = ShapeBox:new();
	aabb.m_Min = vector3d:new(msg.aabb.m_Min);
	aabb.m_Max = vector3d:new(msg.aabb.m_Max);

	local model_voxelizer = ModelVoxelizer:new();

	local blocks = model_voxelizer:buildBMaxModel_blocks(polygons,aabb,block_length);
	LOG.std(nil, "info", "ModelVoxelizerService", "processing blocks:%d",#blocks);

	NPL.activate(string.format("(%s)Mod/ModelVoxelizer/services/ModelVoxelizerService.lua",working_main_thread), {
		   type = "processed", 
		   thread_id = thread_id,
		   blocks = blocks,
		  });
end
-- processed in main thread
function ModelVoxelizerService.processed(msg)
	local thread_id = msg.thread_id;
	local blocks = msg.blocks;

	LOG.std(nil, "info", "ModelVoxelizerService", "processed:%s",tostring(thread_id));

	local input_format = ModelVoxelizerService.input_format;
	local output_format = ModelVoxelizerService.output_format;
	local bBase64 = ModelVoxelizerService.bBase64;
	ModelVoxelizerService.deleteThreadID(thread_id);
	local k,v;
	for k,v in ipairs(blocks) do
		local id = string.format("id_%d_%d_%d",v[1],v[2],v[3]);
		if(not ModelVoxelizerService.blocks_map[id])then
			ModelVoxelizerService.blocks_map[id] = true;
			table.insert(ModelVoxelizerService.blocks,v);
		end
	end
	LOG.std(nil, "info", "ModelVoxelizerService", "ModelVoxelizerService.blocks length :%d",#ModelVoxelizerService.blocks);

	if(ModelVoxelizerService.isEmpty())then
		local bmax_model = BMaxModel:new();
		bmax_model:LoadFromBlocks(ModelVoxelizerService.blocks);	

		local content;
		local mesh_content;
		local preview_stl_content = ModelVoxelizerService.getStlContent(bmax_model);
		if(output_format == "stl")then
			--same as preview_stl_content
			content = nil;
		elseif(output_format == "bmax")then
			content = ModelVoxelizerService.getBMaxContent(bmax_model);
			mesh_content = ModelVoxelizerService.getMeshContent(bmax_model);
		end
		if(bBase64)then
			LOG.std(nil, "info", "ModelVoxelizerService", "ModelVoxelizerService.processed() encode base64.");

			if(preview_stl_content and type(preview_stl_content) == "table")then
				preview_stl_content = table.concat(preview_stl_content);
			end

			if(content and type(content) == "table")then
				content = table.concat(content);
			end
			if(preview_stl_content)then
				preview_stl_content = Encoding.base64(preview_stl_content);
			end
			if(content)then
				content = Encoding.base64(content);
			end
		end
		if(ModelVoxelizerService.callback)then
			ModelVoxelizerService.callback({
				preview_stl_content = preview_stl_content,
				content = content,
				mesh_content = mesh_content,
			});
		end
		--reset
		ModelVoxelizerService.reset();
		LOG.std(nil, "info", "ModelVoxelizerService", "ModelVoxelizerService.processed() finished! blocks length :%d",#ModelVoxelizerService.blocks);
	end
end
function ModelVoxelizerService.getLength()
	local len = #ModelVoxelizerService.working_thread_list;
	return len;
end
function ModelVoxelizerService.isEmpty()
	local len = #ModelVoxelizerService.working_thread_list;
	if(len > 0)then
		return false
	end
	return true;
end
function ModelVoxelizerService.getThreadNum(polygons,block_length)
	if(not polygons)then
		return 0;
	end
	return ModelVoxelizerService.max_thread;
end
function ModelVoxelizerService.getPolygons(polygons,start_index,end_index)
	if(not polygons)then
		return;
	end
	local len = #polygons;
	start_index = math.max(start_index,1);
	end_index = math.min(end_index,len);

	local result = {};
	for k = start_index,end_index do
		table.insert(result,polygons[k]);
	end
	return result;
end
function ModelVoxelizerService.start(buffer,bBase64, block_length,input_format,output_format,callback)
	local working_main_thread = __rts__:GetName();
	LOG.std(nil, "info", "ModelVoxelizerService", "thread:%s block_length:%d input_format:%s output_format:%s",working_main_thread,block_length,input_format,output_format);
	if(not ModelVoxelizerService.isEmpty())then
		LOG.std(nil, "warning", "ModelVoxelizerService", "ModelVoxelizerService can't start.working_thread_list:%d",#ModelVoxelizerService.working_thread_list);
		return
	end
	if(not buffer)then
		return
	end

	block_length = block_length or 1;
	input_format = input_format or "stl"
	output_format = output_format or "stl"

	ModelVoxelizerService.bBase64 = bBase64;
	ModelVoxelizerService.block_length = block_length;
	ModelVoxelizerService.input_format = input_format;
	ModelVoxelizerService.output_format = output_format ;
	ModelVoxelizerService.callback = callback; 

	local data;
	local polygons;
	local aabb;
	if(bBase64)then
		data = Encoding.unbase64(buffer);
	else
		data = buffer;
	end
	if(input_format == "stl")then
		polygons,aabb = ModelVoxelizerService.load_stl(data);
	elseif(input_format == "colorstl")then
		polygons,aabb = ModelVoxelizerService.load_color_stl(data);
	elseif(input_format == "bmax")then
		polygons,aabb = ModelVoxelizerService.load_bmax(data);
	end
	local polygons_len = #polygons;
	local thread_num = ModelVoxelizerService.getThreadNum(polygons,block_length);
	local per_thread_polygons = math.ceil(polygons_len / thread_num);
	LOG.std(nil, "info", "ModelVoxelizerService", "polygons:%d split thread_num:%d",#polygons,thread_num);
	for k = 1, thread_num do
		local thead_name = "ModelVoxelizer_T"..k;
			NPL.CreateRuntimeState(thead_name, 0):Start();
			local start_index = (k - 1) * per_thread_polygons + 1;
			local end_index = k * per_thread_polygons;

			local thread_polygons = ModelVoxelizerService.getPolygons(polygons,start_index,end_index);
			ModelVoxelizerService.insertThreadID(k);
			LOG.std(nil, "info", "ModelVoxelizerService", "%s %d->%d %d",thead_name,start_index,end_index,ModelVoxelizerService.getLength());
			
			NPL.activate(format("(%s)Mod/ModelVoxelizer/services/ModelVoxelizerService.lua", thead_name), {
				type = "processing", 
				thread_id = k,
				working_main_thread = working_main_thread,
				polygons = thread_polygons,
				aabb = aabb,
				bBase64 = bBase64,
				block_length = block_length,
				input_format = input_format,
				output_format = output_format,
			});
	end
end
-- return an array of { pos = {x,y,z}, normal = {x,y,z}, } and an instance of <ShapeBox>
function ModelVoxelizerService.load_bmax(buffer)
	if(not buffer)then
		return
	end
	local bmax_model = BMaxModel:new();
	bmax_model:LoadContent(buffer);

	local writer = STLWriter:new();
	writer:LoadModel(bmax_model);
	writer:SetYAxisUp(false);

	local polygons,aabb = writer:GetPolygons();
	return polygons,aabb;
end
--[[ return an array of { 
	{ pos = {x,y,z}, normal = {x,y,z}, },
	{ pos = {x,y,z}, normal = {x,y,z}, },
	{ pos = {x,y,z}, normal = {x,y,z}, },
} 
	and an instance of <ShapeBox>
--]]
function ModelVoxelizerService.load_stl(buffer)
	if(not buffer)then
		return
	end
	local aabb = ShapeBox:new();
	local polygons = {};
	local block;
	local is_first_setted = false
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
				color = {1,0,0},
			});
			if(not is_first_setted)then
				aabb:SetPointBox(x,y,z);
				is_first_setted = true;
			end
			aabb:Extend(x,y,z);
		end
		table.insert(polygons,polygon_vertices);
	end
	return polygons,aabb;
end
--[[
	NOTE:this is not a standard format of stl which included color info.
	return an array of { 
	{ pos = {x,y,z}, normal = {x,y,z}, color = {r,g,b} },
	{ pos = {x,y,z}, normal = {x,y,z}, color = {r,g,b} },
	{ pos = {x,y,z}, normal = {x,y,z}, color = {r,g,b} },
} 
	and an instance of <ShapeBox>
--]]
function ModelVoxelizerService.load_color_stl(buffer)
	if(not buffer)then
		return
	end
	local aabb = ShapeBox:new();
	local polygons = {};
	local block;
	local is_first_setted = false
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
			local x,y,z,r,g,b = string.match(vertex_line,"%s+(.+)%s+(.+)%s+(.+)%s+(.+)%s+(.+)%s+(.+)");
			x = tonumber(x);
			y = tonumber(y);
			z = tonumber(z);
			r = tonumber(r);
			g = tonumber(g);
			b = tonumber(b);

			table.insert(polygon_vertices,{
				pos = {x,y,z},
				normal = {normal_x,normal_y,normal_z},
				--range is 0 - 1.
				color = {r,g,b},
			});
			if(not is_first_setted)then
				aabb:SetPointBox(x,y,z);
				is_first_setted = true;
			end
			aabb:Extend(x,y,z);
		end
		table.insert(polygons,polygon_vertices);
	end
	return polygons,aabb;
end
function ModelVoxelizerService.getMeshContent(bmax_model)
	if(not bmax_model)then
		return
	end
	LOG.std(nil, "info", "ModelVoxelizer", "getMeshContent");
	local writer = VertexWriter:new();
	writer:LoadModel(bmax_model);
	writer:SetYAxisUp(false);
	local vertices,indices,normals,colors = writer:toMesh();
	return {vertices,indices,normals,colors};
end
function ModelVoxelizerService.getStlContent(bmax_model,bConcat)
	if(not bmax_model)then
		return
	end
	LOG.std(nil, "info", "ModelVoxelizer", "getStlContent");
	local writer = STLWriter:new();
	writer:LoadModel(bmax_model);
	writer:SetYAxisUp(false);
	local content = writer:GetTextList();
	if(bConcat)then
		content = table.concat(content);
	end
	return content;
	
end
function ModelVoxelizerService.getBMaxContent(bmax_model,bConcat)
	if(not bmax_model)then
		return
	end
	LOG.std(nil, "info", "ModelVoxelizer", "getBMaxContent");
	local content = bmax_model:GetTextList();
	if(bConcat)then
		content = table.concat(content);
	end
	return content;
end

function ModelVoxelizerService.test(input_filename,output_filename,bBase64,num,input_format,output_format)
	local file = ParaIO.open(input_filename, "r");
	if(file:IsValid()) then
		local text = file:GetText();
		if(bBase64)then
			text = Encoding.base64(text);
		end
		ModelVoxelizerService.start(text,bBase64,num or 16,input_format,output_format,function(msg)
			local preview_stl_content = msg.preview_stl_content;
			local content = msg.content;
			ParaIO.DeleteFile(output_filename);
			local out_file = ParaIO.open(output_filename, "w");
			if(out_file:IsValid())then
				if(bBase64)then
					preview_stl_content = Encoding.unbase64(preview_stl_content);
				end
				local k,line;
				for k,line in ipairs(content) do
					out_file:WriteString(line);
				end
				out_file:close();
			end
			NPL.load("(gl)script/ide/MessageBox.lua");
			_guihelper.MessageBox("finished");
		end);
		file:close();
	end	
end

local function activate()
	if(not msg)then
		return
	end
	local type = msg.type;
	if(type == "processing")then
		 ModelVoxelizerService.processing(msg);
	elseif(type == "processed")then
		ModelVoxelizerService.processed(msg);
	end
end

NPL.this(activate);