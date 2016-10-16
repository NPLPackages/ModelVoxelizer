﻿--[[
Title: stl file writer
Author(s): leio, refactored LiXizhi
Date: 2015/12/5
Desc: 
use the lib:
------------------------------------------------------------
NPL.load("(gl)Mod/ModelVoxelizer/bmax/STLWriter.lua");
local STLWriter = commonlib.gettable("Mod.ModelVoxelizer.bmax.STLWriter");
local writer = STLWriter:new();
writer:LoadModel(model);
writer:SetYAxisUp(false);
writer:SaveAsText(filename);
writer:SaveAsBinary(filename);
------------------------------------------------------------
]]
NPL.load("(gl)Mod/ModelVoxelizer/bmax/BMaxModel.lua");
NPL.load("(gl)script/ide/math/vector.lua");
local vector3d = commonlib.gettable("mathlib.vector3d");
local BMaxModel = commonlib.gettable("Mod.ModelVoxelizer.bmax.BMaxModel");
local STLWriter = commonlib.inherit(nil,commonlib.gettable("Mod.ModelVoxelizer.bmax.STLWriter"));

-- whether the exported model is Y axis up. BMaxModel uses Y axis up by default, 
-- however, most CAD software uses Z up such as STL.
STLWriter.m_isYAxisUp = false;

function STLWriter:ctor()
end

function STLWriter:LoadModelFromBMaxFile(filename)
	local model = BMaxModel:new();
	model:Load(filename);
	self:LoadModel(model);
end

function STLWriter:LoadModel(bmaxModel)
	self.model = bmaxModel;
end

function STLWriter:IsYAxisUp()
	return self.m_isYAxisUp;
end

function STLWriter:SetYAxisUp(bIsYUp)
	self.m_isYAxisUp = bIsYUp;
end

function STLWriter:IsValid()
	if(self.model) then
		return true;
	end
end

-- save as binary stl file
function STLWriter:SaveAsBinary(output_file_name)
	if(not self:IsValid()) then
		return false;
	end

	ParaIO.CreateDirectory(output_file_name);
	
	local isYUp = self:IsYAxisUp();

	local function write_face(file,vertex_1,vertex_2,vertex_3)
		local a = vertex_3 - vertex_1;
		local b = vertex_3 - vertex_2;
		local normal = a*b;
		normal:normalize();
		if(isYUp) then
			file:WriteFloat(normal[1]);	file:WriteFloat(normal[2]); file:WriteFloat(normal[3]);
			file:WriteFloat(vertex_1[1]); file:WriteFloat(vertex_1[2]);file:WriteFloat(vertex_1[3]);
			file:WriteFloat(vertex_2[1]); file:WriteFloat(vertex_2[2]);file:WriteFloat(vertex_2[3]);
			file:WriteFloat(vertex_3[1]); file:WriteFloat(vertex_3[2]);file:WriteFloat(vertex_3[3]);
		else
			-- invert y,z and change the triangle winding
			file:WriteFloat(normal[1]);	file:WriteFloat(normal[3]); file:WriteFloat(normal[2]);
			file:WriteFloat(vertex_1[1]); file:WriteFloat(vertex_1[3]);file:WriteFloat(vertex_1[2]);
			file:WriteFloat(vertex_3[1]); file:WriteFloat(vertex_3[3]);file:WriteFloat(vertex_3[2]);
			file:WriteFloat(vertex_2[1]); file:WriteFloat(vertex_2[3]);file:WriteFloat(vertex_2[2]);
		end

		local dummy = "\0\0";
		file:write(dummy,2);
	end
	local file = ParaIO.open(output_file_name, "w");
	if(file:IsValid()) then
		local name = "ParaEngine";
		local total = 80;
		for k = string.len(name),total-1 do
			name = name .. "\0";
		end
		file:write(name,total);
		local count = self.model:GetTotalTriangleCount();
		file:WriteInt(count);
		for _, cube in ipairs(self.model.m_blockModels) do
			for nFaceIndex = 0, cube:GetFaceCount()-1 do
				local vertex_1,vertex_2,vertex_3 = cube:GetFaceTriangle(nFaceIndex, 0);
				write_face(file,vertex_1,vertex_2,vertex_3);
				local vertex_1,vertex_2,vertex_3 = cube:GetFaceTriangle(nFaceIndex, 1);
				write_face(file,vertex_1,vertex_2,vertex_3);
			end
		end	
		file:close();
		return true;
	end
end

function STLWriter:ConvertToZUp(v1,v2,v3)
	return vector3d:new({v1[1], v1[3], v1[2]}), vector3d:new({v2[1], v2[3], v2[2]}), vector3d:new({v3[1], v3[3], v3[2]});
end
-- save as plain-text stl file
function STLWriter:SaveAsText(output_file_name)
	LOG.std(nil, "info", "STLWriter", "SaveAsText:%s",output_file_name);
	local text = self:GetTextList();
	ParaIO.CreateDirectory(output_file_name);
	local file = ParaIO.open(output_file_name, "w");
	if(file:IsValid()) then
		local content_list = self:GetTextList();
		if(content_list)then
			local k,v;
			for k,v in ipairs(content_list) do
				file:WriteString(text);
			end
		end
		file:close();
		LOG.std(nil, "info", "STLWriter", "SaveAsText end");
		return true;
	end
end
-- get plain text content list
function STLWriter:GetTextList()
	if(not self:IsValid()) then
		return;
	end
	local content_list = {};
	--local content = "";
	local get_vertex = BMaxModel.get_vertex;
	local isYUp = self:IsYAxisUp();
	local function write_string(s)
		if(not s)then
			return
		end	
		table.insert(content_list,s);
	end
	local function write_face(file,vertex_1,vertex_2,vertex_3)
		local a = vertex_3 - vertex_1;
		local b = vertex_3 - vertex_2;
		local normal = a*b;
		normal:normalize();
		if(isYUp) then
			write_string(string.format(" facet normal %f %f %f\n", normal[1], normal[2], normal[3]));
			write_string(string.format("  outer loop\n"));
			write_string(string.format("  vertex %f %f %f\n", vertex_1[1], vertex_1[2], vertex_1[3]));
			write_string(string.format("  vertex %f %f %f\n", vertex_2[1], vertex_2[2], vertex_2[3]));
			write_string(string.format("  vertex %f %f %f\n", vertex_3[1], vertex_3[2], vertex_3[3]));
		else
			-- invert y,z and change the triangle winding
			write_string(string.format(" facet normal %f %f %f\n", normal[1], normal[3], normal[2]));
			write_string(string.format("  outer loop\n"));
			write_string(string.format("  vertex %f %f %f\n", vertex_1[1], vertex_1[3], vertex_1[2]));
			write_string(string.format("  vertex %f %f %f\n", vertex_3[1], vertex_3[3], vertex_3[2]));
			write_string(string.format("  vertex %f %f %f\n", vertex_2[1], vertex_2[3], vertex_2[2]));
		end
		write_string(string.format("  endloop\n"));
		write_string(string.format(" endfacet\n"));
	end
	LOG.std(nil, "info", "STLWriter", "m_blockModels:%d",#self.model.m_blockModels);
	local name = "ParaEngine";
	write_string(string.format("solid %s\n",name));
	for _, cube in ipairs(self.model.m_blockModels) do
		for nFaceIndex = 0, cube:GetFaceCount()-1 do
			local v1,v2,v3 = cube:GetFaceTriangle(nFaceIndex, 0);
			write_face(file,v1,v2,v3);
			v1,v2,v3 = cube:GetFaceTriangle(nFaceIndex, 1);
			write_face(file,v1,v2,v3);
		end
	end	
	write_string(string.format("endsolid %s\n",name));
	LOG.std(nil, "info", "STLWriter", "content_list:%d",#content_list);
	return content_list;
end