--[[
Title: bmax model
Author(s): leio, refactored LiXizhi
Date: 2015/12/4
Desc: 
use the lib:
------------------------------------------------------------
NPL.load("(gl)Mod/ModelVoxelizer/bmax/BMaxModel.lua");
local BMaxModel = commonlib.gettable("Mod.ModelVoxelizer.bmax.BMaxModel");
local model = BMaxModel:new();
model:Load(filename)
model:LoadFromBlocks(blocks)
------------------------------------------------------------
]]
NPL.load("(gl)script/ide/XPath.lua");
NPL.load("(gl)script/ide/math/ShapeAABB.lua");
NPL.load("(gl)Mod/ModelVoxelizer/bmax/BMaxNode.lua");
NPL.load("(gl)Mod/ModelVoxelizer/bmax/BlockModel.lua");
NPL.load("(gl)Mod/ModelVoxelizer/bmax/BlockCommon.lua");
NPL.load("(gl)script/ide/serialization.lua");
NPL.load("(gl)script/ide/mathlib.lua");
local BlockCommon = commonlib.gettable("Mod.ModelVoxelizer.bmax.BlockCommon");
local BlockModel = commonlib.gettable("Mod.ModelVoxelizer.bmax.BlockModel");
local BMaxNode = commonlib.gettable("Mod.ModelVoxelizer.bmax.BMaxNode");
local ShapeAABB = commonlib.gettable("mathlib.ShapeAABB");
local lshift = mathlib.bit.lshift;

local BMaxModel = commonlib.inherit(nil,commonlib.gettable("Mod.ModelVoxelizer.bmax.BMaxModel"));

-- model will be scaled to this size. 
BMaxModel.m_maxSize = 1.0;
BMaxModel.m_bAutoScale = true;

function BMaxModel:ctor()
	self.m_blockAABB = nil;
	self.m_centerPos = nil;
	self.m_fScale = 1;
	self.m_nodes = {};
	self.m_blockModels = {};
	self.unit_value = nil;
	self.blocks = {};

end
function BMaxModel:SetUnit(v)
	self.unit_value = v;
end
function BMaxModel:IsAutoScale()
	return (BMaxModel.m_bAutoScale or (self.unit_value and self.unit_value > 0)) 
end
-- whether we will resize the model to self:GetMaxModelSize();
function BMaxModel:EnableAutoScale(bEnable)
	self.m_bAutoScale = bEnable;
end

function BMaxModel:GetMaxModelSize()
	return self.m_maxSize;
end

function BMaxModel:SetMaxModelSize(size)
	self.m_maxSize = size or 1;
end

-- public: load from file
-- @param bmax_filename: load from *.bmax file
function BMaxModel:Load(bmax_filename)
	if(not bmax_filename)then return end
	local xmlRoot = ParaXML.LuaXML_ParseFile(bmax_filename);
	self:ParseHeader(xmlRoot);
	local blocks = self:ParseBlocks(xmlRoot);
	if(blocks) then
		return self:LoadFromBlocks(blocks);
	end
end
function BMaxModel:LoadContent(content)
	if(not content)then return end
	local xmlRoot = ParaXML.LuaXML_ParseString(content);
	self:ParseHeader(xmlRoot);
	local blocks = self:ParseBlocks(xmlRoot);
	if(blocks) then
		return self:LoadFromBlocks(blocks);
	end
end
-- public: load from array of blocks
-- @param blocks: array of {x,y,z,id, data, serverdata}
function BMaxModel:LoadFromBlocks(blocks)
	self.blocks = blocks;
	self:InitFromBlocks(blocks);
	self:CalculateVisibleBlocks();
	if(self:IsAutoScale())then
		self:ScaleModels(self.m_fScale);
	end
end

function BMaxModel:ParseHeader(xmlRoot)
	if(not xmlRoot)then return end
	local blocktemplate = xmlRoot[1];
	if(blocktemplate and blocktemplate.attr and blocktemplate.attr.auto_scale and (blocktemplate.attr.auto_scale == "false" or blocktemplate.attr.auto_scale == "False"))then
		self.m_bAutoScale = false;	
	end
end

function BMaxModel:ParseBlocks(xmlRoot)
	if(not xmlRoot)then return end
	local node;
	local result;
	for node in commonlib.XPath.eachNode(xmlRoot, "/pe:blocktemplate/pe:blocks") do
		--find block node
		result = node;
		break;
	end
	if(not result)then return end
	return commonlib.LoadTableFromString(result[1]);
end

-- load from array of blocks
-- @param blocks: array of {x,y,z,id, data, serverdata}
function BMaxModel:InitFromBlocks(blocks)
	if(not blocks) then
		return
	end
	local nodes = {};
	local aabb = ShapeAABB:new();

	for k,v in ipairs(blocks) do
		local x = v[1];
		local y = v[2];
		local z = v[3];
		local template_id = v[4];
		local block_data = v[5];
		aabb:Extend(x,y,z);
		local node = BMaxNode:new():init(x,y,z,template_id, block_data);
		table.insert(nodes,node);
	end
	self.m_blockAABB = aabb;

	local blockMinX,  blockMinY, blockMinZ = self.m_blockAABB:GetMinValues()
	local blockMaxX,  blockMaxY, blockMaxZ = self.m_blockAABB:GetMaxValues();
	local width = blockMaxX - blockMinX;
	local height = blockMaxY - blockMinY;
	local depth = blockMaxZ - blockMinZ;

	self.m_centerPos = self.m_blockAABB:GetCenter();
	self.m_centerPos[1] = (width + 1.0) * 0.5;
	self.m_centerPos[2] = 0;
	self.m_centerPos[3]= (depth + 1.0) * 0.5;

	local offset_x = blockMinX;
	local offset_y = blockMinY;
	local offset_z = blockMinZ;

	for k,node in ipairs(nodes) do
		node.x = node.x - offset_x;
		node.y = node.y - offset_y;
		node.z = node.z - offset_z;
		self:InsertNode(node);
	end
	--set scaling;
	if (self:IsAutoScale()) then
		if(self.unit_value)then
			self.m_fScale = self.unit_value;
		else
			local fMaxLength = math.max(math.max(height, width), depth) + 1;
			self.m_fScale = self:CalculateScale(fMaxLength);
		end
	end
end

function BMaxModel:CalculateScale(length)
	local nPowerOf2Length = mathlib.NextPowerOf2( math.floor(length + 0.1) );
	return self.m_maxSize / nPowerOf2Length;
end

function BMaxModel:InsertNode(node)
	if(not node)then return end
	local index = self:GetNodeIndex(node.x,node.y,node.z);
	if(index)then
		self.m_nodes[index] = node;
	end
end

function BMaxModel:GetNode(x,y,z)
	local index = self:GetNodeIndex(x,y,z);
	if(not index)then
		return
	end
	return self.m_nodes[index];
end

function BMaxModel:GetNodeIndex(x,y,z)
	if(x < 0 or y < 0 or z < 0)then
		return
	end
	return x + lshift(z, 8) + lshift(y, 16);
end

function BMaxModel:CalculateVisibleBlocks()
	for _, node in pairs(self.m_nodes) do
		local cube = self:TessellateBlock(node.x,node.y,node.z);
		if(cube:GetVerticesCount() > 0)then
			table.insert(self.m_blockModels,cube);
		end
	end
end

function BMaxModel:TessellateBlock(x,y,z)
	local node = self:GetNode(x,y,z);
	if(not node)then
		return
	end
	local cube = BlockModel:new();
	local nNearbyBlockCount = 27;
	local neighborBlocks = {};
	neighborBlocks[BlockCommon.rbp_center] = node;
	self:QueryNeighborBlockData(x, y, z, neighborBlocks, 1, nNearbyBlockCount - 1);
	local temp_cube = BlockModel:new():InitCube();
	local dx = node.x - self.m_centerPos[1];
	local dy = node.y - self.m_centerPos[2];
	local dz = node.z - self.m_centerPos[3];
	temp_cube:OffsetPosition(dx,dy,dz);

	for face = 0, 5 do
		local pCurBlock = neighborBlocks[BlockCommon.RBP_SixNeighbors[face]];
		if(not pCurBlock)then
			cube:AddFace(temp_cube, face);
		end
	end
	return cube;
end

function BMaxModel:QueryNeighborBlockData(x,y,z,pBlockData,nFrom,nTo)
	local neighborOfsTable = BlockCommon.NeighborOfsTable;
	local node = self:GetNode(x, y, z);
	if(not node)then return end
	
	for i = nFrom,nTo do
		local xx = x + neighborOfsTable[i].x;
		local yy = y + neighborOfsTable[i].y;
		local zz = z + neighborOfsTable[i].z;

		local pBlock = self:GetNode(xx,yy,zz);
		local index = i - nFrom + 1;
		pBlockData[index] = pBlock;
	end
end

function BMaxModel:ScaleModels(scale)
	if(not scale)then
		return
	end
	local scale = self.m_fScale;
	for _,cube in ipairs(self.m_blockModels) do
		cube:Scale(scale,scale,scale);
	end
end

function BMaxModel:GetTotalTriangleCount()
	local face_cont = 6;
	local cnt = 0;
	for _, cube in ipairs(self.m_blockModels) do
		cnt = cnt + cube:GetFaceCount()*2;
	end	
	return cnt;
end
--get plain bmax content text list
function BMaxModel:GetTextList()
	local result = {};
	local function write_string(s)
		table.insert(result,s);
	end
	write_string("<pe:blocktemplate>\n");
	write_string("<pe:blocks>\n");
	write_string("{\n");
	local blocks = commonlib.copy(self.blocks);
	for k,v in ipairs(blocks) do
		local block_id, block_data = v[4], v[5];
		block_id = block_id or 10; -- default to 10 color block
		if(not block_data and block_id == 10) then
			block_data = 0x00f; -- default to blue color
		end
		write_string(format("  {%d,%d,%d,%d,%d},\n", v[1], v[2], v[3], block_id, block_data or 0));
	end
	write_string("}\n");
	write_string("</pe:blocks>\n");
	write_string("</pe:blocktemplate>");
	return result;
end
-- sava as plain text file
function BMaxModel:SaveAsText(output_file_name)
	local text_list = self:GetTextList();
	ParaIO.CreateDirectory(output_file_name);
	local file = ParaIO.open(output_file_name, "w");
	if(file:IsValid()) then
		local k,v;
		for k,v in ipairs(text_list) do
			file:WriteString(v);
		end
		file:close();
		return true;
	end
end