
treepeople_spawner = class({})

local treepeople_data = Treepeople_data

function treepeople_spawner:RemoveOnDeath() return true end
function treepeople_spawner:IsPurgable() return false end
function treepeople_spawner:IsPurgeException() return false end
function treepeople_spawner:IsHidden() return true end 	-- we can hide the modifier

function treepeople_spawner:GetAttributes()
	return MODIFIER_ATTRIBUTE_IGNORE_INVULNERABLE -- Allows modifier to be assigned to invulnerable entities. 
end

function treepeople_spawner:OnCreated( kv )
	if IsClient() then return end
	
	treepeople_data.spawner_count = treepeople_data.spawner_count + 1
	
	self:StartIntervalThink( 8.75 )

end

function treepeople_spawner:OnIntervalThink()
	if IsClient() then return end
	
	if treepeople_data.count < treepeople_data.limit then
		local parent = self:GetParent()
		local pos = parent:GetAbsOrigin()
		
		local hTree = nil
		local tree_table = GridNav:GetAllTreesAroundPoint( pos, 1800, false )
		local list = {}
		for k, v in pairs(tree_table) do
			if ( v.IsStanding == nil ) or v:IsStanding() then
				list[#list + 1] = v
			end
		end
		
		if #list > 0 then
			hTree = list[ RandomInt( 1, #list ) ]
		end
		
		if hTree == nil then
			-- wait next time
			return
		end

		local hTreeman = CreateUnitByName( "npc_dota_treeman_1", hTree:GetAbsOrigin(), false, nil, nil, parent:GetTeamNumber() ) -- DOTA_TEAM_CUSTOM_1
		if hTreeman ~= nil then
			hTreeman:AddNewModifier( nil, nil, "treepeople_brain", {} )
		end
		
	else
		--print( "limit has reached" )
	end
end

function treepeople_spawner:OnDestroy()
	if IsClient() then return end

	treepeople_data.spawner_count = treepeople_data.spawner_count - 1
end

function treepeople_spawner:CheckState()
	if IsClient() then return 0 end
	
	local state = {
		[MODIFIER_STATE_NO_HEALTH_BAR] = true,
		[MODIFIER_STATE_NOT_ON_MINIMAP] = true,
		[MODIFIER_STATE_NO_UNIT_COLLISION] = true,
	}
	
	return state
end


function treepeople_spawner:DeclareFunctions()
    local funcs = {
    }
    return funcs
end