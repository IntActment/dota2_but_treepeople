local Thinker = class({})

ListenToGameEvent("game_rules_state_game_in_progress", function()
		Timers:CreateTimer( 0, Thinker.Minute00 )
		Timers:CreateTimer( 20*60, Thinker.DontForgetToSubscribe )
		Timers:CreateTimer( 30*60, Thinker.LateGame )
		Timers:CreateTimer( Thinker.VeryVeryOften )
		Timers:CreateTimer( Thinker.VeryOften )
		Timers:CreateTimer( Thinker.Often )
		Timers:CreateTimer( Thinker.Regular )
		Timers:CreateTimer( Thinker.Seldom )
end, GameMode)

function Thinker:Minute00()
	print("The Game begins!")
	return nil -- does not repeat
end

function Thinker:DontForgetToSubscribe()
	-- print("20 minutes")
	return nil -- does not repeat
end

function Thinker:LateGame()
	-- print("30 minutes")
	return nil -- does not repeat
end

LinkLuaModifier( "treepeople_brain", "modifiers/treepeople_brain", LUA_MODIFIER_MOTION_NONE )
LinkLuaModifier( "treepeople_spawner", "modifiers/treepeople_spawner", LUA_MODIFIER_MOTION_NONE )

Treepeople_data =
{
	count = 0,
	spawner_count = 0,
	limit = 120,
	spawner_limit = 16,
}

local treepeople_data = Treepeople_data

function Thinker:VeryVeryOften()
	-- print("every 4.5 seconds")
	
	if treepeople_data.spawner_count < treepeople_data.spawner_limit then
	
		local pos = Vector( RandomFloat( GetWorldMinX(), GetWorldMaxX() ), RandomFloat( GetWorldMinY(), GetWorldMaxY() ), 0 )
		
		local hTree = nil
		local tree_table = GridNav:GetAllTreesAroundPoint( pos, 5000, false )
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
			return 1.5
		end
		
		local hTreemanRax = CreateUnitByName("npc_dota_tree_rax", hTree:GetAbsOrigin() + RandomVector( 20.0 ), false, nil, nil, DOTA_TEAM_CUSTOM_1) -- DOTA_TEAM_CUSTOM_1
		if hTreemanRax ~= nil then
			hTreemanRax:AddNewModifier( nil, nil, "treepeople_spawner", {} )
			hTreemanRax:AddNewModifier( hTreemanRax, nil, "modifier_kill", { duration = 5.0 * 60 } )
		end
	
	else
		--print( "limit has reached" )
	end
	
	return 10.5
end

function Thinker:VeryOften()
	-- print("every minute")
	return 1*60
end

function Thinker:Often()
	-- print("every 5 minutes")
	return 5*60
end

function Thinker:Regular()
	-- print("every 15 minutes")
	return 15*60
end

function Thinker:Seldom()
	-- print("every 30 minutes")
	return 30*60
end
