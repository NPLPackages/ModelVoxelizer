--[[
Title: vertex writer
Author(s): leio
Date: 2015/12/5
Desc: 
use the lib:
------------------------------------------------------------
NPL.load("(gl)Mod/ModelVoxelizer/bmax/VertexWriter.lua");
local VertexWriter = commonlib.gettable("Mod.ModelVoxelizer.bmax.VertexWriter");
local writer = VertexWriter:new();
writer:LoadModel(model);
local vertices,indices,normals,colors = writer:toMesh();
------------------------------------------------------------
]]
NPL.load("(gl)Mod/ModelVoxelizer/bmax/BMaxModel.lua");
NPL.load("(gl)script/ide/math/vector.lua");
NPL.load("(gl)script/ide/math/ShapeBox.lua");
NPL.load("(gl)script/ide/System/Core/Color.lua");
local vector3d = commonlib.gettable("mathlib.vector3d");
local ShapeBox = commonlib.gettable("mathlib.ShapeBox");
local BMaxModel = commonlib.gettable("Mod.ModelVoxelizer.bmax.BMaxModel");
local Color = commonlib.gettable("System.Core.Color");

local VertexWriter = commonlib.inherit(nil,commonlib.gettable("Mod.ModelVoxelizer.bmax.VertexWriter"));

-- whether the exported model is Y axis up. BMaxModel uses Y axis up by default, 
-- however, most CAD software uses Z up such as STL.
VertexWriter.m_isYAxisUp = false;

function VertexWriter:ctor()
end

function VertexWriter:LoadModelFromBMaxFile(filename)
	local model = BMaxModel:new();
	model:Load(filename);
	self:LoadModel(model);
end

function VertexWriter:LoadModel(bmaxModel)
	self.model = bmaxModel;
end

function VertexWriter:IsYAxisUp()
	return self.m_isYAxisUp;
end

function VertexWriter:SetYAxisUp(bIsYUp)
	self.m_isYAxisUp = bIsYUp;
end

function VertexWriter:IsValid()
	if(self.model) then
		return true;
	end
end

function VertexWriter:ConvertToZUp(v1,v2,v3)
	return vector3d:new({v1[1], v1[3], v1[2]}), vector3d:new({v2[1], v2[3], v2[2]}), vector3d:new({v3[1], v3[3], v3[2]});
end
function VertexWriter:toMesh()
	local vertices = {};
	local indices = {};
	local normals = {};
	local colors = {};

	local function write_value(v)
		local x = v.position[1];
		local y = v.position[2];
		local z = v.position[3];
		local pos = {x,y,z};
		local normal = {v.normal[1],v.normal[2],v.normal[3],};
		local color = {1,1,1};
		if(v.color)then
			local rgb = v.color;
			rgb = Color.convert16_32(rgb);
			local r,g,b,a = Color.DWORD_TO_RGBA(rgb);
			color = {r/255,g/255,b/255};
		end
		table.insert(vertices,pos);
		table.insert(normals,normal);
		table.insert(colors,color);
	end
	local cube;
	for _, cube in ipairs(self.model.m_blockModels) do
		for index = 0, cube:GetVerticesCount()-1 do
			local start_index = #vertices + 1;

			local vertex = cube:GetVertex(index);
			write_value(vertex)

			local t = math.mod(index,4);

			if(start_index > 1 and t == 0)then
				table.insert(indices,start_index + 0);
				table.insert(indices,start_index + 1);
				table.insert(indices,start_index + 2);
				table.insert(indices,start_index + 0);
				table.insert(indices,start_index + 2);
				table.insert(indices,start_index + 3);
			end
		end
	end	
	return vertices,indices,normals,colors;
end