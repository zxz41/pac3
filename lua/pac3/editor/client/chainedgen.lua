
local L = pace.LanguageString

local sliders = {
	{'x', 0, 'X'},
	{'y', 0, 'Y'},
	{'z', 0, 'Z'},

	{'pitch', 0, 'Pitch', -180, 180},
	{'yaw', 0, 'Yaw', -180, 180},
	{'roll', 0, 'Roll', -180, 180},
}

local activePanel

local function calculatePoints()
	assert(IsValid(activePanel), 'current panel is invalid')

	local self = activePanel
	local nodes = self.stacksize:GetValue()

	local output = {}
	local outputLinear = {}
	local outputProgressive = {}

	for node = 1, nodes do
		local raw = self.linear.calculate(node, outputLinear)
		local raw2 = self.progressive.calculate(node, outputProgressive)

		table.insert(output, {
			x = raw.x + raw2.x,
			y = raw.y + raw2.y,
			z = raw.z + raw2.z,

			pitch = raw.pitch + raw2.pitch,
			yaw = raw.yaw + raw2.yaw,
			roll = raw.roll + raw2.roll,
		})

		table.insert(outputLinear, raw)
		table.insert(outputProgressive, raw2)
	end

	return output
end

function pace.OpenChainedMenu(parent)
	if IsValid(activePanel) then
		activePanel:Remove()
	end

	if not IsValid(parent) then return end

	local self = vgui.Create('DFrame')
	self:SetSize(800, 640)
	self:Center()
	self:MakePopup()
	self:SetTitle(L('Chained Generator (Stacker)'))

	activePanel = self

	self.part_parent = parent

	self.stacksize = vgui.Create('DNumSlider', self)
	self.stacksize:SetMin(2)
	self.stacksize:SetMax(20)
	self.stacksize:SetValue(4)
	self.stacksize:SetDecimals(0)
	self.stacksize:SetText(L('Amount of models'))
	self.stacksize:Dock(TOP)

	--[[local useNewModel = false

	self.modeltype = vgui.Create('DComboBox', self)
	self.modeltype:SetValue('model')
	self.modeltype:AddChoice('model')
	self.modeltype:AddChoice('model2')
	self.modeltype:Dock(TOP)
	self.modeltype.OnSelect = function(_, index, value)
		useNewModel = value == 'model2'
	end]]

	self.inroot = vgui.Create('DCheckBoxLabel', self)
	self.inroot:SetValue(false)
	self.inroot:SetText(L('put all parts in root of parent part'))
	self.inroot:Dock(TOP)

	do
		local label = vgui.Create('DLabel', self)
		label:SetText(L('Note: unchecking this option can produce very deep \nbut easier to move around part trees'))
		label:SizeToContents()
		label:Dock(TOP)
	end

	self.apply = vgui.Create('DButton', self)
	self.apply:Dock(BOTTOM)
	self.apply:SetText(L('apply'))

	local lastPart, lastPos, lastAng = parent, Vector(), Angle()

	self.apply.DoClick = function()
		local points = calculatePoints()
		local inroot = self.inroot:GetChecked()
		local partClone = parent:ToTable(true)
		local currentRoot = parent:GetParent()

		for i, node in ipairs(points) do
			local newpart = pac.CreatePart(parent.ClassName, parent:GetPlayerOwner())
			newpart:SetTable(partClone)
			newpart:SetParent(parent)

			local origin = Vector(node.x, node.y, node.z)
			local angles = Angle(node.pitch, node.yaw, node.roll)

			if not inroot then
				newpart:SetParent(lastPart)
				lastPart = newpart

				local lpos, lang = WorldToLocal(origin, angles, lastPos, lastAng)
				lastPos = origin
				lastAng = angles

				newpart:SetPosition(lpos)
				newpart:SetAngles(lang)
			else
				newpart:SetPosition(origin)
				newpart:SetAngles(angles)
			end
		end

		self:Remove()
	end

	self.lists = vgui.Create('DPropertySheet', self)
	self.lists:Dock(FILL)
	self.lists:DockMargin(0, 10, 0, 0)

	self.linear = vgui.Create('EditablePanel', self.lists)
	self.progressive = vgui.Create('EditablePanel', self.lists)

	self.lists:AddSheet(L('linear'), self.linear)
	self.lists:AddSheet(L('geometric'), self.progressive)

	for i2, list in ipairs({self.linear, self.progressive}) do
		for i, sliderData in ipairs(sliders) do
			local id, default, name, min, max = sliderData[1], sliderData[2], sliderData[3], sliderData[4], sliderData[5]

			local slider = vgui.Create('DNumSlider', list)
			slider:SetMin(min or -100)
			slider:SetMax(max or 100)
			slider:SetValue(default)
			slider:SetText(L(name))
			slider:SetDecimals(2)
			slider:Dock(TOP)

			list['slider_' .. id] = slider
		end

		local checkbox = vgui.Create('DCheckBoxLabel', list)
		checkbox:SetValue(false)
		checkbox:SetText(L('angles affect children align'))
		checkbox:Dock(TOP)

		list.affects_children = checkbox
	end

	self.linear.calculate = function(node, nodelist)
		local x, y, z = self.linear.slider_x:GetValue(), self.linear.slider_y:GetValue(), self.linear.slider_z:GetValue()
		local pitch, yaw, roll = self.linear.slider_pitch:GetValue(), self.linear.slider_yaw:GetValue(), self.linear.slider_roll:GetValue()

		if not self.linear.affects_children:GetChecked() or #nodelist == 0 then
			return {
				x = x * node,
				y = y * node,
				z = z * node,

				pitch = pitch * node,
				yaw = yaw * node,
				roll = roll * node,
			}
		end

		local lastNode = nodelist[#nodelist]
		local pos = Vector(x, y, z)
		local ang = Angle(pitch * node, yaw * node, roll * node)
		pos:Rotate(ang)

		return {
			x = lastNode.x + pos.x,
			y = lastNode.y + pos.y,
			z = lastNode.z + pos.z,

			pitch = pitch * node,
			yaw = yaw * node,
			roll = roll * node,
		}
	end

	self.progressive.calculate = function(node, nodelist)
		local x, y, z = self.progressive.slider_x:GetValue(), self.progressive.slider_y:GetValue(), self.progressive.slider_z:GetValue()
		local pitch, yaw, roll = self.progressive.slider_pitch:GetValue(), self.progressive.slider_yaw:GetValue(), self.progressive.slider_roll:GetValue()

		if not self.progressive.affects_children:GetChecked() or #nodelist == 0 then
			return {
				x = x * node * node,
				y = y * node * node,
				z = z * node * node,

				pitch = pitch * node,
				yaw = yaw * node,
				roll = roll * node,
			}
		end

		local lastNode = nodelist[#nodelist]
		local pow = math.pow(node - 1, 2)
		local pos = Vector(x * pow, y * pow, z * pow)
		local ang = Angle(pitch * node, yaw * node, roll * node)
		pos:Rotate(ang)

		return {
			x = lastNode.x + pos.x,
			y = lastNode.y + pos.y,
			z = lastNode.z + pos.z,

			pitch = pitch * node,
			yaw = yaw * node,
			roll = roll * node,
		}
	end
end

local colorX = Color(255, 80, 80)
local colorY = Color(80, 255, 80)
local colorZ = Color(80, 80, 255)

hook.Add('PostDrawTranslucentRenderables', 'pac_DrawChainedPreview', function(a, b)
	if a or b then return end
	if not IsValid(activePanel) then return end

	local points = calculatePoints()
	local parent = activePanel.part_parent
	local pos, ang = parent:GetDrawPosition()
	local x, y, z = pos.x, pos.y, pos.z
	local p, yaw, r = ang.p, ang.y, ang.r

	render.SetColorMaterial()
	--render.SetColorModulation(1, 1, 1)
	local amount = #points

	for i, node in ipairs(points) do
		local div = i / amount
		render.SetColorModulation(div, 1 - div / 2, 1 - div)
		local origin = Vector(node.x, node.y, node.z)
		local angles = Angle(node.pitch, node.yaw, node.roll)

		local norigin, nangles = LocalToWorld(origin, angles, pos, ang)

		render.DrawSphere(norigin, 3, 30, 30, color_white)

		render.DrawLine(norigin, norigin + nangles:Up() * 10, colorZ, true)
		render.DrawLine(norigin, norigin - nangles:Right() * 10, colorY, true)
		render.DrawLine(norigin, norigin + nangles:Forward() * 10, colorX, true)
	end
end)
